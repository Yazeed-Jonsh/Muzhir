"""Public API response shapes for Flutter (Task 2.6) — no Firestore-only metadata."""

from __future__ import annotations

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

from backend.models.diagnosis import BoundingBoxModel, DiseaseSeverity, DiseaseSnapshotModel
from backend.models.scan import ImageStatus


class ScanSummary(BaseModel):
    """One row in scan history lists."""

    model_config = ConfigDict(populate_by_name=True)

    scan_id: str = Field(
        alias="scanId",
        description="Client-facing scan identifier.",
        examples=["scan_7f3a9c2e"],
    )
    crop_name: str = Field(
        alias="cropName",
        description="Crop name in English.",
        examples=["Tomato"],
    )
    crop_name_ar: str = Field(
        alias="cropNameAr",
        description="Crop name in Arabic.",
        examples=["طماطم"],
    )
    created_at: datetime = Field(
        alias="createdAt",
        description="When the scan was created.",
        examples=["2025-04-12T14:30:00Z"],
    )
    status: ImageStatus = Field(
        description="Image pipeline status (e.g. pending, done).",
        examples=["done"],
    )
    severity: Optional[DiseaseSeverity] = Field(
        default=None,
        description="Disease severity when a diagnosis exists; null if pending.",
        examples=["medium"],
    )
    image_url: str = Field(
        alias="imageUrl",
        description="Cloudinary image URL for the scan thumbnail/preview.",
        examples=["https://res.cloudinary.com/demo/image/upload/v1/muzhir/scans/scan_123.jpg"],
    )


class RecommendationBlock(BaseModel):
    """Treatment advice exposed to the client (no recommendation UUID)."""

    model_config = ConfigDict(populate_by_name=True)

    treatment_text: str = Field(
        alias="treatmentText",
        description="English treatment text.",
        examples=["Apply fungicide and prune affected leaves."],
    )
    treatment_text_ar: str = Field(
        alias="treatmentTextAr",
        description="Arabic treatment text.",
        examples=["رش مبيد فطري وقلم الأوراق المصابة."],
    )
    cited_sources: List[str] = Field(
        default_factory=list,
        alias="citedSources",
        description="Source labels shown to the user.",
        examples=[["MEWA tomato guide"]],
    )
    generated_by: Literal["llm", "manual"] = Field(
        alias="generatedBy",
        description="Origin of the recommendation text.",
        examples=["llm"],
    )


class DiagnosisBlock(BaseModel):
    """Diagnosis payload returned to the client (no diagnosis UUID)."""

    model_config = ConfigDict(populate_by_name=True)

    confidence_score: float = Field(
        alias="confidenceScore",
        ge=0.0,
        le=1.0,
        description="Model confidence (0–1).",
        examples=[0.87],
    )
    model_version: str = Field(
        alias="modelVersion",
        description="Model version used for inference.",
        examples=["yolov8-muzhir-v1.2"],
    )
    bounding_box: BoundingBoxModel = Field(
        alias="boundingBox",
        description="Normalized detection box (0–1).",
        examples=[{"x": 0.12, "y": 0.08, "width": 0.35, "height": 0.28}],
    )
    disease: DiseaseSnapshotModel = Field(
        description="Detected disease labels.",
        examples=[
            {
                "diseaseId": "tomato_early_blight",
                "diseaseName": "Early blight",
                "diseaseNameAr": "اللفحة المبكرة",
                "severity": "medium",
            }
        ],
    )
    recommendation: Optional[RecommendationBlock] = Field(
        default=None,
        description="Treatment recommendation when available.",
        examples=[
            {
                "treatmentText": "Apply fungicide.",
                "treatmentTextAr": "رش مبيد فطري.",
                "citedSources": [],
                "generatedBy": "llm",
            }
        ],
    )


class DiagnoseResponse(BaseModel):
    """Immediate diagnosis result for a single scan."""

    model_config = ConfigDict(populate_by_name=True)

    scan_id: str = Field(
        alias="scanId",
        description="Client-facing scan identifier.",
        examples=["scan_7f3a9c2e"],
    )
    status: ImageStatus = Field(
        description="Current image/scan processing status.",
        examples=["done"],
    )
    image_url: str = Field(
        alias="imageUrl",
        description="Public URL of the scan image (no soft-delete flags).",
        examples=["https://storage.example.com/scans/abc/image.jpg"],
    )
    diagnosis: DiagnosisBlock = Field(
        description="Embedded diagnosis result.",
        examples=[
            {
                "confidenceScore": 0.87,
                "modelVersion": "yolov8-muzhir-v1.2",
                "boundingBox": {"x": 0.12, "y": 0.08, "width": 0.35, "height": 0.28},
                "disease": {
                    "diseaseId": "tomato_early_blight",
                    "diseaseName": "Early blight",
                    "diseaseNameAr": "اللفحة المبكرة",
                    "severity": "medium",
                },
            }
        ],
    )


class DiagnoseUploadResponse(BaseModel):
    """Diagnosis-first response for upload flow."""

    model_config = ConfigDict(populate_by_name=True)

    scan_id: str = Field(
        alias="scanId",
        description="Unique scan identifier used for storage and tracking.",
        examples=["scan_f47ac10b58cc4372a5670e02b2c3d479"],
    )
    image_url: str = Field(
        alias="imageUrl",
        description="Cloudinary URL of the uploaded scan image.",
        examples=["https://res.cloudinary.com/demo/image/upload/v1/muzhir/scans/scan_123.jpg"],
    )
    location: str | None = Field(
        default=None,
        description="Capture location metadata provided by the client.",
        examples=["Field A - North Zone"],
    )
    source: str = Field(
        description="Source channel for this scan event.",
        examples=["mobile"],
    )
    diagnosis: "DiagnosePriorityBlock" = Field(
        description="Minimal diagnosis block focused on model signal.",
    )
    recommendation: "DiagnoseRecommendationBlock" = Field(
        description="Recommendation text prepared for UI button display.",
    )


class DiagnosePriorityBlock(BaseModel):
    """Diagnosis-first compact payload for immediate UX."""

    label: str = Field(
        description="Detected disease label (or healthy label).",
        examples=["Early blight"],
    )
    confidence: float = Field(
        ge=0.0,
        le=1.0,
        description="YOLO confidence score (0-1).",
        examples=[0.87],
    )
    is_healthy: bool = Field(
        description="True when no disease is detected.",
        examples=[False],
    )


class DiagnoseRecommendationBlock(BaseModel):
    """Recommendation payload that the UI can reveal on demand."""

    text_ar: str = Field(
        description="Recommendation text in Arabic.",
        examples=["رش مبيد فطري وقلم الأوراق المصابة."],
    )
    text_en: str = Field(
        description="Recommendation text in English.",
        examples=["Apply fungicide and prune affected leaves."],
    )


class HistoryResponse(BaseModel):
    """Paginated-style wrapper for scan history (lightweight entries only)."""

    model_config = ConfigDict(populate_by_name=True)

    scans: List[ScanSummary] = Field(
        default_factory=list,
        description="History rows without internal Firestore fields.",
        examples=[
            [
                {
                    "scanId": "scan_a",
                    "cropName": "Tomato",
                    "cropNameAr": "طماطم",
                    "createdAt": "2025-04-12T14:30:00Z",
                    "status": "done",
                    "severity": "medium",
                }
            ]
        ],
    )
