"""Firebase Admin bootstrap and Cloud Storage helpers."""

from __future__ import annotations

import traceback
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, storage

DEFAULT_SERVICE_ACCOUNT_PATH = (
    Path(__file__).resolve().parents[1] / "config" / "serviceAccountKey.json"
)
DEFAULT_STORAGE_BUCKET = "muzhir-abf11.firebasestorage.app"


def get_firebase_app() -> firebase_admin.App:
    """Return initialized Firebase app (singleton)."""
    try:
        return firebase_admin.get_app()
    except ValueError:
        credential = credentials.Certificate("backend/config/serviceAccountKey.json")
        bucket_name = DEFAULT_STORAGE_BUCKET
        options = {"storageBucket": bucket_name}
        return firebase_admin.initialize_app(credential, options)


def upload_scan_image(scan_id: str, image_bytes: bytes) -> str:
    """Upload bytes to Cloud Storage and return a public URL."""
    bucket_name = DEFAULT_STORAGE_BUCKET
    credential_source = "backend/config/serviceAccountKey.json"
    print(
        "[Firebase Upload] Starting upload with "
        f"bucket='{bucket_name}' credential_source='{credential_source}' scan_id='{scan_id}'"
    )

    try:
        app = get_firebase_app()
        blob_path = f"scans/{scan_id}/image.jpg"

        bucket = storage.bucket(name=bucket_name, app=app)
        blob = bucket.blob(blob_path)
        blob.upload_from_string(image_bytes, content_type="image/jpeg")
        blob.make_public()
        return blob.public_url
    except Exception as exc:
        # Some projects still use the legacy default bucket name (*.appspot.com).
        if "The specified bucket does not exist." in str(exc):
            fallback_bucket_name = DEFAULT_STORAGE_BUCKET.replace(
                ".firebasestorage.app", ".appspot.com"
            )
            print(
                "[Firebase Upload] Retrying upload with fallback bucket "
                f"'{fallback_bucket_name}'"
            )
            app = get_firebase_app()
            bucket = storage.bucket(name=fallback_bucket_name, app=app)
            blob = bucket.blob(f"scans/{scan_id}/image.jpg")
            blob.upload_from_string(image_bytes, content_type="image/jpeg")
            blob.make_public()
            return blob.public_url

        traceback.print_exc()
        raise
