"""
Muzhir Backend — FastAPI application entry point (placeholder).

Mount route modules from `routers/` as endpoints are implemented.
"""

from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv

# Load repo-root `.env` before any module reads os.environ (Cloudinary, Groq, etc.).
load_dotenv(Path(__file__).resolve().parents[1] / ".env", override=True)

from fastapi import FastAPI, File, Form, HTTPException, UploadFile, status

from backend.core.cloudinary_uploader import delete_image, upload_image, upload_image_asset
from backend.inference.class_mapper import ClassMapper
from backend.inference.llm_caller import get_recommendation
from backend.inference.model_loader import lifespan
from backend.inference.runner import InferenceResult, run_inference
from backend.models.recommendation import RecommendationModel
from backend.models.diagnosis import BoundingBoxModel, DiseaseSeverity, DiseaseSnapshotModel
from backend.models.scan import ScanModel
from backend.models.user import UserModel
from backend.schemas.responses import DiagnosisBlock, DiagnoseResponse, HistoryResponse

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


@app.post(
    "/api/v1/diagnose",
    response_model=DiagnoseResponse,
    summary="Run YOLO diagnosis on uploaded image",
)
async def diagnose(image: UploadFile = File(...)) -> DiagnoseResponse:
    """Accept a real image upload and return YOLO diagnosis output."""
    _validate_image_upload(image)

    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    try:
        image_url = upload_image(
            image_bytes,
            folder="muzhir/scans",
            public_id=f"scan_{uuid4().hex}",
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

    if inference_result is None:
        diagnosis = _no_disease_diagnosis()
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
                "crop_type": "Unknown",
                "growth_stage": "Unknown",
            }
            recommendation = await get_recommendation(context)
            diagnosis = _build_diagnosis_block(
                inference_result,
                disease_snapshot,
                recommendation=recommendation,
            )
        except KeyError as exc:
            raise HTTPException(status_code=500, detail=str(exc)) from exc

    return DiagnoseResponse(
        scan_id=f"scan_{uuid4().hex[:8]}",
        status="done",
        image_url=image_url,
        diagnosis=diagnosis,
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
        deleted = delete_image(public_id=public_id, image_url=image_url)
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

    return {"deleted": deleted}


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
