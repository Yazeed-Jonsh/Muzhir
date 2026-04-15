"""Crop and growth-stage models embedded on scan documents (Task 2.3)."""

from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field


class GrowthStageModel(BaseModel):
    """Growth stage metadata for a crop at scan time."""

    model_config = ConfigDict(populate_by_name=True)

    stage_id: str = Field(
        alias="stageId",
        description="Stable identifier for the growth stage.",
        examples=["flowering"],
    )
    stage_name: str = Field(
        alias="stageName",
        description="Human-readable growth stage label.",
        examples=["Flowering"],
    )


class CropModel(BaseModel):
    """Crop context for a scan; English and Arabic names are both required."""

    model_config = ConfigDict(populate_by_name=True)

    crop_id: str = Field(
        alias="cropId",
        description="Stable crop identifier.",
        examples=["tomato"],
    )
    crop_name: str = Field(
        alias="cropName",
        description="Crop name in English (required, non-null).",
        examples=["Tomato"],
        min_length=1,
    )
    crop_name_ar: str = Field(
        alias="cropNameAr",
        description="Crop name in Arabic (required, non-null).",
        examples=["طماطم"],
        min_length=1,
    )
    growth_stage: GrowthStageModel = Field(
        alias="growthStage",
        description="Nested growth stage for this scan.",
        examples=[{"stageId": "flowering", "stageName": "Flowering"}],
    )
