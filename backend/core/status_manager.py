"""Helpers for scan image lifecycle status updates."""

from firebase_admin import firestore

from backend.core.firebase_config import get_firestore_client


def set_scan_status(scan_id: str, status: str) -> None:
    """Atomically update only the nested image status fields for a scan."""
    get_firestore_client().collection("scans").document(scan_id).update(
        {
            "image.status": status,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
    )
