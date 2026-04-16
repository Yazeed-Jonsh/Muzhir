"""Background-safe activity logging helpers."""

from __future__ import annotations

import asyncio
from typing import Any

from firebase_admin import firestore

from backend.core.firebase_config import get_firestore_client


async def log_action(
    user_id: str,
    action_type: str,
    scan_id: str | None = None,
    details: dict[str, Any] | None = None,
) -> None:
    """Write an activity log entry without surfacing logging failures."""

    payload = {
        "userId": user_id,
        "actionType": action_type,
        "scanId": scan_id,
        "details": details or {},
        "timestamp": firestore.SERVER_TIMESTAMP,
    }

    try:
        await asyncio.to_thread(
            get_firestore_client().collection("activity_logs").add,
            payload,
        )
    except Exception as exc:
        print(f"Activity log failed: {exc}")
