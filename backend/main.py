"""
Muzhir Backend — FastAPI application entry point (placeholder).

Mount route modules from `routers/` as endpoints are implemented.
"""

from pathlib import Path
from datetime import datetime, timezone
import re
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import FastAPI, File, Form, HTTPException, Query, Response, UploadFile, status
from firebase_admin import firestore

# Load env values before any module reads os.environ (Cloudinary/Firebase/Groq).
load_dotenv(Path(__file__).resolve().parent / ".env", override=False)
load_dotenv(Path(__file__).resolve().parents[1] / ".env", override=False)

from backend.core.cloudinary_uploader import delete_image, upload_image, upload_image_asset
from backend.core.firebase_config import (
    get_firestore_client,
    get_user_document,
    log_activity,
    get_scan_document,
    save_scan_metadata,
    soft_delete_scan,
    update_user_profile_image,
)
from backend.inference.llm_caller import get_recommendation
from backend.inference.model_loader import lifespan
from backend.inference.runner import InferenceResult, run_inference
from backend.models.recommendation import RecommendationModel
from backend.models.diagnosis import BoundingBoxModel, DiseaseSeverity, DiseaseSnapshotModel
from backend.models.scan import ScanModel
from backend.models.user import UserModel
from backend.schemas.responses import (
    DiagnosisBlock,
    DiagnoseResponse,
    DiagnoseUploadResponse,
    HistoryResponse,
    ScanSummary,
)

app = FastAPI(title="Muzhir Backend", version="0.1.0", lifespan=lifespan)


def _validate_image_upload(image: UploadFile) -> None:
    if image.content_type is None or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image uploads are supported.")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/v1/test/user", response_model=UserModel)
async def test_user(body: UserModel) -> UserModel:
    """Temporary route to validate [UserModel] in Swagger (e.g. `preferredLanguage`: `fr` → 422)."""
    return body


@app.post("/api/v1/test/scan", response_model=ScanModel)
async def test_scan(body: ScanModel) -> ScanModel:
    """Validate a full [ScanModel] in Swagger.

    Required: `userId`, `image.imageUrl`, `crop` (with `cropNameAr`). Omit `diagnosis` for pending scans.

    Optional `diagnosis` (hierarchy: scan → diagnosis → recommendation for one-read). Example:

    ```json
    "diagnosis": {
      "confidenceScore": 0.87,
      "modelVersion": "yolov8-muzhir-v1.2",
      "boundingBox": { "x": 0.12, "y": 0.08, "width": 0.35, "height": 0.28 },
      "disease": {
        "diseaseId": "tomato_early_blight",
        "diseaseName": "Early blight",
        "diseaseNameAr": "اللفحة المبكرة",
        "severity": "medium"
      },
      "recommendation": {
        "treatmentText": "Apply fungicide and prune affected leaves.",
        "treatmentTextAr": "رش مبيد فطري وقلم الأوراق المصابة.",
        "citedSources": ["MEWA tomato guide"],
        "generatedBy": "llm"
      }
    }
    ```

    Omit `recommendation` until advice exists. `citedSources` defaults to `[]`. `generatedBy` must be `llm` or `manual`.
    Omitted `diagnosisId` / `recommendationId` get new UUID v4s. Invalid bbox or confidence outside [0,1] → 422.

    For **client-facing** responses without internal ids/metadata, use `/api/v1/test/diagnose` and `/api/v1/test/history`.
    """
    return body


def _no_disease_diagnosis() -> DiagnosisBlock:
    return DiagnosisBlock(
        confidence_score=0.0,
        model_version="yolo26-m",
        bounding_box=BoundingBoxModel(x=0.0, y=0.0, width=0.0, height=0.0),
        disease=DiseaseSnapshotModel(
            disease_id="no_disease",
            disease_name="No disease detected",
            disease_name_ar="لا يوجد مرض",
            severity=DiseaseSeverity.LOW,
        ),
        recommendation=None,
    )


