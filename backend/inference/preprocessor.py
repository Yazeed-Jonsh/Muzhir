"""
Image Preprocessor Module

This module is responsible for preparing raw image bytes received from the Flutter client
for YOLO26-M inference. It enforces the strict 640x640 server-side resizing rule,
normalizes pixel values, and formats the tensor as (1, 3, 640, 640).
"""

import cv2
import numpy as np

def preprocess(image_bytes: bytes) -> np.ndarray:
    """
    Decodes raw image bytes and pre-processes the image for the YOLO model.
    
    Args:
        image_bytes: The raw image data uploaded via multipart/form-data.
        
    Returns:
        A numpy array of shape (1, 3, 640, 640) ready for inference.
    """
    # 1. Decode bytes: Convert the raw bytes from Flutter into a readable OpenCV image
    np_arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if img is None:
        raise ValueError("Failed to decode image bytes. The format might be unsupported.")

    # YOLO expects RGB format, but OpenCV reads images in BGR format by default
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # 2. Server-Side Resizing: Force the image to exactly 640x640 using INTER_LINEAR interpolation
    # Note: Letterboxing is explicitly not required for the baseline implementation.
    img_resized = cv2.resize(img_rgb, (640, 640), interpolation=cv2.INTER_LINEAR)

    # 3. Normalization: Scale pixel values from [0, 255] to [0.0, 1.0] to maximize model accuracy
    img_normalized = img_resized.astype(np.float32) / 255.0

    # 4. Dimension Transposition: Convert from HWC (Height, Width, Channels) to CHW (Channels, Height, Width)
    img_chw = np.transpose(img_normalized, (2, 0, 1))

    # 5. Batch Dimension: Add a batch dimension at axis 0 -> resulting in (1, 3, 640, 640)
    tensor_ready = np.expand_dims(img_chw, axis=0)

    return tensor_ready