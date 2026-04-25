"""
Muzhir Backend — FastAPI application entry point (placeholder).

Mount route modules from `routers/` as endpoints are implemented.
"""

from datetime import datetime, timezone
import re
from uuid import uuid4

from fastapi import BackgroundTasks, Depends, FastAPI, File, Form, HTTPException, Query, Response, UploadFile, status
from fastapi.responses import JSONResponse
from firebase_admin import firestore

from backend.core.activity_logger import log_action
from backend.core.cloudinary_uploader import delete_image, upload_image, upload_image_asset
from backend.core.config import settings
from backend.core.firebase_config import (
    ensure_firebase_initialized,
    get_firestore_client,
    get_scan_document,
    get_user_document,
    save_scan_metadata,
    soft_delete_scan,
    update_user_profile_image,
)
from backend.middleware.auth import verify_token
from backend.core.status_manager import set_scan_status
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
    MapMarkerItem,
    ScanSummary,
)

OPENAPI_TAGS = [
    {
        "name": "System Health",
        "description": "Operational health and service availability endpoints.",
    },
    {
        "name": "Diagnosis",
        "description": "Image upload, disease inference, and diagnosis response workflows.",
    },
    {
        "name": "History",
        "description": "Authenticated scan history retrieval and per-scan detail access.",
    },
    {
        "name": "Map",
        "description": "Geolocated scan markers for the farmer map.",
    },
    {
        "name": "User Profile",
        "description": "Authenticated profile image management and user schema helpers.",
    },
]

AUTH_RESPONSES = {
    401: {"description": "Unauthorized. A valid Firebase Bearer token is required."},
    503: {"description": "Service unavailable. An upstream dependency is temporarily unavailable."},
}
OWNER_SCAN_RESPONSES = {
    **AUTH_RESPONSES,
    403: {"description": "Forbidden. The authenticated user does not own this scan."},
    404: {"description": "Scan not found."},
}
PROFILE_RESPONSES = {
    **AUTH_RESPONSES,
    404: {"description": "User profile or profile image was not found."},
}

app = FastAPI(
    title="Muzhir (مُزهِر) API - Smart Agriculture System",
    version=settings.APP_VERSION,
    description=(
        "Advanced backend for plant disease detection using YOLOv8, Groq LLM, and "
        "Cloudinary. Integrated with Firebase Auth and Firestore."
    ),
    contact={"name": "Bader"},
    lifespan=lifespan,
    openapi_tags=OPENAPI_TAGS,
    docs_url="/docs" if settings.SHOW_DOCS else None,
    redoc_url="/redoc" if settings.SHOW_DOCS else None,
    openapi_url="/openapi.json" if settings.SHOW_DOCS else None,
    swagger_ui_parameters={"persistAuthorization": True},
)

# Default Firebase Admin app (Auth + Firestore). Idempotent for uvicorn --reload.
ensure_firebase_initialized()

# TODO: Log `login` actions once auth middleware is finalized.


def _validate_image_upload(image: UploadFile) -> None:
    if image.content_type is None or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image uploads are supported.")


@app.get("/health", include_in_schema=False)
@app.get(
    "/api/v1/health",
    response_model=None,
    tags=["System Health"],
    summary="Health check",
    description=(
        "Checks the public API health by verifying that the YOLO model is loaded, Firestore "
        "is reachable, and the configured application version is available for operators and probes."
    ),
    responses={
        503: {"description": "Service unavailable. The API is running but a dependency is unhealthy."},
    },
)
async def health():
    yolo_status = "Loaded" if getattr(app.state, "yolo_model", None) is not None else "Error"
    firestore_status = "Error"
    errors: list[str] = []

    try:
        list(get_firestore_client().collection("scans").limit(1).stream())
        firestore_status = "Connected"
    except Exception as exc:
        errors.append(f"Firestore health check failed: {exc}")

    payload = {
        "api_status": "OK",
        "yolo_model": yolo_status,
        "firestore": firestore_status,
        "version": settings.APP_VERSION,
    }

    if yolo_status != "Loaded":
        errors.append("YOLO model is not loaded.")

    if errors:
        payload["api_status"] = "ERROR"
        payload["errors"] = errors
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content=payload,
        )

    return payload


