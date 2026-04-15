"""Pydantic models aligned with Firestore `users/{userId}` (Task 2.1)."""

from __future__ import annotations

from datetime import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class RoleModel(BaseModel):
    """Role embedded on a user document (`role` object)."""

    model_config = ConfigDict(populate_by_name=True)

    role_name: str = Field(
        alias="roleName",
        description="Human-readable role label (e.g. Farmer, Admin).",
        examples=["Farmer"],
    )


class FavoriteCropModel(BaseModel):
    """Structured crop entry for APIs that return crop metadata (not the shape of `favoriteCrops` on the user doc)."""

    model_config = ConfigDict(populate_by_name=True)

    code: str = Field(
        description="Stable crop identifier code.",
        examples=["tomato"],
    )
    display_name: Optional[str] = Field(
        default=None,
        alias="displayName",
        description="Optional localized or human-readable crop name.",
        examples=["Cherry tomato"],
    )


class UserModel(BaseModel):
    """User profile document at `users/{userId}` in Firestore."""

    model_config = ConfigDict(populate_by_name=True)

    uid: str = Field(
        description="Firebase Auth UID; matches the user document id when set explicitly.",
        examples=["a1b2c3d4e5f6g7h8i9j0k1l2"],
    )
    full_name: str = Field(
        alias="fullName",
        description="User's full display name.",
        examples=["Sara Al-Mansouri"],
    )
    email: EmailStr = Field(
        description="Primary email address (no password is stored on this model).",
        examples=["sara@example.com"],
    )
    preferred_language: Literal["en", "ar"] = Field(
        alias="preferredLanguage",
        description="UI language code; must be 'en' or 'ar' (other values yield HTTP 422).",
        examples=["en"],
    )
    is_active: bool = Field(
        alias="isActive",
        description="Whether the account is active.",
        examples=[True],
    )
    role: RoleModel = Field(
        description="Embedded role object (e.g. roleName).",
        examples=[{"roleName": "Farmer"}],
    )
    favorite_crops: Optional[List[Optional[str]]] = Field(
        default=None,
        alias="favoriteCrops",
        description="Optional list of favorite crop identifiers; entries may be null.",
        examples=[["tomato", "wheat", None]],
    )
    created_at: datetime = Field(
        alias="createdAt",
        description="Account creation time (ISO 8601 or compatible).",
        examples=["2025-01-15T10:30:00Z"],
    )
