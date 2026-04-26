"""Firebase Admin bootstrap and Firestore helper utilities."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore

from backend.core.config import settings

DEFAULT_SERVICE_ACCOUNT_PATH = (
    Path(__file__).resolve().parents[1] / "config" / "service-account.json"
)
_LEGACY_SERVICE_ACCOUNT_PATH = (
    Path(__file__).resolve().parents[1] / "config" / "serviceAccountKey.json"
)


def _resolve_service_account_path() -> Path:
    configured_path = settings.FIREBASE_CREDENTIALS_PATH.strip()
    if configured_path:
        return Path(configured_path).expanduser()
    if DEFAULT_SERVICE_ACCOUNT_PATH.is_file():
        return DEFAULT_SERVICE_ACCOUNT_PATH
    if _LEGACY_SERVICE_ACCOUNT_PATH.is_file():
        return _LEGACY_SERVICE_ACCOUNT_PATH
    return DEFAULT_SERVICE_ACCOUNT_PATH


def ensure_firebase_initialized() -> None:
    """Initialize the default Firebase Admin app once (safe across uvicorn reloads)."""
    if firebase_admin._apps:
        return
    raw_json = settings.FIREBASE_CREDENTIALS_JSON.strip()
    if raw_json:
        cred = credentials.Certificate(json.loads(raw_json))
        firebase_admin.initialize_app(cred)
        return
    path = _resolve_service_account_path()
    if not path.is_file():
        raise FileNotFoundError(
            f"Firebase service account JSON not found at {path}. "
            "Set FIREBASE_CREDENTIALS_JSON or add backend/config/service-account.json "
            f"(or legacy {_LEGACY_SERVICE_ACCOUNT_PATH.name})."
        )
    cred = credentials.Certificate(str(path))
    firebase_admin.initialize_app(cred)


def get_firebase_app() -> firebase_admin.App:
    """Return the default initialized Firebase app (singleton)."""
    ensure_firebase_initialized()
    return firebase_admin.get_app()


def get_firestore_client() -> firestore.Client:
    """Create a Firestore client bound to the initialized app."""
    app = get_firebase_app()
    return firestore.client(app=app)


def get_scan_document(scan_id: str):
    """Fetch a scan document snapshot from `scans/{scanId}`."""
    return get_firestore_client().collection("scans").document(scan_id).get()


def get_user_document(user_id: str):
    """Fetch a user document snapshot from `users/{userId}`."""
    return get_firestore_client().collection("users").document(user_id).get()


def soft_delete_scan(scan_id: str) -> None:
    """Mark scan image as deleted without removing the document."""
    get_firestore_client().collection("scans").document(scan_id).set(
        {
            "image": {"isDeleted": True},
            "updatedAt": firestore.SERVER_TIMESTAMP,
        },
        merge=True,
    )


def save_scan_metadata(
    *,
    scan_id: str,
    user_id: str,
    disease_name: str,
    confidence_score: float,
    is_healthy: bool,
    recommendation: dict[str, Any] | None,
    image_url: str,
    crop_id: str,
    growth_stage_id: str,
    location: str | None,
    source: str,
    latitude: float | None = None,
    longitude: float | None = None,
) -> None:
    """Persist the core scan payload in `scans/{scanId}`."""
    payload: dict[str, Any] = {
        "scanId": scan_id,
        "userId": user_id,
        "diseaseName": disease_name,
        "confidence_score": float(confidence_score),
        "isHealthy": is_healthy,
        "recommendation": recommendation,
        "imageUrl": image_url,
        "cropId": crop_id,
        "growthStageId": growth_stage_id,
        "location": location,
        "source": source,
        "image": {"isDeleted": False},
        "timestamp": firestore.SERVER_TIMESTAMP,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    if latitude is not None:
        payload["captureLatitude"] = float(latitude)
    if longitude is not None:
        payload["captureLongitude"] = float(longitude)
    get_firestore_client().collection("scans").document(scan_id).set(payload, merge=True)


def update_user_profile_image(
    *,
    user_id: str,
    profile_image_url: str | None,
    profile_image_public_id: str | None,
) -> None:
    """Update `users/{userId}` with profile image fields."""
    payload: dict[str, Any] = {
        "profileImageUrl": profile_image_url,
        "profileImagePublicId": profile_image_public_id,
        "updatedAt": firestore.SERVER_TIMESTAMP,
    }
    get_firestore_client().collection("users").document(user_id).set(payload, merge=True)
