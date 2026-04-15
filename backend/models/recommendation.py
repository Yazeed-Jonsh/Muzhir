"""Treatment recommendation embedded under diagnosis (Task 2.5)."""

from __future__ import annotations

from typing import List, Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field


class RecommendationModel(BaseModel):
    """Bilingual treatment text and provenance, stored with diagnosis for one-read fetch."""

    model_config = ConfigDict(populate_by_name=True)

    recommendation_id: UUID = Field(
        default_factory=uuid4,
        alias="recommendationId",
        description="Unique id for this recommendation; defaults to a new UUID v4.",
        examples=["6ba7b810-9dad-11d1-80b4-00c04fd430c8"],
    )
    treatment_text: str = Field(
        alias="treatmentText",
        description="English treatment / management recommendation text.",
        examples=["Apply fungicide X and improve airflow between plants."],
    )
    treatment_text_ar: str = Field(
        alias="treatmentTextAr",
        description="Arabic treatment / management recommendation text.",
        examples=["استخدم مبيد فطري X وحسّن التهوية بين النباتات."],
    )
    cited_sources: List[str] = Field(
        default_factory=list,
        alias="citedSources",
        description="References or source labels supporting the recommendation.",
        examples=[["extension bulletin #12", "MEWA crop guide"]],
    )
    generated_by: Literal["llm", "manual"] = Field(
        alias="generatedBy",
        description="Whether the text was produced by an LLM or entered manually.",
        examples=["llm"],
    )
