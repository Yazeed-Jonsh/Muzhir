"""Firebase Admin bootstrap and Firestore helper utilities."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore

DEFAULT_SERVICE_ACCOUNT_PATH = (
    Path(__file__).resolve().parents[1] / "config" / "serviceAccountKey.json"
)


def _resolve_service_account_path() -> Path:
    configured_path = (
        os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH", "").strip()
        or os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    )
    if configured_path:
        return Path(configured_path).expanduser()
    return DEFAULT_SERVICE_ACCOUNT_PATH


def get_firebase_app() -> firebase_admin.App:
    """Return initialized Firebase app (singleton)."""
    try:
        return firebase_admin.get_app()
    except ValueError:
        credential = credentials.Certificate(str(_resolve_service_account_path()))
        return firebase_admin.initialize_app(credential)


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


def log_activity(*, scan_id: str, user_id: str, action_type: str) -> None:
    """Append an activity row to `/activity_logs`."""
    get_firestore_client().collection("activity_logs").add(
        {
            "scanId": scan_id,
            "userId": user_id,
            "actionType": action_type,
            "timestamp": firestore.SERVER_TIMESTAMP,
        }
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
        "createdAt": firestore.SERVER_TIMESTAMP,
        "status": "done",
        "timestamp": firestore.SERVER_TIMESTAMP,
    }
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
