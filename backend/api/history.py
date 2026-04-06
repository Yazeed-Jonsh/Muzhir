"""
History API Router

This module handles the retrieval of a user's scan history.
It uses the lightweight ScanSummary schema to optimize bandwidth 
and strictly enforces authorization via Firebase tokens.
"""

from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from typing import List

# Import security and schemas
from api.auth import verify_firebase_token
from schemas.responses import HistoryResponse, ScanSummary
from models.scan import ImageStatus

# Initialize the router
router = APIRouter(prefix="/history", tags=["History"])

@router.get("/", response_model=HistoryResponse)
async def get_scan_history(user_token: dict = Depends(verify_firebase_token)):
    """
    Fetches the historical scans for the authenticated user.
    The user ID is securely extracted from the validated Firebase token,
    preventing users from fetching each other's data.
    """
    user_id = user_token.get("uid")
    
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token structure.")

    # NOTE: In production, you will query Firestore here:
    # docs = db.collection("scans").where("userId", "==", user_id).where("isDeleted", "==", False).order_by("createdAt", direction="DESCENDING").limit(20).stream()
    
    # Mocking a database response for now using our lightweight schema
    mock_scans: List[ScanSummary] = [
        ScanSummary(
            scanId="scan-123",
            cropName="Tomato",
            cropNameAr="طماطم",
            createdAt=datetime.utcnow(),
            status=ImageStatus.done,
            severity="high",
            imageUrl="https://example.com/tomato_blight.jpg"
        ),
        ScanSummary(
            scanId="scan-456",
            cropName="Potato",
            cropNameAr="بطاطس",
            createdAt=datetime.utcnow(),
            status=ImageStatus.processing,
            severity=None, # Still processing, so no severity yet
            imageUrl="https://example.com/potato_scan.jpg"
        )
    ]

    # Return the validated list wrapped in our standard HistoryResponse
    return HistoryResponse(scans=mock_scans)