"""ONNX Runtime model loader for FastAPI lifespan startup.

Replaces the ultralytics YOLO wrapper entirely — onnxruntime alone is
enough to run inference and saves ~200–300 MB of RSS (no PyTorch import).
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path

import onnxruntime as ort
from fastapi import FastAPI

from backend.core.config import settings
from backend.inference.class_mapper import ClassMapper


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load ONNX model once at startup and expose session via app.state."""
    weights_path = Path(settings.YOLO_WEIGHTS_PATH).expanduser()
    if not weights_path.exists():
        raise RuntimeError(
            f"YOLO weights not found at {weights_path}. App startup failed."
        )

    # Single-threaded to cap CPU usage on the free-tier container.
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = 1
    opts.inter_op_num_threads = 1

    session = ort.InferenceSession(
        str(weights_path),
        sess_options=opts,
        providers=["CPUExecutionProvider"],
    )
    app.state.onnx_session = session
    app.state.class_mapper = ClassMapper()
    print(f"YOLO26-M loaded successfully from {weights_path}")

    try:
        yield
    finally:
        app.state.onnx_session = None
        app.state.class_mapper = None
