"""
Diagnose API Router

This module handles the main /diagnose endpoint.
It accepts image uploads, verifies the user, triggers background processing 
for AI inference, and immediately returns a 'processing' status to the client.
"""

import uuid
from fastapi import APIRouter, UploadFile, File, Depends, BackgroundTasks, Request, HTTPException

# Import the security middleware
from api.auth import verify_firebase_token

# Import our response schema and internal models
from schemas.responses import DiagnoseResponse
from models.scan import ImageStatus
from inference.runner import run_yolo_inference
from inference.llm_client import get_treatment_recommendation

# Initialize the router
router = APIRouter(prefix="/diagnose", tags=["Diagnosis"])

async def background_ai_processing(scan_id: str, image_bytes: bytes, request: Request, user_id: str):
    """
    Background task that handles the heavy lifting:
    1. Uploads image to Firebase Storage.
    2. Runs YOLO inference.
    3. Fetches ChatGPT recommendations if a disease is found.
    4. Updates the Firestore document with the final status.
    """
    try:
        # NOTE: In production, upload `image_bytes` to Firebase Storage here and get the URL
        mock_image_url = f"https://storage.googleapis.com/muzhir-bucket/scans/{scan_id}.jpg"

        # Step 1: Run YOLO Inference (Computer Vision)
        diagnosis = run_yolo_inference(image_bytes, request)

        # Step 2: If a disease is detected, ask ChatGPT for a treatment plan
        if diagnosis is not None:
            recommendation = await get_treatment_recommendation(
                disease_name_en=diagnosis.diseaseSnapshot.diseaseName,
                disease_name_ar=diagnosis.diseaseSnapshot.diseaseNameAr
            )
            diagnosis.recommendation = recommendation

        # Step 3: Update Firestore document (Placeholder for actual Firebase Admin DB call)
        # db.collection("scans").document(scan_id).update({
        #     "status": "done",
        #     "imageUrl": mock_image_url,
        #     "diagnosis": diagnosis.dict() if diagnosis else None
        # })
        
        print(f"✅ Background processing complete for scan: {scan_id}")

    except Exception as e:
        # Step 4: Handle failures gracefully by updating the DB status to 'failed'
        print(f"❌ Background task failed for scan {scan_id}: {e}")
        # db.collection("scans").document(scan_id).update({"status": "failed"})


@router.post("/", response_model=DiagnoseResponse)
async def create_diagnosis(
    request: Request,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    user_token: dict = Depends(verify_firebase_token)
):
    """
    Uploads a leaf image and starts the AI diagnosis process.
    Requires a valid Firebase Bearer token.
    Returns a 'processing' status immediately to keep the mobile UI responsive.
    """
    # Validate that the uploaded file is actually an image
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Invalid file type. Please upload an image.")

    # Read the file into memory
    image_bytes = await file.read()
    
    # Extract the authenticated user ID from the Firebase token
    user_id = user_token.get("uid")
    
    # Generate a unique ID for this scan
    scan_id = str(uuid.uuid4())

    # NOTE: In production, create the initial Firestore document here
    # db.collection("scans").document(scan_id).set({"status": "processing", ...})

    # Add the heavy AI pipeline to the background tasks
    background_tasks.add_task(
        background_ai_processing,
        scan_id=scan_id,
        image_bytes=image_bytes,
        request=request,
        user_id=user_id
    )

    # Return immediate response to the Flutter app
    return DiagnoseResponse(
        scanId=scan_id,
        status=ImageStatus.processing,
        imageUrl="uploading_in_background" 
    )