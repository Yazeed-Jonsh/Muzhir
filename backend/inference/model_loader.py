"""YOLO model loader service for FastAPI lifespan startup."""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from ultralytics import YOLO

from backend.core.config import settings
from backend.inference.class_mapper import ClassMapper


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load YOLO26-M once at startup and expose it via app.state."""
    weights_path = Path(settings.YOLO_WEIGHTS_PATH).expanduser()
    if not weights_path.exists():
        raise RuntimeError(
            f"YOLO weights not found at {weights_path}. App startup failed."
        )

    app.state.yolo_model = YOLO(str(weights_path))
    app.state.class_mapper = ClassMapper()
    print(f"YOLO26-M loaded successfully from {weights_path}")

    try:
        yield
    finally:
        app.state.yolo_model = None
        app.state.class_mapper = None
