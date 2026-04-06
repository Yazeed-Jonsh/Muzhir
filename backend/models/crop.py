"""
Crop and Growth Stage Data Models

This module defines the embedded models for crops and their specific growth stages.
It enforces the bilingual constraint (English and Arabic) required for the Flutter UI.
"""

from pydantic import BaseModel, Field


class GrowthStageModel(BaseModel):
    """
    Embedded document representing the growth stage of the crop at the time of scanning.
    """
    stageId: str = Field(..., description="Unique identifier for the growth stage")
    stageName: str = Field(..., description="Human-readable name of the stage (e.g., 'Flowering')")


class CropModel(BaseModel):
    """
    Embedded crop document. 
    Imported and embedded directly into ScanModel to avoid separate Firestore collection reads.
    """
    cropId: str = Field(..., description="Unique identifier for the crop type")
    
    # Enforcing the bilingual constraint: Both EN and AR fields are strictly required.
    cropName: str = Field(
        ..., 
        description="Crop name in English", 
        example="Tomato"
    )
    
    cropNameAr: str = Field(
        ..., 
        description="Crop name in Arabic", 
        example="طماطم"
    )
    
    # Nesting the GrowthStageModel inside the CropModel
    growthStage: GrowthStageModel = Field(
        ..., 
        description="The specific growth stage of this crop during the scan"
    )