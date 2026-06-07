import os
from abc import ABC, abstractmethod
from dotenv import load_dotenv
import google.generativeai as genai
from openai import OpenAI
from vector_db import VectorDB

load_dotenv()

class AIProvider(ABC):
    @abstractmethod
    def generate_content(self, prompt: str) -> str:
        pass

class GeminiProvider(AIProvider):
    def __init__(self, model_name='gemini-1.5-flash-8b'):
        api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key:
            raise ValueError("GOOGLE_API_KEY not found")
        genai.configure(api_key=api_key)
        self.model_name = model_name
        self.model = genai.GenerativeModel(self.model_name)

    def _get_available_model(self):
        print("Listing available models...")
        try:
            for m in genai.list_models():
                if 'generateContent' in m.supported_generation_methods:
                    print(f"Found available model: {m.name}")
                    # Prefer gemini-1.5-flash or gemini-pro
                    if 'flash' in m.name:
                        return m.name
                    if 'gemini-pro' in m.name:
                        return m.name
            # If no preference found, return the first one
            for m in genai.list_models():
                if 'generateContent' in m.supported_generation_methods:
                    return m.name
        except Exception as e:
            print(f"Error listing models: {e}")
        return 'gemini-pro' # Ultimate fallback

    def generate_content(self, prompt: str) -> str:
        try:
            response = self.model.generate_content(prompt)
            return response.text
        except Exception as e:
            print(f"Primary model {self.model_name} failed: {e}")
            # If 404 or not found, try to find a working model
            if "404" in str(e) or "not found" in str(e).lower() or "not supported" in str(e).lower():
                new_model_name = self._get_available_model()
                print(f"Switching to available model: {new_model_name}")
                if new_model_name != self.model_name:
                    self.model_name = new_model_name
                    # Remove 'models/' prefix if present for clean init
                    clean_name = new_model_name.replace('models/', '')
                    self.model = genai.GenerativeModel(clean_name)
                    # Try again
                    try:
                        response = self.model.generate_content(prompt)
                        return response.text
                    except Exception as inner_e:
                        print(f"Fallback model {clean_name} also failed: {inner_e}")
                        raise inner_e # If even the listed model fails, we really have an issue
            raise e

class DeepSeekProvider(AIProvider):
    def __init__(self, model_name='deepseek-chat'):
        api_key = os.getenv("DEEPSEEK_API_KEY")
        if not api_key:
            raise ValueError("DEEPSEEK_API_KEY not found")
        # DeepSeek uses an OpenAI-compatible API
        self.client = OpenAI(api_key=api_key, base_url="https://api.deepseek.com")
        self.model_name = model_name

    def generate_content(self, prompt: str) -> str:
        response = self.client.chat.completions.create(
            model=self.model_name,
            messages=[
                {"role": "system", "content": "You are a helpful legal assistant."},
                {"role": "user", "content": prompt},
            ],
            stream=False
        )
        return response.choices[0].message.content

class AIService:
    def __init__(self, provider_type="gemini", db=None):
        self.db = db if db else VectorDB()
        if not db:
            self.db.load_or_create_index()
        self.provider_type = provider_type
        
        # Initialize providers
        self.gemini = None
        self.deepseek = None
        
        try:
            self.gemini = GeminiProvider()
        except Exception as e:
            print(f"Warning: Gemini initialization failed: {e}")
            
        try:
            self.deepseek = DeepSeekProvider()
        except Exception as e:
            print(f"Warning: DeepSeek initialization failed: {e}")

        if provider_type == "gemini":
            self.primary_provider = self.gemini
        else:
            self.primary_provider = self.deepseek

        if not self.primary_provider:
             # Fallback to whatever is available
             self.primary_provider = self.gemini if self.gemini else self.deepseek
             
        if not self.primary_provider:
            raise ValueError("No AI providers could be initialized. Check API keys.")

    def _execute_with_fallback(self, prompt):
        """Tries the primary provider, then falls back to secondary if primary fails"""
        try:
            return self.primary_provider.generate_content(prompt)
        except Exception as e:
            print(f"Primary provider failed: {e}. Trying fallback...")
            # If primary was gemini, try deepseek
            if self.primary_provider == self.gemini and self.deepseek:
                try:
                    return self.deepseek.generate_content(prompt)
                except Exception as de:
                    print(f"DeepSeek fallback also failed: {de}")
                    raise de
            # If primary was deepseek, try gemini (unlikely to fix quota issues but worth a shot)
            elif self.primary_provider == self.deepseek and self.gemini:
                try:
                    return self.gemini.generate_content(prompt)
                except Exception as ge:
                    print(f"Gemini fallback also failed: {ge}")
                    raise ge
            raise e

    def get_embedding_info(self):
        return {
            "provider": "HuggingFace (Local)",
            "model": "all-MiniLM-L6-v2",
            "index_path": self.db.index_path
        }

    def analyze_case(self, case_details):
        try:
            context_docs = self.db.similarity_search(case_details)
            context_text = "\n".join([doc.page_content for doc in context_docs])

            prompt = f"""
            You are an AI Legal Assistant for Nyay Mitra, focused on family disputes and legal guidance.
            Use the following retrieved context to help analyze the user's case.
            
            Mandatory Disclaimer: "I am an AI, not a lawyer. This is for informational purposes only. Please consult a [legal professional](/advisors)."

            Context:
            {context_text}

            User's Case:
            {case_details}

            Please provide:
            1. A brief summary of the situation.
            2. Potential legal points or precedents (if applicable).
            3. Emotional well-being suggestions.
            4. Next steps for the user.
            5. Legal References: Explicitly list the Sections of law (e.g., Section 13 HMA, Section 125 CrPC) or Landmark Judgments (with names) that the user should read for more details.
            """
            return self._execute_with_fallback(prompt)
        except Exception as e:
            raise e

    def calculate_alimony(self, financial_data):
        try:
            prompt = f"""
            You are an AI Alimony Calculator for Nyay Mitra.
            Analyze the following financial and marital data to provide a projected alimony range.
            
            Data:
            {financial_data}

            Mandatory Disclaimer: "Calculations are estimates based on general trends and provided data. Actual court rulings may vary. Please consult a [legal professional](/advisors)."

            Provide:
            1. Estimated Alimony range (Monthly/Lump sum).
            2. Justification based on the data factors (duration, income gap, etc.).
            3. Suggested negotiation points.
            4. Legal References: List the specific sections of the Hindu Marriage Act, Special Marriage Act, or Section 125 CrPC that govern these calculations.
            """
            return self._execute_with_fallback(prompt)
        except Exception as e:
            raise e

    def generate_legal_draft(self, prompt_data):
        try:
            prompt = f"""
            You are an expert Indian Family Law legal drafter. 
            Generate a professional, court-ready legal document based on the following details. 
            Use formal legal language as used in Indian Courts (CPC/HMA). 
            Include Petitioner, Respondent, Jurisdiction, Facts, and Prayer sections.

            Details:
            {prompt_data}
            """
            return self._execute_with_fallback(prompt)
        except Exception as e:
            raise e
