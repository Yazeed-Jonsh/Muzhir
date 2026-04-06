"""
API Response Schemas

This module defines lightweight, strictly-typed response models.
It prevents leaking internal Firestore metadata to the Flutter client 
and ensures the Swagger UI displays clean, documented response bodies.
"""

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

# Importing components from our internal models to build the responses
from models.scan import ImageStatus
from models.diagnosis import DiagnosisModel


class DiagnoseResponse(BaseModel):
    """
    Response model for POST /diagnose.
    Returns only the essential fields needed immediately after an image upload or inference.
    """
    scanId: str = Field(..., description="The unique ID of the scan")
    status: ImageStatus = Field(..., description="Current status of the AI inference")
    imageUrl: str = Field(..., description="Download URL of the uploaded image")
    
    # Diagnosis is optional here because the status might be 'pending' or 'processing'
    diagnosis: Optional[DiagnosisModel] = Field(
        default=None, 
        description="Complete diagnosis block (null if status is not 'done')"
    )


class ScanSummary(BaseModel):
    """
    A lightweight representation of a scan used for list views (History).
    Deliberately excludes the LLM recommendation text to save bandwidth.
    """
    scanId: str = Field(..., description="The unique ID of the scan")
    cropName: str = Field(..., description="Crop name in English")
    cropNameAr: str = Field(..., description="Crop name in Arabic")
    createdAt: datetime = Field(..., description="Timestamp of the scan")
    status: ImageStatus = Field(..., description="Final status of the scan")
    
    severity: Optional[str] = Field(
        default=None, 
        description="Severity level if a disease was found, otherwise null"
    )
    
    imageUrl: str = Field(..., description="Thumbnail or main image URL")


class HistoryResponse(BaseModel):
    """
    Response model for GET /history/{userId}.
    Wraps a list of ScanSummary objects for pagination and clean JSON structure.
    """
    # Wrapping the list in an object is a REST API best practice
    scans: List[ScanSummary] = Field(
        default_factory=list, 
        description="A list of historical scan summaries for the farmer"
    )