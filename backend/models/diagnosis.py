"""Diagnosis and detection geometry models for scan documents (Task 2.4)."""

from __future__ import annotations

from enum import Enum
from typing import Optional
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field

from backend.models.recommendation import RecommendationModel


class BoundingBoxModel(BaseModel):
    """Normalized bounding box in relative image coordinates (0–1)."""

    model_config = ConfigDict(populate_by_name=True)

    x: float = Field(
        ge=0.0,
        le=1.0,
        description="Left edge of the box (normalized, 0–1).",
        examples=[0.12],
    )
    y: float = Field(
        ge=0.0,
        le=1.0,
        description="Top edge of the box (normalized, 0–1).",
        examples=[0.08],
    )
    width: float = Field(
        ge=0.0,
        le=1.0,
        description="Box width (normalized, 0–1).",
        examples=[0.35],
    )
    height: float = Field(
        ge=0.0,
        le=1.0,
        description="Box height (normalized, 0–1).",
        examples=[0.28],
    )


class DiseaseSeverity(str, Enum):
    """Coarse severity label for the detected condition."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class DiseaseSnapshotModel(BaseModel):
    """Disease labels captured at inference time."""

    model_config = ConfigDict(populate_by_name=True)

    disease_id: str = Field(
        alias="diseaseId",
        description="Stable disease identifier.",
        examples=["tomato_early_blight"],
    )
    disease_name: str = Field(
        alias="diseaseName",
        description="Disease name in English.",
        examples=["Early blight"],
    )
    disease_name_ar: str = Field(
        alias="diseaseNameAr",
        description="Disease name in Arabic.",
        examples=["اللفحة المبكرة"],
    )
    severity: DiseaseSeverity = Field(
        description="Severity tier: low, medium, or high.",
        examples=["medium"],
    )


class DiagnosisModel(BaseModel):
    """Single diagnosis outcome with geometry and model metadata."""

    model_config = ConfigDict(populate_by_name=True)

    diagnosis_id: UUID = Field(
        default_factory=uuid4,
        alias="diagnosisId",
        description="Unique id for this diagnosis record; defaults to a new UUID v4.",
        examples=["550e8400-e29b-41d4-a716-446655440000"],
    )
    confidence_score: float = Field(
        alias="confidenceScore",
        ge=0.0,
        le=1.0,
        description="Model confidence for this detection (0–1).",
        examples=[0.87],
    )
    model_version: str = Field(
        alias="modelVersion",
        description="Inference model version or artifact tag.",
        examples=["yolov8-muzhir-v1.2"],
    )
    bounding_box: BoundingBoxModel = Field(
        alias="boundingBox",
        description="Normalized bounding box for the detection.",
        examples=[{"x": 0.1, "y": 0.1, "width": 0.4, "height": 0.3}],
    )
    disease: DiseaseSnapshotModel = Field(
        description="Disease snapshot at inference time.",
        examples=[
            {
                "diseaseId": "tomato_early_blight",
                "diseaseName": "Early blight",
                "diseaseNameAr": "اللفحة المبكرة",
                "severity": "medium",
            }
        ],
    )
    recommendation: Optional[RecommendationModel] = Field(
        default=None,
        description=(
            "Optional treatment recommendation; omit until generated so scan+diagnosis "
            "still load in one read when present."
        ),
        examples=[
            {
                "treatmentText": "Apply fungicide and prune affected leaves.",
                "treatmentTextAr": "رش مبيد فطري وقلم الأوراق المصابة.",
                "citedSources": ["MEWA tomato guide"],
                "generatedBy": "llm",
            }
        ],
    )