@app.post(
    "/api/v1/test/user",
    response_model=UserModel,
    tags=["User Profile"],
    summary="Validate user schema",
    description=(
        "Echoes a `UserModel` payload so developers can inspect and validate the generated "
        "user schema in Swagger during integration work."
    ),
    responses=AUTH_RESPONSES,
)
async def test_user(body: UserModel, user_id: str = Depends(verify_token)) -> UserModel:
    """Temporary route to validate [UserModel] in Swagger (e.g. `preferredLanguage`: `fr` → 422)."""
    return body


@app.post(
    "/api/v1/test/scan",
    response_model=ScanModel,
    tags=["Diagnosis"],
    summary="Validate scan schema",
    description=(
        "Echoes a full `ScanModel` payload for documentation and client contract validation, "
        "including embedded crop, image, and diagnosis structures."
    ),
    responses=AUTH_RESPONSES,
)
async def test_scan(body: ScanModel, user_id: str = Depends(verify_token)) -> ScanModel:
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
    tags=["Diagnosis"],
    summary="Diagnose crop image",
    description=(
        "Accepts an authenticated image upload, stores it in Cloudinary, creates the Firestore "
        "scan record, runs YOLOv8 inference plus Groq recommendation generation, updates "
        "scan lifecycle status, and logs the upload activity in the background."
    ),
    responses={
        **AUTH_RESPONSES,
        403: {"description": "Forbidden. The authenticated user is not allowed to create this resource."},
        404: {"description": "Related crop metadata was not found."},
    },
)
async def diagnose(
    background_tasks: BackgroundTasks,
    image: UploadFile = File(...),
    cropId: str = Form(...),
    growthStageId: str = Form(...),
    location: str | None = Form(None),
    source: str = Form("mobile"),
    latitude: float | None = Form(None),
    longitude: float | None = Form(None),
    user_id: str = Depends(verify_token),
) -> DiagnoseUploadResponse:
    """Accept a multipart scan request, upload to Cloudinary, then persist metadata."""
    if image.content_type is None or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image uploads are supported.")
    normalized_user_id = user_id.strip()
    normalized_crop_id = cropId.strip()
    normalized_growth_stage_id = growthStageId.strip()
    normalized_location = location.strip() if location and location.strip() else "Unknown"
    normalized_source = source.strip() if source and source.strip() else "mobile"
    capture_latitude = float(latitude) if latitude is not None else None
    capture_longitude = float(longitude) if longitude is not None else None
    if not normalized_crop_id or not normalized_growth_stage_id:
        raise HTTPException(
            status_code=400,
            detail="cropId and growthStageId are required form fields.",
        )

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    scan_id = uuid4().hex
    scan_document_created = False

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
        get_firestore_client().collection("scans").document(scan_id).set(
            {
                "scanId": scan_id,
                "userId": normalized_user_id,
                "imageUrl": image_url,
                "cropId": normalized_crop_id,
                "growthStageId": normalized_growth_stage_id,
                "location": normalized_location,
                "source": normalized_source,
                "image": {
                    "imageUrl": image_url,
                    "isDeleted": False,
                },
                "createdAt": firestore.SERVER_TIMESTAMP,
                "timestamp": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )
        scan_document_created = True
        set_scan_status(scan_id, "pending")

        set_scan_status(scan_id, "processing")
        inference_result = run_inference(image_bytes, model)
        disease_name = "No disease detected"
        disease_name_ar = "لا يوجد مرض"
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
                if mapped_name.strip().lower().replace(
                    "_", " "
                ) != yolo_name.strip().lower().replace("_", " "):
                    print(
                        "DEBUG: Mapping mismatch detected."
                        f" ClassMap='{mapped_name}' vs YOLO='{yolo_name}'."
                        " Using YOLO label mapping."
                    )
                    disease_snapshot = class_mapper.get_disease_snapshot_by_en_name(yolo_name)

                disease_name_en = str(disease_snapshot["diseaseName"])
                disease_name_ar = str(
                    disease_snapshot.get("diseaseNameAr") or disease_name_en
                )
                context = {
                    "disease_name": disease_name_en,
                    "disease_name_ar": disease_name_ar,
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
            latitude=capture_latitude,
            longitude=capture_longitude,
        )
        set_scan_status(scan_id, "done")
    except ValueError as exc:
        if scan_document_created:
            try:
                set_scan_status(scan_id, "failed")
            except Exception:
                pass
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except HTTPException as exc:
        if scan_document_created:
            try:
                set_scan_status(scan_id, "failed")
            except Exception:
                pass
        raise exc
    except Exception as exc:
        if scan_document_created:
            try:
                set_scan_status(scan_id, "failed")
            except Exception:
                pass
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to complete diagnosis pipeline: {exc}",
        ) from exc

    background_tasks.add_task(
        log_action,
        normalized_user_id,
        "upload",
        scan_id,
        {
            "cropId": normalized_crop_id,
            "growthStageId": normalized_growth_stage_id,
            "source": normalized_source,
        },
    )

    return DiagnoseUploadResponse(
        scan_id=scan_id,
        image_url=image_url,
        location=normalized_location,
        source=normalized_source,
        diagnosis={
            "label": disease_name,
            "labelAr": disease_name_ar,
            "confidence": confidence_score,
            "is_healthy": is_healthy,
            "boundingBox": None if is_healthy or inference is None else {
                "x": inference.bbox["x"],
                "y": inference.bbox["y"],
                "width": inference.bbox["w"],
                "height": inference.bbox["h"],
            },
        },
        recommendation=recommendation_payload,
        latitude=capture_latitude,
        longitude=capture_longitude,
    )


