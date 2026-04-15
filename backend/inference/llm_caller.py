"""Groq-based recommendation caller (Task 3.5)."""

from __future__ import annotations

import asyncio
import json
import os
from pathlib import Path

from dotenv import load_dotenv
from groq import Groq

from backend.models.recommendation import RecommendationModel

ROOT_ENV_PATH = Path(__file__).resolve().parents[2] / ".env"
load_dotenv(dotenv_path=ROOT_ENV_PATH, override=True)

_startup_key = os.getenv("GROQ_API_KEY")
if not _startup_key:
    module_dir = Path(__file__).resolve().parent
    fallback_paths = [
        module_dir / ".env",
        module_dir.parent / ".env",
        Path.cwd() / ".env",
        Path.cwd().parent / ".env",
    ]
    for env_path in fallback_paths:
        if env_path.exists():
            load_dotenv(dotenv_path=env_path, override=True)
            _startup_key = os.getenv("GROQ_API_KEY")
            if _startup_key:
                break

if _startup_key:
    _startup_key = _startup_key.strip().strip('"').strip("'")
    os.environ["GROQ_API_KEY"] = _startup_key
    print(f"Using Groq API Key starting with: {_startup_key[:5]}")
else:
    print("Using Groq API Key starting with: <missing>")
    print("CRITICAL: GROQ_API_KEY NOT LOADED FROM ENV")

PROMPT_PATH = Path(__file__).resolve().parents[1] / "prompts" / "treatment_prompt.txt"
MODEL_NAME = "llama-3.1-8b-instant"


def _render_prompt(context: dict) -> str:
    template = PROMPT_PATH.read_text(encoding="utf-8")
    return (
        template.replace("{{disease_name}}", str(context.get("disease_name", "Unknown")))
        .replace("{{severity}}", str(context.get("severity", "low")))
        .replace("{{crop_type}}", str(context.get("crop_type", "Unknown")))
        .replace("{{growth_stage}}", str(context.get("growth_stage", "Unknown")))
    )


def _extract_json(text: str) -> dict:
    cleaned = text.strip()
    if "```" in cleaned:
        cleaned = cleaned.replace("```json", "").replace("```", "").strip()

    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("Gemini response does not contain a valid JSON object.")
    return json.loads(cleaned[start : end + 1])


def _call_groq(prompt: str, disease_name: str) -> str:
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError("GROQ_API_KEY is missing.")

    client = Groq(api_key=api_key)
    print(f"Sending request to Groq for: {disease_name}")
    response = client.chat.completions.create(
        model=MODEL_NAME,
        messages=[
            {
                "role": "system",
                "content": (
                    "You are a Saudi agricultural expert. Return only valid JSON with "
                    "exactly: treatmentText and treatmentTextAr."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        temperature=0.2,
    )
    print(f"Groq full response: {response}")
    content = response.choices[0].message.content if response.choices else ""
    return (content or "").strip()


def get_mock_recommendation(disease_name: str) -> RecommendationModel:
    """Return deterministic bilingual fallback advice for demos/offline mode."""
    disease_key = (disease_name or "").strip().lower()

    recommendations = {
        "tomato mildiou": (
            "Treat as late blight: remove infected leaves, reduce leaf wetness, and apply an approved anti-oomycete fungicide on schedule.",
            "عالجها كلفحة متأخرة: أزل الأوراق المصابة، وقلل بلل الأوراق، واستخدم مبيداً معتمداً ضد الأوميستات وفق جدول منتظم.",
        ),
        "late blight": (
            "Remove infected leaves, avoid overhead irrigation, and apply an approved fungicide every 7-10 days.",
            "أزل الأوراق المصابة، وتجنب الري بالرش العلوي، واستخدم مبيداً فطرياً معتمداً كل 7 إلى 10 أيام.",
        ),
        "early blight": (
            "Prune affected foliage, improve airflow, and start a preventive fungicide schedule.",
            "قلم الأوراق المصابة، وحسن التهوية، وابدأ برنامجاً وقائياً بالمبيد الفطري.",
        ),
        "powdery mildew": (
            "Reduce humidity around plants, remove heavily infected parts, and apply sulfur-based treatment if suitable.",
            "خفف الرطوبة حول النباتات، وأزل الأجزاء شديدة الإصابة، واستخدم علاجاً قائماً على الكبريت إذا كان مناسباً.",
        ),
        "rust": (
            "Remove infected leaves early, avoid wetting foliage, and use a targeted fungicide according to label instructions.",
            "أزل الأوراق المصابة مبكراً، وتجنب تبليل المجموع الخضري، واستخدم مبيداً فطرياً موجهاً حسب التعليمات.",
        ),
    }

    treatment_en, treatment_ar = recommendations.get(
        disease_key,
        (
            "Monitor plants daily, remove visibly infected tissue, optimize irrigation and ventilation, and consult local extension guidance.",
            "راقب النباتات يومياً، وأزل الأنسجة المصابة بوضوح، وحسّن الري والتهوية، وارجع لإرشادات الإرشاد الزراعي المحلي.",
        ),
    )

    return RecommendationModel(
        treatment_text=treatment_en,
        treatment_text_ar=treatment_ar,
        cited_sources=["smart-mock"],
        generated_by="manual",
    )


async def get_recommendation(context: dict) -> RecommendationModel:
    """Get bilingual recommendation from Groq, fallback to smart mock on any failure."""
    disease_name = str(context.get("disease_name", "unknown"))
    try:
        print(f"Groq Context: {context}")
        prompt = _render_prompt(context)
        raw_text = await asyncio.wait_for(
            asyncio.to_thread(_call_groq, prompt, disease_name),
            timeout=20,
        )
        payload = _extract_json(raw_text)
        return RecommendationModel(
            treatment_text=str(payload["treatmentText"]).strip(),
            treatment_text_ar=str(payload["treatmentTextAr"]).strip(),
            cited_sources=[],
            generated_by="llm",
        )
    except Exception as exc:
        print(f"Groq Error: {exc}")
        return get_mock_recommendation(disease_name)
