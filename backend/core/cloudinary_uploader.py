"""Cloudinary image upload helpers for backend endpoints."""

from __future__ import annotations

import io
import os
from typing import Optional
from urllib.parse import unquote, urlparse

import cloudinary
import cloudinary.uploader

_CONFIGURED = False


def _ensure_configured() -> None:
    """Configure Cloudinary client from env vars once."""
    global _CONFIGURED
    if _CONFIGURED:
        return

    cloud_name = os.getenv("CLOUDINARY_CLOUD_NAME", "").strip()
    api_key = os.getenv("CLOUDINARY_API_KEY", "").strip()
    api_secret = os.getenv("CLOUDINARY_API_SECRET", "").strip()

    if not cloud_name or not api_key or not api_secret:
        raise RuntimeError(
            "Missing Cloudinary configuration. Set CLOUDINARY_CLOUD_NAME, "
            "CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET."
        )

    cloudinary.config(
        cloud_name=cloud_name,
        api_key=api_key,
        api_secret=api_secret,
        secure=True,
    )
    _CONFIGURED = True


def upload_image_asset(
    image_bytes: bytes,
    *,
    folder: str,
    public_id: Optional[str] = None,
    filename: str = "upload.jpg",
) -> tuple[str, str]:
    """Upload bytes to Cloudinary and return (secure_url, public_id)."""
    _ensure_configured()

    buffer = io.BytesIO(image_bytes)
    buffer.name = filename
    result = cloudinary.uploader.upload(
        buffer,
        resource_type="image",
        folder=folder,
        public_id=public_id,
        overwrite=True,
    )

    secure_url = str(result.get("secure_url", "")).strip()
    resolved_public_id = str(result.get("public_id", "")).strip()
    if not secure_url or not resolved_public_id:
        raise RuntimeError("Cloudinary upload completed but returned no secure_url/public_id.")
    return secure_url, resolved_public_id


def upload_image(
    image_bytes: bytes,
    *,
    folder: str,
    public_id: Optional[str] = None,
    filename: str = "upload.jpg",
) -> str:
    """Upload bytes to Cloudinary and return the secure URL."""
    secure_url, _ = upload_image_asset(
        image_bytes,
        folder=folder,
        public_id=public_id,
        filename=filename,
    )
    return secure_url


def _extract_public_id_from_url(image_url: str) -> str:
    """Extract Cloudinary public id from a secure_url."""
    parsed = urlparse(image_url)
    path_parts = [part for part in parsed.path.split("/") if part]
    if "upload" not in path_parts:
        raise ValueError("Provided URL is not a Cloudinary upload URL.")

    upload_idx = path_parts.index("upload")
    public_parts = path_parts[upload_idx + 1 :]
    if public_parts and public_parts[0].startswith("v") and public_parts[0][1:].isdigit():
        public_parts = public_parts[1:]
    if not public_parts:
        raise ValueError("Cloudinary URL does not include a public id path.")

    joined = "/".join(public_parts)
    if "." in joined:
        joined = joined.rsplit(".", 1)[0]
    public_id = unquote(joined).strip()
    if not public_id:
        raise ValueError("Could not resolve public id from Cloudinary URL.")
    return public_id


def delete_image(*, public_id: Optional[str] = None, image_url: Optional[str] = None) -> bool:
    """Delete an image by explicit public_id or Cloudinary image URL."""
    _ensure_configured()
    resolved_public_id = (public_id or "").strip()
    if not resolved_public_id:
        if not image_url or not image_url.strip():
            raise ValueError("Either public_id or image_url must be provided.")
        resolved_public_id = _extract_public_id_from_url(image_url)

    result = cloudinary.uploader.destroy(resolved_public_id, resource_type="image")
    return str(result.get("result", "")).lower() in {"ok", "not found"}