@app.post(
    "/api/v1/profile-photo",
    tags=["User Profile"],
    summary="Upload profile photo to Cloudinary",
    description=(
        "Uploads the authenticated user's profile image to Cloudinary, then persists the "
        "resulting image URL and public id in Firestore."
    ),
    responses=PROFILE_RESPONSES,
)
async def upload_profile_photo(
    image: UploadFile = File(...),
    user_id: str = Depends(verify_token),
) -> dict[str, str]:
    """Upload profile photo and return Cloudinary URL/public id."""
    _validate_image_upload(image)
    normalized_user_id = user_id.strip()
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


@app.delete(
    "/api/v1/profile-photo",
    tags=["User Profile"],
    summary="Delete profile photo from Cloudinary",
    description=(
        "Deletes the authenticated user's current profile image from Cloudinary and clears "
        "the related Firestore profile image fields."
    ),
    responses=PROFILE_RESPONSES,
)
async def delete_profile_photo(
    image_url: str | None = Form(None, alias="imageUrl"),
    public_id: str | None = Form(None, alias="publicId"),
    user_id: str = Depends(verify_token),
) -> dict[str, bool]:
    """Delete a profile photo by public id or image URL."""
    normalized_user_id = user_id.strip()
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
    "/api/v1/history",
    response_model=list[ScanSummary],
    tags=["History"],
    summary="List scan history",
    description=(
        "Returns the authenticated user's scan history from Firestore, with optional crop "
        "filtering and lightweight summary data suitable for the mobile history screen."
    ),
    responses={
        **AUTH_RESPONSES,
        403: {"description": "Forbidden. The authenticated user cannot access this history."},
        404: {"description": "No history resource was found for the authenticated user."},
    },
)
async def get_history(
    limit: int = Query(20, ge=1, le=100),
    cropId: str | None = Query(None),
    user_id: str = Depends(verify_token),
) -> list[ScanSummary]:
    """Return a lightweight scan history list for Flutter history screen."""
    normalized_user_id = user_id.strip()

    normalized_crop_id = cropId.strip() if cropId and cropId.strip() else None

    fetch_limit = min(max(limit * 10, limit), 100)

    try:
        scans_query = get_firestore_client().collection("scans").where(
            "userId", "==", normalized_user_id
        )
        if normalized_crop_id is not None:
            scans_query = scans_query.where("cropId", "==", normalized_crop_id)
        scans_query = scans_query.order_by(
            "createdAt", direction=firestore.Query.DESCENDING
        ).limit(fetch_limit)
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
        status_value = image.get("status") or data.get("status") or "done"
        severity_value = (
            data.get("severity")
            or data.get("diseaseSeverity")
            or disease.get("severity")
        )
        image_url = data.get("imageUrl") or image.get("imageUrl") or ""
        disease_name_raw = (
            data.get("diseaseName")
            or diagnosis.get("diseaseName")
            or disease.get("diseaseName")
        )
        disease_name_value: str | None
        if disease_name_raw is None or str(disease_name_raw).strip() == "":
            disease_name_value = None
        else:
            disease_name_value = str(disease_name_raw).strip()

        status_str = str(status_value).lower() if status_value else ""
        if status_str in ("pending", "processing"):
            is_healthy_value = False
            confidence_value: float | None = None
        else:
            disease_label_for_health = (
                disease_name_value if disease_name_value else "No disease detected"
            )
            is_healthy_value = _scan_is_healthy_row(data, str(disease_label_for_health))
            confidence_value = _history_row_confidence(data, diagnosis, disease)

        history.append(
            ScanSummary(
                scan_id=str(data.get("scanId") or doc.id),
                crop_name=str(crop_name),
                crop_name_ar=str(crop_name_ar),
                created_at=created_at,
                status=status_value,
                severity=severity_value,
                image_url=str(image_url),
                disease_name=disease_name_value,
                is_healthy=is_healthy_value,
                confidence=confidence_value,
            )
        )
        if len(history) >= limit:
            break

    return history