def _build_diagnosis_block(
    inference: InferenceResult,
    disease_snapshot: dict,
    recommendation: RecommendationModel | None = None,
) -> DiagnosisBlock:
    """Convert parsed inference into the public diagnosis response shape."""
    if inference.confidence >= 0.8:
        severity = DiseaseSeverity.HIGH
    elif inference.confidence >= 0.5:
        severity = DiseaseSeverity.MEDIUM
    else:
        severity = DiseaseSeverity.LOW

    mapped_snapshot = dict(disease_snapshot)
    mapped_snapshot["severity"] = severity
    recommendation_payload = (
        {
            "treatmentText": recommendation.treatment_text,
            "treatmentTextAr": recommendation.treatment_text_ar,
            "citedSources": recommendation.cited_sources,
            "generatedBy": recommendation.generated_by,
        }
        if recommendation is not None
        else None
    )

    return DiagnosisBlock(
        confidence_score=inference.confidence,
        model_version=inference.model_version,
        bounding_box=BoundingBoxModel(
            x=inference.bbox["x"],
            y=inference.bbox["y"],
            width=inference.bbox["w"],
            height=inference.bbox["h"],
        ),
        disease=DiseaseSnapshotModel(**mapped_snapshot),
        recommendation=recommendation_payload,
    )


def _severity_from_confidence(confidence: float) -> DiseaseSeverity:
    if confidence >= 0.8:
        return DiseaseSeverity.HIGH
    if confidence >= 0.5:
        return DiseaseSeverity.MEDIUM
    return DiseaseSeverity.LOW


def _slugify_label(label: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", label.lower()).strip("_") or "unknown"


def _normalize_image_status(status_value: str | None) -> str:
    if status_value in {"pending", "processing", "done", "failed"}:
        return status_value
    return "done"


@app.post(
    "/api/v1/diagnose",
    response_model=DiagnoseUploadResponse,
    summary="Upload scan image and trigger diagnosis pipeline",
)
async def diagnose(
    image: UploadFile = File(...),
    userId: str = Form(...),
    cropId: str = Form(...),
    growthStageId: str = Form(...),
    location: str | None = Form(None),
    source: str = Form("mobile"),
) -> DiagnoseUploadResponse:
    """Accept a multipart scan request, upload to Cloudinary, then persist metadata."""
    if image.content_type is None or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image uploads are supported.")
    normalized_user_id = userId.strip()
    normalized_crop_id = cropId.strip()
    normalized_growth_stage_id = growthStageId.strip()
    normalized_location = location.strip() if location and location.strip() else "Unknown"
    normalized_source = source.strip() if source and source.strip() else "mobile"
    if not normalized_user_id or not normalized_crop_id or not normalized_growth_stage_id:
        raise HTTPException(
            status_code=400,
            detail="userId, cropId, and growthStageId are required form fields.",
        )

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    scan_id = uuid4().hex

    try:
        image_url = upload_image(
            image_bytes,
            folder="muzhir/scans",
            public_id=f"scan_{scan_id}",
            filename=image.filename or "scan.jpg",
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Image upload failed: {exc}",
        ) from exc

    model = app.state.yolo_model
    class_mapper = app.state.class_mapper

    try:
        inference_result = run_inference(image_bytes, model)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    disease_name = "No disease detected"
    confidence_score = 0.0
    is_healthy = True
    recommendation_payload: dict[str, str] = {
        "text_ar": "",
        "text_en": "",
    }

    if inference_result is None:
        _no_disease_diagnosis()
    else:
        try:
            print(f"DEBUG: YOLO detected Class ID: {inference_result.class_id}")
            severity_label = (
                "high"
                if inference_result.confidence >= 0.8
                else "medium" if inference_result.confidence >= 0.5 else "low"
            )
            disease_snapshot = class_mapper.get_disease_snapshot(inference_result.class_id)
            mapped_name = str(disease_snapshot["diseaseName"])
            yolo_name = inference_result.yolo_label
            if mapped_name.strip().lower().replace("_", " ") != yolo_name.strip().lower().replace(
                "_", " "
            ):
                print(
                    "DEBUG: Mapping mismatch detected."
                    f" ClassMap='{mapped_name}' vs YOLO='{yolo_name}'."
                    " Using YOLO label mapping."
                )
                disease_snapshot = class_mapper.get_disease_snapshot_by_en_name(yolo_name)

            disease_name_en = str(disease_snapshot["diseaseName"])
            context = {
                "disease_name": disease_name_en,
                "severity": severity_label,
                "crop_type": normalized_crop_id,
                "growth_stage": normalized_growth_stage_id,
            }
            recommendation = await get_recommendation(context)
            disease_name = disease_name_en
            confidence_score = float(inference_result.confidence)
            is_healthy = disease_name_en.strip().lower() in {"no disease", "no disease detected"}
            recommendation_payload = {
                "text_ar": recommendation.treatment_text_ar,
                "text_en": recommendation.treatment_text,
            }
            _build_diagnosis_block(
                inference_result,
                disease_snapshot,
                recommendation=recommendation,
            )
        except KeyError as exc:
            raise HTTPException(status_code=500, detail=str(exc)) from exc

    try:
        save_scan_metadata(
            scan_id=scan_id,
            user_id=normalized_user_id,
            disease_name=disease_name,
            confidence_score=confidence_score,
            is_healthy=is_healthy,
            recommendation=recommendation_payload,
            image_url=image_url,
            crop_id=normalized_crop_id,
            growth_stage_id=normalized_growth_stage_id,
            location=normalized_location,
            source=normalized_source,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to persist scan metadata: {exc}",
        ) from exc

    return DiagnoseUploadResponse(
        scan_id=scan_id,
        image_url=image_url,
        location=normalized_location,
        source=normalized_source,
        diagnosis={
            "label": disease_name,
            "confidence": confidence_score,
            "is_healthy": is_healthy,
        },
        recommendation=recommendation_payload,
    )


@app.post("/api/v1/profile-photo", summary="Upload profile photo to Cloudinary")
async def upload_profile_photo(
    user_id: str = Form(..., alias="userId"),
    image: UploadFile = File(...),
) -> dict[str, str]:
    """Upload profile photo and return Cloudinary URL/public id."""
    _validate_image_upload(image)
    normalized_user_id = user_id.strip()
    if not normalized_user_id:
        raise HTTPException(status_code=400, detail="userId cannot be empty.")
    try:
        user_doc = get_user_document(normalized_user_id)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user profile: {exc}",
        ) from exc
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found.")

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    try:
        image_url, public_id = upload_image_asset(
            image_bytes,
            folder=f"muzhir/users/{normalized_user_id}",
            public_id="profile_pic",
            filename=image.filename or "profile.jpg",
        )
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Profile upload failed: {exc}",
        ) from exc

    try:
        update_user_profile_image(
            user_id=normalized_user_id,
            profile_image_url=image_url,
            profile_image_public_id=public_id,
        )
    except Exception as exc:
        # Best-effort rollback: avoid orphaning uploaded Cloudinary assets.
        try:
            delete_image(public_id=public_id)
        except Exception:
            pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update user profile image in Firestore: {exc}",
        ) from exc

    return {"imageUrl": image_url, "publicId": public_id}


