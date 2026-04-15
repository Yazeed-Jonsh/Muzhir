"""Class ID mapper for YOLO predictions (Task 3.3)."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class ClassMapper:
    """Map YOLO class IDs to disease ids and bilingual disease snapshots."""

    def __init__(self, map_path: Path | None = None) -> None:
        self.map_path = map_path or (
            Path(__file__).resolve().parents[1] / "config" / "class_map.json"
        )
        self._mapping: dict[str, dict[str, str]] = {}
        self._last_mtime: float | None = None
        self._load_mapping()

    def _load_mapping(self) -> None:
        with self.map_path.open("r", encoding="utf-8") as fp:
            raw = json.load(fp)

        if not isinstance(raw, dict):
            raise ValueError(f"Class map at {self.map_path} must be a JSON object.")

        validated: dict[str, dict[str, str]] = {}
        for key, value in raw.items():
            if not isinstance(value, dict) or "en" not in value or "ar" not in value:
                raise ValueError(
                    f"Invalid entry for class '{key}' in {self.map_path}; expected en/ar fields."
                )
            validated[str(key)] = {"en": str(value["en"]), "ar": str(value["ar"])}

        self._mapping = validated
        self._last_mtime = self.map_path.stat().st_mtime

    def _reload_if_changed(self) -> None:
        current_mtime = self.map_path.stat().st_mtime
        if self._last_mtime is None or current_mtime > self._last_mtime:
            self._load_mapping()

    @staticmethod
    def _slugify(value: str) -> str:
        return value.strip().lower().replace(" ", "_")

    @staticmethod
    def _normalize_label(value: str) -> str:
        return value.strip().lower().replace("_", " ")

    def get_disease_id(self, class_id: int) -> str:
        self._reload_if_changed()
        key = str(class_id)
        if key not in self._mapping:
            raise KeyError(
                f"Class ID {class_id} is not mapped in {self.map_path}. Update class_map.json."
            )
        return self._slugify(self._mapping[key]["en"])

    def get_disease_name_en(self, class_id: int) -> str:
        self._reload_if_changed()
        key = str(class_id)
        if key not in self._mapping:
            raise KeyError(
                f"Class ID {class_id} is not mapped in {self.map_path}. Update class_map.json."
            )
        return self._mapping[key]["en"]

    def get_disease_snapshot(self, class_id: int) -> dict[str, Any]:
        self._reload_if_changed()
        key = str(class_id)
        if key not in self._mapping:
            raise KeyError(
                f"Class ID {class_id} is not mapped in {self.map_path}. Update class_map.json."
            )

        entry = self._mapping[key]
        return {
            "diseaseId": self.get_disease_id(class_id),
            "diseaseName": entry["en"],
            "diseaseNameAr": entry["ar"],
            "severity": "low",
        }

    def get_disease_snapshot_by_en_name(self, disease_name_en: str) -> dict[str, Any]:
        self._reload_if_changed()
        normalized_target = self._normalize_label(disease_name_en)
        for class_id, entry in self._mapping.items():
            if self._normalize_label(entry["en"]) == normalized_target:
                resolved_id = int(class_id)
                return {
                    "diseaseId": self.get_disease_id(resolved_id),
                    "diseaseName": entry["en"],
                    "diseaseNameAr": entry["ar"],
                    "severity": "low",
                }
        raise KeyError(
            f"Disease label '{disease_name_en}' is not mapped in {self.map_path}. Update class_map.json."
        )
