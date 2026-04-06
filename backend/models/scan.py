"""
Scan and Image Data Models

This module defines the master ScanModel and its embedded components 
(Image, GeoPoint, Batch) matching the /scans/{scanId} Firestore collection.
It strictly enforces backend rules like soft-deletion and the image status lifecycle.
"""
from .crop import CropModel
from .diagnosis import DiagnosisModel
from datetime import datetime
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field


class ImageStatus(str, Enum):
    """
    Enum representing the strict lifecycle of an uploaded image in Firestore.
    Matches the exact string values expected by the Flutter frontend.
    """
    pending = "pending"
    processing = "processing"
    done = "done"
    failed = "failed"


class GeoPointModel(BaseModel):
    """Represents geographical coordinates where the scan was taken."""
    lat: float = Field(..., description="Latitude coordinate", example=21.4858)
    lng: float = Field(..., description="Longitude coordinate", example=39.1925)


class BatchModel(BaseModel):
    """Optional model for grouping multiple scans together (e.g., scanning a whole field)."""
    batchId: str = Field(..., description="Unique identifier for the batch")
    batchName: str = Field(..., description="Human-readable name for the batch")


class ImageModel(BaseModel):
    """
    Embedded document containing image metadata.
    Status is strictly managed by the backend lifecycle manager.
    """
    imageUrl: str = Field(
        ..., 
        description="Firebase Storage URL of the uploaded image"
    )
    
    # Using Enum to restrict status values. Defaults to 'pending' as required.
    status: ImageStatus = Field(
        default=ImageStatus.pending, 
        description="Lifecycle status of the AI inference process"
    )
    
    # Defaults to False to preserve historical data for YOLO retraining (Soft Delete).
    isDeleted: bool = Field(
        default=False, 
        description="Soft delete flag to hide from UI but keep in database"
    )


class ScanModel(BaseModel):
    """
    Master Scan Document mapping to /scans/{scanId}.
    Serves as the root container to enforce the One-Read Rule constraint.
    """
    scanId: str = Field(..., description="Firestore document auto-ID")
    
    # Will fail validation immediately with 422 if Flutter app forgets to send userId.
    userId: str = Field(..., description="Owner of the scan, matches Firebase Auth UID")
    
    # Embedded crop data to satisfy the One-Read Rule
    crop: CropModel = Field(..., description="Details of the scanned crop")

    # Diagnosis block populated by the AI inference pipeline
    diagnosis: Optional[DiagnosisModel] = Field(
        default=None, 
        description="AI diagnosis details. Null until inference is complete."
    )
    
    createdAt: datetime = Field(
        default_factory=datetime.utcnow, 
        description="Timestamp of scan creation (UTC)"
    )
    
    image: ImageModel = Field(..., description="Embedded image metadata and status")
    
    # Location and batch are defined as Optional based on the farmer's input.
    location: Optional[GeoPointModel] = Field(
        default=None, 
        description="Optional geographical location"
    )
    
    batch: Optional[BatchModel] = Field(
        default=None, 
        description="Optional batch grouping info"
    )

    # Note: crop, diagnosis, and recommendation models will be added 
    # here in Tasks 2.3, 2.4, and 2.5 to complete the One-Read Rule hierarchy.