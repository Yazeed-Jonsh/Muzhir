"""
Authentication Middleware

This module provides dependency functions to protect API routes.
It validates Firebase ID Tokens (JWT) sent by the Flutter app 
to ensure only authenticated users can access the AI models.
"""

from fastapi import HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, credentials, initialize_app
import os

# 1. Initialize Firebase Admin SDK
# This requires a serviceAccountKey.json file from Firebase Console
if not any(os.environ.get(k) for k in ["FIREBASE_CONFIG", "GOOGLE_APPLICATION_CREDENTIALS"]):
    # If no env var is set, we assume local development with a file
    try:
        cred = credentials.Certificate("config/serviceAccountKey.json")
        initialize_app(cred)
    except Exception as e:
        print(f"Warning: Firebase Admin not initialized: {e}")

# Use HTTPBearer to handle 'Authorization: Bearer <TOKEN>' headers
security = HTTPBearer()

async def verify_firebase_token(auth_creds: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """
    Dependency that validates the Firebase JWT token.
    
    Args:
        auth_creds: The Bearer token extracted from the Authorization header.
        
    Returns:
        dict: The decoded user information (uid, email, etc.).
        
    Raises:
        HTTPException: 401 if token is invalid or expired.
    """
    token = auth_creds.credentials
    
    try:
        # Verify the token against Firebase servers
        decoded_token = auth.verify_id_token(token)
        return decoded_token
        
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Your session has expired. Please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials.",
            headers={"WWW-Authenticate": "Bearer"},
        )