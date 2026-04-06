"""
AI Model Loader Service

This module is responsible for loading the YOLO26-M inference model into memory
exactly once during the FastAPI application startup phase. 
It implements a fail-fast mechanism if the weights file is missing.
"""

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from ultralytics import YOLO  # Assuming Ultralytics is used for YOLO models

# Defining the path to the YOLO weights. In production, this can be set via env variables.
YOLO_WEIGHTS_PATH = os.getenv("YOLO_WEIGHTS_PATH", "weights/yolo26-m.pt")

def load_yolo_model() -> YOLO:
    """
    Loads the YOLO model from the disk.
    Raises a RuntimeError if the weights file cannot be found.
    """
    # Fail-fast mechanism: Do not start the server if the AI model is missing
    if not os.path.exists(YOLO_WEIGHTS_PATH):
        raise RuntimeError(
            f"CRITICAL: YOLO weights file missing at '{YOLO_WEIGHTS_PATH}'. "
            "Server cannot start without the inference engine."
        )
    
    print(f"Loading YOLO26-M weights from {YOLO_WEIGHTS_PATH}...")
    model = YOLO(YOLO_WEIGHTS_PATH)
    return model

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    FastAPI lifespan manager.
    Executes startup code before the server starts receiving requests,
    and cleanup code when the server shuts down.
    """
    # --- Startup Phase ---
    try:
        # Load the model and attach it to the global application state
        app.state.yolo_model = load_yolo_model()
        print("YOLO26-M loaded successfully (640x640). Inference engine is ready.")
    except Exception as e:
        print(f"Failed to initialize the AI Inference Engine: {e}")
        raise e  # Prevent server from starting if model loading fails
    
    yield  # Server is now running and accepting requests
    
    # --- Shutdown Phase ---
    # Clear the model from memory gracefully when the server stops
    print("Shutting down AI Inference Engine...")
    app.state.yolo_model = None