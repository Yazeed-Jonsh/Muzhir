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
