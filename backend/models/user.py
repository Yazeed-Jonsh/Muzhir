"""
User Data Models

This module defines the Pydantic models for user-related data, matching the Firestore 
schema precisely. These models serve as the contract for FastAPI endpoint validation.
"""

from typing import List, Literal, Optional
from pydantic import BaseModel, Field


class RoleModel(BaseModel):
    """Represents an embedded user role."""
    roleName: str = Field(
        ..., 
        description="The name of the user role", 
        example="farmer"
    )


class FavoriteCropModel(BaseModel):
    """Represents a reference to a favorite crop."""
    cropId: str = Field(
        ..., 
        description="The unique ID of the favorite crop", 
        example="tomato_01"
    )


class UserModel(BaseModel):
    """
    Master User model mapping to /users/{userId} in Firestore.
    Enforces strict schema validation before processing any Firestore write operations.
    """
    
    userId: str = Field(
        ..., 
        description="The unique identifier managed by Firebase Auth", 
        example="abc123xyz"
    )
    
    fullName: str = Field(
        ..., 
        description="Full name of the user", 
        example="Thamer Alruqi"
    )
    
    email: str = Field(
        ..., 
        description="User email address", 
        example="thamer@example.com"
    )
    
    # Restricting values to 'en' or 'ar' to automatically trigger HTTP 422 
    # if the client sends an unsupported language payload.
    preferredLanguage: Literal["en", "ar"] = Field(
        default="ar", 
        description="User's language preference ('en' or 'ar')", 
        example="ar"
    )
    
    role: RoleModel = Field(
        ..., 
        description="The embedded role object defining user permissions"
    )
    
    # Defined as Optional[List[Optional[str]]] to safely handle null arrays 
    # or empty entries arriving from NoSQL Firestore documents.
    favoriteCrops: Optional[List[Optional[str]]] = Field(
        default=None, 
        description="Array of favorite crop IDs", 
        example=["tomato_01", "wheat_02"]
    )