@app.delete("/api/v1/profile-photo", summary="Delete profile photo from Cloudinary")
async def delete_profile_photo(
    user_id: str = Form(..., alias="userId"),
    image_url: str | None = Form(None, alias="imageUrl"),
    public_id: str | None = Form(None, alias="publicId"),
) -> dict[str, bool]:
    """Delete a profile photo by public id or image URL."""
    normalized_user_id = user_id.strip()
    if not normalized_user_id:
        raise HTTPException(status_code=400, detail="userId cannot be empty.")
    try:
        user_doc = get_user_document(normalized_user_id)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user profile: {exc}",
        ) from exc
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found.")

    user_data = user_doc.to_dict() or {}
    resolved_public_id = (public_id or user_data.get("profileImagePublicId") or "").strip()
    resolved_image_url = (image_url or user_data.get("profileImageUrl") or "").strip()
    if not resolved_public_id and not resolved_image_url:
        raise HTTPException(
            status_code=400,
            detail="No profile image reference found. Provide publicId/imageUrl or upload one first.",
        )

    try:
        deleted = delete_image(public_id=resolved_public_id, image_url=resolved_image_url)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Profile delete failed: {exc}",
        ) from exc

    if deleted:
        try:
            update_user_profile_image(
                user_id=normalized_user_id,
                profile_image_url=None,
                profile_image_public_id=None,
            )
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to clear profile image in Firestore: {exc}",
            ) from exc

    return {"deleted": deleted}


