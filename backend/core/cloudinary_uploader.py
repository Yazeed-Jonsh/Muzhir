"""Cloudinary image upload helpers for backend endpoints."""

from __future__ import annotations

import io
from typing import Optional
from urllib.parse import unquote, urlparse

import cloudinary
import cloudinary.uploader

from backend.core.config import settings

_CONFIGURED = False


def _resolve_cloudinary_credentials() -> tuple[str, str, str]:
    parsed = urlparse(settings.CLOUDINARY_URL.strip())
    cloud_name = parsed.hostname or ""
    api_key = unquote(parsed.username or "").strip()
    api_secret = unquote(parsed.password or "").strip()
    return cloud_name, api_key, api_secret


def _ensure_configured() -> None:
    """Configure Cloudinary client from settings once."""
    global _CONFIGURED
    if _CONFIGURED:
        return

    if not settings.CLOUDINARY_URL.strip():
        raise RuntimeError("Missing Cloudinary configuration. Set CLOUDINARY_URL.")

    cloud_name, api_key, api_secret = _resolve_cloudinary_credentials()
    if not cloud_name or not api_key or not api_secret:
        raise RuntimeError("Invalid CLOUDINARY_URL. Expected cloud_name, api_key, and api_secret.")

    cloudinary.config(
        cloud_name=cloud_name,
        api_key=api_key,
        api_secret=api_secret,
        secure=True,
    )
    print("DEBUG: Cloudinary configured with explicit credentials parsed from CLOUDINARY_URL.")
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
