"""Inference runner that ties preprocessing and YOLO parsing together."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from backend.inference.preprocessor import preprocess

MIN_CONFIDENCE_THRESHOLD = 0.40


@dataclass
class InferenceResult:
    """Parsed top YOLO detection for downstream mapping."""

    class_id: int
    yolo_label: str
    confidence: float
    bbox: dict[str, float]
    model_version: str


def _resolve_model_version(model) -> str:
    ckpt_path = getattr(model, "ckpt_path", None)
    if isinstance(ckpt_path, str) and ckpt_path:
        return Path(ckpt_path).stem
    return "yolo26-m"


def run_inference(image_bytes: bytes, model) -> Optional[InferenceResult]:
    """Preprocess image bytes, run YOLO, parse top box, and apply threshold."""
    image = preprocess(image_bytes)
    results = model(image)
    result = results[0]
    boxes = getattr(result, "boxes", None)

    if boxes is None or len(boxes) == 0:
        return None

    top_idx = int(boxes.conf.argmax().item())
    confidence = float(boxes.conf[top_idx].item())
    if confidence < MIN_CONFIDENCE_THRESHOLD:
        return None

    class_id = int(boxes.cls[top_idx].item())
    names = getattr(result, "names", {}) or {}
    yolo_label = str(names.get(class_id, f"class_{class_id}"))
    x_center, y_center, width, height = [float(v) for v in boxes.xywhn[top_idx].tolist()]
    x = max(0.0, min(1.0, x_center - (width / 2.0)))
    y = max(0.0, min(1.0, y_center - (height / 2.0)))

    return InferenceResult(
        class_id=class_id,
        yolo_label=yolo_label,
        confidence=confidence,
        bbox={
            "x": x,
            "y": y,
            "w": max(0.0, min(1.0, width)),
            "h": max(0.0, min(1.0, height)),
        },
        model_version=_resolve_model_version(model),
    )
