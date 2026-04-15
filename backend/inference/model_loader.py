"""YOLO model loader service for FastAPI lifespan startup."""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from ultralytics import YOLO

from backend.inference.class_mapper import ClassMapper

WEIGHTS_PATH = Path(__file__).resolve().parents[1] / "assets" / "best.pt"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load YOLO26-M once at startup and expose it via app.state."""
    if not WEIGHTS_PATH.exists():
        raise RuntimeError(
            f"YOLO weights not found at {WEIGHTS_PATH}. App startup failed."
        )

    app.state.yolo_model = YOLO(str(WEIGHTS_PATH))
    app.state.class_mapper = ClassMapper()
    print("YOLO26-M loaded successfully (640x640)")

    try:
        yield
    finally:
        app.state.yolo_model = None
        app.state.class_mapper = None