def _capture_coordinate(value: object) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _scan_is_healthy_row(data: dict, disease_label: str) -> bool:
    if data.get("isHealthy") is True:
        return True
    dl = disease_label.lower()
    return "healthy" in dl or "no disease" in dl


def _history_row_confidence(data: dict, diagnosis: dict, disease: dict) -> float | None:
    """Return model confidence in [0, 1], or None if not stored."""
    raw = (
        data.get("confidence_score")
        or diagnosis.get("confidenceScore")
        or diagnosis.get("confidence_score")
        or disease.get("confidenceScore")
        or disease.get("confidence_score")
    )
    if raw is None:
        return None
    try:
        v = float(raw)
    except (TypeError, ValueError):
        return None
    if 1.0 < v <= 100.0:
        v = v / 100.0
    if v < 0.0 or v > 1.0:
        return None
    return v


@app.get(
    "/api/v1/map-markers",
    response_model=list[MapMarkerItem],
    tags=["Map"],
    summary="List map markers",
    description=(
        "Returns scans for the authenticated user that include stored GPS coordinates, "
        "optionally filtered by crop id (same values as `cropId` on diagnose)."
    ),
    responses={
        **AUTH_RESPONSES,
        500: {"description": "Failed to read scans from storage."},
    },
)
async def get_map_markers(
    crop: str | None = Query(
        None,
        description="Optional crop id filter (e.g. tomato, corn).",
    ),
    limit: int = Query(200, ge=1, le=500),
    user_id: str = Depends(verify_token),
) -> list[MapMarkerItem]:
    """Geolocated pins for the mobile map; skips scans without capture coordinates."""
    normalized_user_id = user_id.strip()
    normalized_crop_id = crop.strip() if crop and crop.strip() else None

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
            detail=f"Failed to fetch map markers: {exc}",
        ) from exc

    markers: list[MapMarkerItem] = []
    for doc in docs:
        data = doc.to_dict() or {}
        crop = data.get("crop") if isinstance(data.get("crop"), dict) else {}
        image = data.get("image") if isinstance(data.get("image"), dict) else {}
        if bool(image.get("isDeleted", False)):
            continue

        lat = _capture_coordinate(data.get("captureLatitude"))
        lon = _capture_coordinate(data.get("captureLongitude"))
        if lat is None or lon is None:
            continue

        diagnosis = (
            data.get("diagnosis") if isinstance(data.get("diagnosis"), dict) else {}
        )
        disease = (
            diagnosis.get("disease")
            if isinstance(diagnosis.get("disease"), dict)
            else {}
        )
        disease_name_raw = (
            data.get("diseaseName")
            or diagnosis.get("diseaseName")
            or disease.get("diseaseName")
        )
        disease_label = (
            str(disease_name_raw).strip()
            if disease_name_raw is not None and str(disease_name_raw).strip()
            else "No disease detected"
        )

        crop_name = (
            data.get("cropName")
            or crop.get("cropName")
            or data.get("cropId")
            or crop.get("cropId")
            or "Unknown"
        )
        scan_id = str(data.get("scanId") or doc.id)
        created_raw = data.get("createdAt") or data.get("timestamp")
        if isinstance(created_raw, datetime):
            created_at = created_raw
            if created_at.tzinfo is None:
                created_at = created_at.replace(tzinfo=timezone.utc)
        elif isinstance(created_raw, str) and created_raw.strip():
            try:
                raw = created_raw.replace("Z", "+00:00")
                created_at = datetime.fromisoformat(raw)
                if created_at.tzinfo is None:
                    created_at = created_at.replace(tzinfo=timezone.utc)
            except ValueError:
                created_at = datetime.now(timezone.utc)
        else:
            created_at = datetime.now(timezone.utc)

        markers.append(
            MapMarkerItem(
                scan_id=scan_id,
                latitude=lat,
                longitude=lon,
                crop_type=str(crop_name),
                is_healthy=_scan_is_healthy_row(data, disease_label),
                created_at=created_at,
            )
        )

    return markers


