"""Image preprocessing for YOLO26-M (640x640 baseline pipeline)."""

from __future__ import annotations

import cv2
import numpy as np


def preprocess(image_bytes: bytes) -> np.ndarray:
    """Decode image bytes and return a resized OpenCV BGR image (640x640)."""
    encoded = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(encoded, cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("Unable to decode image bytes.")

    resized = cv2.resize(image, (640, 640), interpolation=cv2.INTER_LINEAR)
    return resized
