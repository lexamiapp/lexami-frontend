from fastapi import FastAPI, HTTPException, Depends, Header
from datetime import datetime
from pydantic import BaseModel
from typing import Optional, Dict, Any
from contextlib import asynccontextmanager
from fastapi.middleware.cors import CORSMiddleware
from ai_service import AIService
from vector_db import VectorDB
import uvicorn
import os
import hashlib
import json

# Persistent data files
CACHE_FILE = "response_cache.json"
INTERACTIONS_LOG = "interactions_log.json"
FEEDBACK_LOG = "feedback_log.json"

def load_json(filepath):
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return [] if "log" in filepath else {}
    return [] if "log" in filepath else {}

response_cache = load_json(CACHE_FILE)
interactions_log = load_json(INTERACTIONS_LOG)
feedback_log = load_json(FEEDBACK_LOG)

def save_json(filepath, data):
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print(f"Error saving {filepath}: {e}")

def log_interaction(interaction_type, payload, response):
    entry = {
        "timestamp": datetime.now().isoformat(),
        "type": interaction_type,
        "payload": payload,
        "response": response
    }
    interactions_log.append(entry)
    # Keep last 10,000 interactions locally
    if len(interactions_log) > 10000: interactions_log.pop(0)
    save_json(INTERACTIONS_LOG, interactions_log)

def save_to_cache(key: str, value: str):
    # Limit cache size to prevent memory explosion
    if len(response_cache) > 1000:
        response_cache.pop(next(iter(response_cache)))
    response_cache[key] = value
    save_json(CACHE_FILE, response_cache)

ai_services = {}
initialization_errors = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup logic
    global ai_services, initialization_errors
    print("Starting AI Services initialization...")
    
    # Initialize shared VectorDB once
    try:
        shared_db = VectorDB()
        shared_db.load_or_create_index()
    except Exception as e:
        print(f"[ERROR] Failed to initialize VectorDB: {e}")
        shared_db = None

    for provider in ["gemini", "deepseek"]:
        try:
            print(f"Initializing {provider}...")
            ai_services[provider] = AIService(provider_type=provider, db=shared_db)
            print(f"[OK] Successfully initialized {provider} service.")
        except Exception as e:
            error_msg = f"[ERROR] Error initializing {provider}: {str(e)}"
            print(error_msg)
            # import traceback
            # traceback.print_exc()
            initialization_errors[provider] = str(e)
    yield
    # Shutdown logic (if any)
    ai_services.clear()

app = FastAPI(title="LexAmi AI API", lifespan=lifespan)

# Enable CORS for all origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class CaseAnalysisRequest(BaseModel):
    case_details: str
    provider: Optional[str] = "gemini"

class AlimonyCalculationRequest(BaseModel):
    financial_data: Dict[str, Any]
    provider: Optional[str] = "gemini"

class CaseDraftRequest(BaseModel):
    prompt: str
    provider: Optional[str] = "gemini"

class FeedbackRequest(BaseModel):
    interaction_id: str # The cache key or a unique ID
    rating: int # 1 to 5
    comment: Optional[str] = None
    corrected_info: Optional[str] = None
    user_context: Optional[str] = None # e.g. "Lawyer", "Student", "Litigant"

async def verify_api_key(x_api_key: str = Header(...)):
    expected_key = os.getenv("NYAY_MITRA_API_KEY")
    if not expected_key:
        # If no key is configured in environment, we might want to warn or allow in dev
        # For production, we should require it.
        return
    if x_api_key != expected_key:
        raise HTTPException(status_code=403, detail="Invalid API Key")

@app.get("/warmup")
async def warmup():
    # Trigger loading of services and embedding if not yet loaded
    for provider in ["gemini"]:
        if provider in ai_services:
            # This triggers the similarity search loading via get_embedding_info or a dummy call
            ai_services[provider].get_embedding_info()
            # Perform a tiny dummy search to ensure FAISS and HF are warm
            try:
                ai_services[provider].db.similarity_search("warmup query", k=1)
            except:
                pass
    return {"status": "Backend and Knowledge Base are warm and ready"}