@app.get(
    "/api/v1/scan/{scanId}",
    response_model=ScanModel,
    tags=["History"],
    summary="Get scan details",
    description=(
        "Fetches one scan document, verifies that it belongs to the authenticated user, "
        "hydrates the API response shape, and records a background view activity log."
    ),
    responses=OWNER_SCAN_RESPONSES,
)
async def get_scan(
    scanId: str,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(verify_token),
) -> ScanModel:
    """Fetch one scan, verify ownership, and return full scan payload."""
    normalized_scan_id = scanId.strip()
    normalized_user_id = user_id.strip()
    if not normalized_scan_id:
        raise HTTPException(status_code=400, detail="scanId is required.")

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
        str(image.get("status") or data.get("status") or "done")
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

    def _coerce_optional_float(value: object) -> float | None:
        if value is None:
            return None
        try:
            return float(value)
        except (TypeError, ValueError):
            return None

    cap_lat = _coerce_optional_float(data.get("captureLatitude"))
    cap_lon = _coerce_optional_float(data.get("captureLongitude"))

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
    if cap_lat is not None:
        payload["latitude"] = cap_lat
    if cap_lon is not None:
        payload["longitude"] = cap_lon

    background_tasks.add_task(
        log_action,
        normalized_user_id,
        "view_scan",
        normalized_scan_id,
    )

    return ScanModel(**payload)


@app.delete(
    "/api/v1/scan/{scanId}",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["History"],
    summary="Delete scan",
    description=(
        "Soft deletes a scan by marking `image.isDeleted=true` in Firestore after ownership "
        "verification, then records the delete action in the background."
    ),
    responses=OWNER_SCAN_RESPONSES,
)
async def delete_scan(
    scanId: str,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(verify_token),
) -> Response:
    """Soft delete a scan by marking `image.isDeleted=true` and logging activity."""
    normalized_scan_id = scanId.strip()
    normalized_user_id = user_id.strip()
    if not normalized_scan_id:
        raise HTTPException(status_code=400, detail="scanId is required.")

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
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to soft delete scan: {exc}",
        ) from exc

    background_tasks.add_task(
        log_action,
        normalized_user_id,
        "delete_scan",
        normalized_scan_id,
    )

    return Response(status_code=status.HTTP_204_NO_CONTENT)


@app.post(
    "/api/v1/test/diagnose",
    response_model=DiagnoseResponse,
    tags=["Diagnosis"],
    summary="Validate diagnose response schema",
    description=(
        "Echoes a `DiagnoseResponse` payload so frontend developers can inspect the clean "
        "diagnosis response contract without internal Firestore-only fields."
    ),
    responses=AUTH_RESPONSES,
)
async def test_diagnose(body: DiagnoseResponse, user_id: str = Depends(verify_token)) -> DiagnoseResponse:
    """Echo a [DiagnoseResponse] body — Swagger shows the clean diagnose payload (no `diagnosisId`, `recommendationId`, or `isDeleted`)."""
    return body


@app.post(
    "/api/v1/test/history",
    response_model=HistoryResponse,
    tags=["History"],
    summary="Validate history response schema",
    description=(
        "Echoes a `HistoryResponse` payload for documentation and contract testing of the "
        "history list wrapper returned to clients."
    ),
    responses=AUTH_RESPONSES,
)
async def test_history(body: HistoryResponse, user_id: str = Depends(verify_token)) -> HistoryResponse:
    """Echo a [HistoryResponse] body — Swagger shows the wrapped list of [ScanSummary] rows."""
    return body
