"""Inference runner: direct ONNX Runtime decoding — no ultralytics/torch.

YOLOv8 ONNX export format (Ultralytics default, no NMS in graph):
  Input  : (1, 3, 640, 640) float32 [0, 1]
  Output : (1, 4 + nc, num_anchors)  — cx/cy/w/h in pixel coords, then
           per-class probabilities (sigmoid already applied).

We transpose to (num_anchors, 4+nc), pick the anchor with the highest
max-class score, and convert bbox to normalised xywh.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
from typing import Optional

import numpy as np
import onnxruntime as ort

from backend.core.config import settings
from backend.inference.preprocessor import preprocess


@dataclass
class InferenceResult:
    """Parsed top YOLO detection for downstream mapping."""

    class_id: int
    yolo_label: str
    confidence: float
    bbox: dict[str, float]
    model_version: str


def _parse_class_names(session: ort.InferenceSession) -> dict[int, str]:
    """Read class names from ONNX model metadata (Ultralytics export convention)."""
    try:
        meta = session.get_modelmeta().custom_metadata_map
        raw = meta.get("names", "")
        if raw:
            parsed = ast.literal_eval(raw)
            return {int(k): str(v) for k, v in parsed.items()}
    except Exception:
        pass
    return {}


def run_inference(
    image_bytes: bytes, session: ort.InferenceSession
) -> Optional[InferenceResult]:
    """Preprocess image bytes, run ONNX session, decode top detection."""
    tensor = preprocess(image_bytes)  # (1, 3, 640, 640) float32

    input_name = session.get_inputs()[0].name
    output_name = session.get_outputs()[0].name
    raw = session.run([output_name], {input_name: tensor})[0]  # (1, ?, ?)

    # Standard YOLOv8 export: (1, 4+nc, num_anchors) — axis-1 is smaller.
    # Transpose so rows are anchors and columns are [cx, cy, w, h, *scores].
    preds = raw[0].T if raw.shape[1] < raw.shape[2] else raw[0]

    scores = preds[:, 4:]         # (num_anchors, nc)
    conf = scores.max(axis=1)     # (num_anchors,)
    best_idx = int(conf.argmax())
    best_conf = float(conf[best_idx])

    if best_conf < settings.MIN_CONFIDENCE_THRESHOLD:
        return None

    class_id = int(scores[best_idx].argmax())
    names = _parse_class_names(session)
    yolo_label = names.get(class_id, f"class_{class_id}")

    # Bbox: cx, cy, w, h in pixel coords → normalised x1, y1, w, h
    cx = float(preds[best_idx, 0])
    cy = float(preds[best_idx, 1])
    w = float(preds[best_idx, 2])
    h = float(preds[best_idx, 3])
    s = 640.0
    x = max(0.0, min(1.0, (cx - w / 2) / s))
    y = max(0.0, min(1.0, (cy - h / 2) / s))

    return InferenceResult(
        class_id=class_id,
        yolo_label=yolo_label,
        confidence=best_conf,
        bbox={
            "x": x,
            "y": y,
            "w": max(0.0, min(1.0, w / s)),
            "h": max(0.0, min(1.0, h / s)),
        },
        model_version="yolo26-m",
    )
