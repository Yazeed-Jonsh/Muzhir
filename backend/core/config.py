"""Application configuration loaded from environment variables."""

from __future__ import annotations

from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT_DIR = Path(__file__).resolve().parents[2]
BACKEND_DIR = ROOT_DIR / "backend"
DEFAULT_FIREBASE_CREDENTIALS_PATH = (
    Path(__file__).resolve().parents[1] / "config" / "service-account.json"
)
DEFAULT_YOLO_WEIGHTS_PATH = Path(__file__).resolve().parents[1] / "assets" / "best.onnx"


class Settings(BaseSettings):
    """Centralized application settings."""

    model_config = SettingsConfigDict(
        env_file=(ROOT_DIR / ".env", BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    FIREBASE_CREDENTIALS_PATH: str = Field(default=str(DEFAULT_FIREBASE_CREDENTIALS_PATH))
    FIREBASE_CREDENTIALS_JSON: str = Field(default="")
    CLOUDINARY_URL: str = Field(default="")
    GROQ_API_KEY: str = Field(default="")
    YOLO_WEIGHTS_PATH: str = Field(default=str(DEFAULT_YOLO_WEIGHTS_PATH))
    MIN_CONFIDENCE_THRESHOLD: float = Field(default=0.25)
    APP_VERSION: str = Field(default="1.0.0")
    SHOW_DOCS: bool = Field(default=True)


settings = Settings()
