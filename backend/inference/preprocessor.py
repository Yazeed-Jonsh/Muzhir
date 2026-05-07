"""Image preprocessing for YOLO26-M ONNX (640×640 float32 tensor).

Resize happens immediately after decode so the full-resolution phone
image (12 MP+) is never held in memory alongside the float tensor.
"""

from __future__ import annotations

import cv2
import numpy as np


def preprocess(image_bytes: bytes) -> np.ndarray:
    """Decode image bytes and return a (1, 3, 640, 640) float32 ONNX input.

    Values are normalised to [0, 1] in RGB channel order, matching the
    convention used by Ultralytics ONNX exports.
    """
    encoded = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(encoded, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Unable to decode image bytes.")

    # Resize right after decode — the full-res array is freed immediately.
    resized = cv2.resize(image, (640, 640), interpolation=cv2.INTER_LINEAR)

    # BGR → RGB, HWC → CHW, uint8 → float32 [0, 1]
    rgb = resized[:, :, ::-1]
    chw = np.ascontiguousarray(rgb.transpose(2, 0, 1), dtype=np.float32) / 255.0
    return chw[np.newaxis]  # (1, 3, 640, 640)