@app.get("/")
async def root():
    # Get embedding info from one of the services (they share the same vector DB)
    embedding_info = {}
    if "gemini" in ai_services:
        embedding_info = ai_services["gemini"].get_embedding_info()
    
    return {
        "message": "LexAmi AI API is running",
        "version": "1.1.0 (Fix for API Quota)",
        "embedding_config": embedding_info,
        "interactive_docs": "Visit http://localhost:8000/docs to test the API",
        "available_providers": list(ai_services.keys())
    }

@app.post("/analyze-case")
async def analyze_case(request: CaseAnalysisRequest, _ = Depends(verify_api_key)):
    service = ai_services.get(request.provider)
    if not service:
        error_detail = initialization_errors.get(request.provider, "Unknown error during initialization")
        raise HTTPException(status_code=503, detail=f"AI Provider {request.provider} not available. Error: {error_detail}")
    
    # Check Cache
    cache_key = hashlib.md5(f"analyze_{request.provider}_{request.case_details}".encode()).hexdigest()
    cached_result = get_from_cache(cache_key)
    if cached_result:
        print(f"⚡ Serving from cache: {cache_key}")
        return {"analysis": cached_result, "provider": request.provider}

    try:
        analysis = service.analyze_case(request.case_details)
        save_to_cache(cache_key, analysis)
        log_interaction("analyze_case", request.dict(), analysis)
        return {"analysis": analysis, "provider": request.provider, "interaction_id": cache_key}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/calculate-alimony")
async def calculate_alimony(request: AlimonyCalculationRequest, _ = Depends(verify_api_key)):
    service = ai_services.get(request.provider)
    if not service:
        error_detail = initialization_errors.get(request.provider, "Unknown error during initialization")
        raise HTTPException(status_code=503, detail=f"AI Provider {request.provider} not available. Error: {error_detail}")
    
    # Check Cache
    cache_key = hashlib.md5(f"alimony_{request.provider}_{json.dumps(request.financial_data, sort_keys=True)}".encode()).hexdigest()
    cached_result = get_from_cache(cache_key)
    if cached_result:
        print(f"⚡ Serving from cache (Alimony): {cache_key}")
        return {"prediction": cached_result, "provider": request.provider, "interaction_id": cache_key}

    try:
        prediction = service.calculate_alimony(request.financial_data)
        save_to_cache(cache_key, prediction)
        log_interaction("calculate_alimony", request.dict(), prediction)
        return {"prediction": prediction, "provider": request.provider, "interaction_id": cache_key}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/generate-draft")
async def generate_draft(request: CaseDraftRequest, _ = Depends(verify_api_key)):
    service = ai_services.get(request.provider)
    if not service:
        error_detail = initialization_errors.get(request.provider, "Unknown error during initialization")
        raise HTTPException(status_code=503, detail=f"AI Provider {request.provider} not available. Error: {error_detail}")
    
    # Check Cache
    cache_key = hashlib.md5(f"draft_{request.provider}_{request.prompt}".encode()).hexdigest()
    cached_result = get_from_cache(cache_key)
    if cached_result:
        print(f"⚡ Serving from cache (Draft): {cache_key}")
        return {"draft": cached_result, "provider": request.provider, "interaction_id": cache_key}

    try:
        draft = service.generate_legal_draft(request.prompt)
        save_to_cache(cache_key, draft)
        log_interaction("generate_draft", request.dict(), draft)
        return {"draft": draft, "provider": request.provider, "interaction_id": cache_key}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/feedback")
async def provide_feedback(request: FeedbackRequest, _ = Depends(verify_api_key)):
    # Save feedback to build the maturity dataset
    entry = {
        "timestamp": datetime.now().isoformat(),
        **request.dict()
    }
    feedback_log.append(entry)
    save_json(FEEDBACK_LOG, feedback_log)
    print(f"🌟 Received user feedback (Rating: {request.rating})")
    return {"status": "Feedback recorded. Thank you for helping LexAmi mature."}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
