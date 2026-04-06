    """
LLM Client for Treatment Recommendations

This module connects to the OpenAI API to generate agricultural treatment plans.
It uses OpenAI's Structured Outputs feature (parse method) to guarantee that 
the response strictly matches our bilingual requirements and returns a valid Pydantic model.
"""

import os
import uuid
import logging
from typing import Optional, List
from pydantic import BaseModel, Field
from openai import AsyncOpenAI

from models.recommendation import RecommendationModel, GeneratedByEnum

# Initialize the Asynchronous OpenAI client. 
# Requires OPENAI_API_KEY environment variable.
client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class LLMTreatmentResponse(BaseModel):
    """Temporary internal schema to force ChatGPT to output exactly these JSON fields."""
    treatmentText: str = Field(..., description="Detailed, step-by-step agricultural treatment plan in English")
    treatmentTextAr: str = Field(..., description="Detailed, step-by-step agricultural treatment plan in Arabic")
    citedSources: List[str] = Field(..., description="List of 2 to 3 real agricultural reference URLs or guidelines")

async def get_treatment_recommendation(disease_name_en: str, disease_name_ar: str) -> Optional[RecommendationModel]:
    """
    Calls OpenAI to generate a bilingual treatment recommendation asynchronously.
    
    Args:
        disease_name_en (str): Disease name in English (from Class Mapper).
        disease_name_ar (str): Disease name in Arabic (from Class Mapper).
        
    Returns:
        RecommendationModel: The strictly validated recommendation object.
        None: If the API call fails or times out.
    """
    system_prompt = (
        "You are an expert agricultural engineer and plant pathologist. "
        "Your task is to provide practical, safe, and accurate treatment recommendations "
        "for plant diseases. You must provide the response strictly in both English and Arabic."
    )
    
    user_prompt = f"The AI has detected the following disease: '{disease_name_en}' ({disease_name_ar}). Please provide a treatment plan."

    try:
        # Using the modern .parse() method to guarantee JSON output matches our Pydantic schema
        completion = await client.beta.chat.completions.parse(
            model="gpt-4o-mini",  # Highly cost-effective and fast for text generation
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            response_format=LLMTreatmentResponse,
            temperature=0.2  # Low temperature for factual, scientific answers (prevents hallucinations)
        )
        
        # Extract the validated Pydantic object directly from OpenAI's response
        llm_result = completion.choices[0].message.parsed
        
        if not llm_result:
             return None

        # Wrap the LLM result into our final Firestore database model (One-Read Rule structure)
        recommendation = RecommendationModel(
            recommendationId=uuid.uuid4(),
            treatmentText=llm_result.treatmentText,
            treatmentTextAr=llm_result.treatmentTextAr,
            citedSources=llm_result.citedSources,
            generatedBy=GeneratedByEnum.llm
        )
        
        return recommendation
        
    except Exception as e:
        # Graceful degradation: Log the error and return None so the app doesn't crash.
        logging.error(f"Failed to fetch recommendation from ChatGPT API: {e}")
        return None