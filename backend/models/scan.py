"""Pydantic models for scan documents at `scans/{scanId}` (Task 2.2)."""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

from backend.models.crop import CropModel
from backend.models.diagnosis import DiagnosisModel


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


class ImageStatus(str, Enum):
    """Lifecycle state of image processing for a scan."""

    PENDING = "pending"
    PROCESSING = "processing"
    DONE = "done"
    FAILED = "failed"


class GeoPointModel(BaseModel):
    """Geographic coordinates for a scan capture location."""

    model_config = ConfigDict(populate_by_name=True)

    latitude: float = Field(
        description="Latitude in decimal degrees (WGS84).",
        examples=[24.7136],
    )
    longitude: float = Field(
        description="Longitude in decimal degrees (WGS84).",
        examples=[46.6753],
    )


class ImageModel(BaseModel):
    """Image payload embedded on a scan document."""

    model_config = ConfigDict(populate_by_name=True)

    image_url: str = Field(
        alias="imageUrl",
        description="HTTPS URL of the stored scan image (required).",
        examples=["https://storage.example.com/scans/abc/image.jpg"],
    )
    status: ImageStatus = Field(
        default=ImageStatus.PENDING,
        description="Processing status; defaults to pending.",
        examples=["pending"],
    )
    is_deleted: bool = Field(
        default=False,
        alias="isDeleted",
        description="Soft-delete flag; defaults to false.",
        examples=[False],
    )


class BatchModel(BaseModel):
    """Optional metadata linking a scan to a batch or upload group."""

    model_config = ConfigDict(populate_by_name=True)

    batch_id: str = Field(
        alias="batchId",
        description="Identifier of the batch this scan belongs to.",
        examples=["batch_2025_04_field_a"],
    )
    label: Optional[str] = Field(
        default=None,
        description="Optional human-readable batch label.",
        examples=["Morning field survey"],
    )


class ScanModel(BaseModel):
    """Master document for `/scans/{scanId}` in Firestore."""

    model_config = ConfigDict(populate_by_name=True)

    user_id: str = Field(
        alias="userId",
        description="Owner user id (Firebase Auth UID); required.",
        examples=["a1b2c3d4e5f6g7h8i9j0k1l2"],
    )
    image: ImageModel = Field(
        description="Embedded image record; imageUrl is required inside this object.",
        examples=[
            {
                "imageUrl": "https://storage.example.com/scans/abc/image.jpg",
                "status": "pending",
                "isDeleted": False,
            }
        ],
    )
    crop: CropModel = Field(
        description="Crop and growth-stage context for this scan (master document field).",
        examples=[
            {
                "cropId": "tomato",
                "cropName": "Tomato",
                "cropNameAr": "طماطم",
                "growthStage": {"stageId": "flowering", "stageName": "Flowering"},
            }
        ],
    )
    location: Optional[GeoPointModel] = Field(
        default=None,
        description="Optional GPS point where the image was captured.",
        examples=[{"latitude": 24.7136, "longitude": 46.6753}],
    )
    latitude: float | None = Field(
        default=None,
        description="Capture latitude when the mobile client sends coordinates.",
    )
    longitude: float | None = Field(
        default=None,
        description="Capture longitude when the mobile client sends coordinates.",
    )
    batch: Optional[BatchModel] = Field(
        default=None,
        description="Optional batch grouping metadata.",
        examples=[{"batchId": "batch_2025_04", "label": "Field A"}],
    )
    diagnosis: Optional[DiagnosisModel] = Field(
        default=None,
        description=(
            "Optional diagnosis result; omitted for new scans until inference completes."
        ),
        examples=[
            {
                "diagnosisId": "550e8400-e29b-41d4-a716-446655440000",
                "confidenceScore": 0.87,
                "modelVersion": "yolov8-muzhir-v1.2",
                "boundingBox": {"x": 0.12, "y": 0.08, "width": 0.35, "height": 0.28},
                "disease": {
                    "diseaseId": "tomato_early_blight",
                    "diseaseName": "Early blight",
                    "diseaseNameAr": "اللفحة المبكرة",
                    "severity": "medium",
                },
                "recommendation": {
                    "treatmentText": "Apply fungicide and prune affected leaves.",
                    "treatmentTextAr": "رش مبيد فطري وقلم الأوراق المصابة.",
                    "citedSources": ["MEWA tomato guide"],
                    "generatedBy": "llm",
                },
            }
        ],
    )
    created_at: datetime = Field(
        default_factory=_utc_now,
        alias="createdAt",
        description="Scan creation time (defaults to current UTC if omitted).",
        examples=["2025-04-12T12:00:00Z"],
    )
