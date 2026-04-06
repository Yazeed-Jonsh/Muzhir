"""
AI Inference Runner

This module orchestrates the entire AI inference pipeline for YOLO26-M.
It connects the preprocessor, the in-memory model, and the class mapper
to return a strictly validated DiagnosisModel ready for Firestore.
"""

import uuid
from typing import Optional
from fastapi import Request
from pydantic import ValidationError

from .preprocessor import preprocess
from .class_mapper import get_disease_snapshot
from models.diagnosis import DiagnosisModel, BoundingBoxModel


def run_yolo_inference(image_bytes: bytes, request: Request) -> Optional[DiagnosisModel]:
    """
    Executes the YOLO inference pipeline on the provided image bytes.
    
    Args:
        image_bytes (bytes): The raw image uploaded by the Flutter app.
        request (Request): The FastAPI request object to access app.state.
        
    Returns:
        DiagnosisModel: If a disease is detected.
        None: If the image contains no detectable crops or diseases.
    """
    # 1. Access the in-memory AI model (Fail-fast if not loaded)
    model = getattr(request.app.state, "yolo_model", None)
    if model is None:
        raise RuntimeError("CRITICAL: AI Inference Engine is offline or not loaded into memory.")

    # 2. Preprocess the image (Resize to 640x640, Normalize, etc.)
    tensor_ready = preprocess(image_bytes)

    # 3. Run Inference (verbose=False to keep server logs clean)
    # Using the preprocessed numpy array directly
    results = model.predict(tensor_ready, verbose=False)
    
    # We only process the first result since we passed a single image (batch size 1)
    result = results[0]

    # 4. Check if YOLO found anything
    if len(result.boxes) == 0:
        return None  # No disease or crop detected in the image

    # For the baseline, we take the bounding box with the highest confidence
    # YOLO automatically sorts result.boxes by confidence in descending order
    best_box = result.boxes[0]

    # 5. Extract raw data from YOLO tensor outputs
    class_id = int(best_box.cls[0].item())
    confidence_score = float(best_box.conf[0].item())
    
    # Extract normalized coordinates (xywhn format: x_center, y_center, width, height, normalized 0.0-1.0)
    # Note: Ultralytics xywhn returns center x,y. We convert to top-left for Flutter UI if needed,
    # but for this example, we assume Flutter uses normalized center or we just pass the normalized values.
    # To keep it standard (Top-Left x, y, width, height):
    x_center, y_center, width, height = best_box.xywhn[0].tolist()
    
    # Convert center coordinates to top-left for standard UI drawing
    x_top_left = x_center - (width / 2)
    y_top_left = y_center - (height / 2)

    # 6. Retrieve bilingual disease details from the Mapper
    disease_snapshot = get_disease_snapshot(class_id)

    # 7. Construct and Validate the Pydantic Models
    try:
        # This will automatically raise 422 if coordinates exceed 1.0 or confidence is wrong
        bounding_box = BoundingBoxModel(
            x=max(0.0, x_top_left),  # Ensure it doesn't go below 0
            y=max(0.0, y_top_left),
            width=width,
            height=height
        )

        diagnosis = DiagnosisModel(
            diagnosisId=uuid.uuid4(),
            confidenceScore=confidence_score,
            boundingBox=bounding_box,
            modelVersion="YOLO26-M_v1",
            diseaseSnapshot=disease_snapshot
            # recommendation is left as None, will be filled by ChatGPT later
        )
        return diagnosis
        
    except ValidationError as e:
        # Log the critical validation error internally
        print(f"Internal Model Validation Error during inference: {e}")
        raise RuntimeError("AI model output violated data contracts.")