@app.get(
    "/api/v1/history/{userId}",
    response_model=list[ScanSummary],
    summary="Get scan history for a user",
)
async def get_history(
    userId: str,
    limit: int = Query(20, ge=1, le=100),
    cropId: str | None = Query(None),
) -> list[ScanSummary]:
    """Return a lightweight scan history list for Flutter history screen."""
    normalized_user_id = userId.strip()
    if not normalized_user_id:
        raise HTTPException(status_code=400, detail="userId cannot be empty.")

    normalized_crop_id = cropId.strip() if cropId and cropId.strip() else None

    try:
        scans_query = get_firestore_client().collection("scans").where(
            "userId", "==", normalized_user_id
        )
        if normalized_crop_id is not None:
            scans_query = scans_query.where("cropId", "==", normalized_crop_id)
        scans_query = scans_query.order_by(
            "createdAt", direction=firestore.Query.DESCENDING
        ).limit(limit)
        docs = list(scans_query.stream())
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch scan history: {exc}",
        ) from exc

    if not docs:
        return []

    history: list[ScanSummary] = []
    for doc in docs:
        data = doc.to_dict() or {}
        crop = data.get("crop") if isinstance(data.get("crop"), dict) else {}
        image = data.get("image") if isinstance(data.get("image"), dict) else {}
        if bool(image.get("isDeleted", False)):
            continue
        diagnosis = (
            data.get("diagnosis") if isinstance(data.get("diagnosis"), dict) else {}
        )
        disease = (
            diagnosis.get("disease")
            if isinstance(diagnosis.get("disease"), dict)
            else {}
        )

        crop_name = (
            data.get("cropName")
            or crop.get("cropName")
            or data.get("cropId")
            or crop.get("cropId")
            or "Unknown"
        )
        crop_name_ar = (
            data.get("cropNameAr")
            or crop.get("cropNameAr")
            or crop_name
        )
        created_at = data.get("createdAt") or data.get("timestamp") or datetime.now(
            timezone.utc
        )
        status_value = data.get("status") or image.get("status") or "done"
        severity_value = (
            data.get("severity")
            or data.get("diseaseSeverity")
            or disease.get("severity")
        )
        image_url = data.get("imageUrl") or image.get("imageUrl") or ""

        history.append(
            ScanSummary(
                scan_id=str(data.get("scanId") or doc.id),
                crop_name=str(crop_name),
                crop_name_ar=str(crop_name_ar),
                created_at=created_at,
                status=status_value,
                severity=severity_value,
                image_url=str(image_url),
            )
        )

    return history


