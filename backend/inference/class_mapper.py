"""
Class ID to Disease Mapper

This module translates raw integer class IDs output by the YOLO model 
into rich, bilingual disease metadata dictionaries.
It dynamically loads mapping from a JSON config file to allow hot-reloading 
without requiring a server restart.
"""

import json
import os
from typing import Dict, Any

# Path to the JSON configuration file
CONFIG_PATH = os.getenv("CLASS_MAP_PATH", "config/class_map.json")


def _load_mapping() -> Dict[str, Any]:
    """
    Internal helper to load the JSON file. 
    Reads the file on-demand to support hot-reloading in production.
    """
    if not os.path.exists(CONFIG_PATH):
        raise FileNotFoundError(f"CRITICAL: Disease class mapping file not found at {CONFIG_PATH}")
    
    with open(CONFIG_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def get_disease_id(class_id: int) -> str:
    """
    Retrieves the string ID for a given YOLO class index.
    
    Args:
        class_id (int): The integer class ID from YOLO.
        
    Returns:
        str: The diseaseId (e.g., 'tomato_late_blight').
    """
    mapping = _load_mapping()
    class_key = str(class_id)
    
    if class_key not in mapping:
        raise KeyError(f"Class ID {class_id} returned by YOLO is not mapped in {CONFIG_PATH}.")
        
    return mapping[class_key]["diseaseId"]


def get_disease_snapshot(class_id: int) -> Dict[str, str]:
    """
    Retrieves the complete bilingual snapshot for a given YOLO class index.
    This snapshot is embedded directly into the DiagnosisModel.
    
    Args:
        class_id (int): The integer class ID from YOLO.
        
    Returns:
        Dict: A dictionary containing diseaseId, diseaseName, diseaseNameAr, and severity.
    """
    mapping = _load_mapping()
    class_key = str(class_id)
    
    if class_key not in mapping:
        raise KeyError(f"Class ID {class_id} returned by YOLO is not mapped in {CONFIG_PATH}.")
        
    return mapping[class_key]