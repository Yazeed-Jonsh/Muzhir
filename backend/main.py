"""
Main Application Entry Point

This file initializes the FastAPI application, registers the AI model lifespan,
configures CORS, and defines the system health check endpoint.
"""

from api.history import router as history_router
from api.scanner import router as scanner_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Import the model lifespan manager built in Task 3.1
from inference.model_loader import lifespan

# Initialize the FastAPI app and attach the AI model lifecycle manager
app = FastAPI(
    title="Muzhir Backend API",
    description="Agricultural Disease Detection API powered by YOLO and ChatGPT",
    version="1.0.0",
    lifespan=lifespan
)

# CORS configuration to securely allow the Flutter app to communicate with the server
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict this to specific domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", tags=["System"])
async def health_check():
    """
    Health Check Endpoint.
    Used by cloud providers (e.g., Google Cloud) to verify that the server is running
    and the AI model is successfully loaded into memory.
    """
    model_status = "offline"
    
    # Check if the YOLO model is actually loaded in the application state
    if getattr(app.state, "yolo_model", None) is not None:
        model_status = "online"

    return {
        "status": "healthy",
        "ai_engine": model_status,
        "message": "Muzhir Backend is running smoothly."
    }

app.include_router(scanner_router)
app.include_router(history_router)