@app.get(
    "/api/v1/scan/{scanId}",
    response_model=ScanModel,
    summary="Get full scan details",
)
async def get_scan(scanId: str, userId: str = Query(...)) -> ScanModel:
    """Fetch one scan, verify ownership, and return full scan payload."""
    normalized_scan_id = scanId.strip()
    normalized_user_id = userId.strip()
    if not normalized_scan_id or not normalized_user_id:
        raise HTTPException(status_code=400, detail="scanId and userId are required.")

    try:
        doc = get_scan_document(normalized_scan_id)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch scan: {exc}",
        ) from exc

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Scan not found.")

    data = doc.to_dict() or {}
    owner_user_id = str(data.get("userId", "")).strip()
    if owner_user_id != normalized_user_id:
        raise HTTPException(status_code=403, detail="Forbidden.")

    crop = data.get("crop") if isinstance(data.get("crop"), dict) else {}
    image = data.get("image") if isinstance(data.get("image"), dict) else {}
    diagnosis_data = (
        data.get("diagnosis") if isinstance(data.get("diagnosis"), dict) else {}
    )
    recommendation_data = (
        data.get("recommendation") if isinstance(data.get("recommendation"), dict) else {}
    )

    crop_id = str(data.get("cropId") or crop.get("cropId") or "unknown")
    crop_name = str(data.get("cropName") or crop.get("cropName") or crop_id)
    crop_name_ar = str(data.get("cropNameAr") or crop.get("cropNameAr") or crop_name)
    growth_stage = (
        crop.get("growthStage") if isinstance(crop.get("growthStage"), dict) else {}
    )
    growth_stage_id = str(
        data.get("growthStageId") or growth_stage.get("stageId") or "unknown"
    )
    growth_stage_name = str(
        data.get("growthStageName") or growth_stage.get("stageName") or growth_stage_id
    )

    image_url = str(data.get("imageUrl") or image.get("imageUrl") or "")
    status_value = _normalize_image_status(
        str(data.get("status") or image.get("status") or "done")
    )

    confidence_score = float(
        data.get("confidence_score")
        or diagnosis_data.get("confidenceScore")
        or 0.0
    )
    disease_name = str(
        data.get("diseaseName")
        or diagnosis_data.get("disease", {}).get("diseaseName")
        or "No disease detected"
    )
    disease_name_ar = str(
        data.get("diseaseNameAr")
        or diagnosis_data.get("disease", {}).get("diseaseNameAr")
        or ("لا يوجد مرض" if disease_name.lower() == "no disease detected" else disease_name)
    )
    severity = _severity_from_confidence(confidence_score)
    bbox = diagnosis_data.get("boundingBox")
    if not isinstance(bbox, dict):
        bbox = {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0}

    recommendation_payload = None
    text_en = (
        recommendation_data.get("text_en")
        or recommendation_data.get("treatmentText")
    )
    text_ar = (
        recommendation_data.get("text_ar")
        or recommendation_data.get("treatmentTextAr")
    )
    if text_en or text_ar:
        recommendation_payload = {
            "treatmentText": text_en or "",
            "treatmentTextAr": text_ar or "",
            "citedSources": recommendation_data.get("citedSources") or [],
            "generatedBy": recommendation_data.get("generatedBy") or "llm",
        }

    diagnosis_payload = {
        "confidenceScore": confidence_score,
        "modelVersion": diagnosis_data.get("modelVersion") or "yolo26-m",
        "boundingBox": {
            "x": float(bbox.get("x", 0.0)),
            "y": float(bbox.get("y", 0.0)),
            "width": float(bbox.get("width", 0.0)),
            "height": float(bbox.get("height", 0.0)),
        },
        "disease": {
            "diseaseId": _slugify_label(disease_name),
            "diseaseName": disease_name,
            "diseaseNameAr": disease_name_ar,
            "severity": severity.value,
        },
        "recommendation": recommendation_payload,
    }

    location_payload = None
    if isinstance(data.get("location"), dict):
        location_payload = data.get("location")

    created_at = data.get("createdAt") or data.get("timestamp") or datetime.now(timezone.utc)

    payload = {
        "userId": owner_user_id,
        "image": {
            "imageUrl": image_url,
            "status": status_value,
            "isDeleted": bool(image.get("isDeleted", False)),
        },
        "crop": {
            "cropId": crop_id,
            "cropName": crop_name,
            "cropNameAr": crop_name_ar,
            "growthStage": {
                "stageId": growth_stage_id,
                "stageName": growth_stage_name,
            },
        },
        "location": location_payload,
        "diagnosis": diagnosis_payload,
        "createdAt": created_at,
    }
    return ScanModel(**payload)


@app.delete(
    "/api/v1/scan/{scanId}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft delete a scan",
)
async def delete_scan(scanId: str, userId: str = Query(...)) -> Response:
    """Soft delete a scan by marking `image.isDeleted=true` and logging activity."""
    normalized_scan_id = scanId.strip()
    normalized_user_id = userId.strip()
    if not normalized_scan_id or not normalized_user_id:
        raise HTTPException(status_code=400, detail="scanId and userId are required.")

    try:
        doc = get_scan_document(normalized_scan_id)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch scan: {exc}",
        ) from exc

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Scan not found.")

    data = doc.to_dict() or {}
    owner_user_id = str(data.get("userId", "")).strip()
    if owner_user_id != normalized_user_id:
        raise HTTPException(status_code=403, detail="Forbidden.")

    try:
        soft_delete_scan(normalized_scan_id)
        log_activity(
            scan_id=normalized_scan_id,
            user_id=normalized_user_id,
            action_type="delete_scan",
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to soft delete scan: {exc}",
        ) from exc

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.post(
    "/api/v1/test/diagnose",
    response_model=DiagnoseResponse,
    summary="Test DiagnoseResponse schema",
)
async def test_diagnose(body: DiagnoseResponse) -> DiagnoseResponse:
    """Echo a [DiagnoseResponse] body — Swagger shows the clean diagnose payload (no `diagnosisId`, `recommendationId`, or `isDeleted`)."""
    return body


@app.post(
    "/api/v1/test/history",
    response_model=HistoryResponse,
    summary="Test HistoryResponse schema",
)
async def test_history(body: HistoryResponse) -> HistoryResponse:
    """Echo a [HistoryResponse] body — Swagger shows the wrapped list of [ScanSummary] rows."""
    return body
