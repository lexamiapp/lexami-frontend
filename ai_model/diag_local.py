import requests
import json
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("NYAY_MITRA_API_KEY", "nyay_mitra_secret_v1")
BASE_URL = "http://localhost:8000"

print(f"Testing LOCAL API at {BASE_URL}")

def test_endpoint(name, method, endpoint, **kwargs):
    url = f"{BASE_URL}{endpoint}"
    print(f"\n--- Testing {name} ---")
    headers = {"x-api-key": API_KEY, "Content-Type": "application/json"}
    try:
        if method == "GET":
            response = requests.get(url, headers=headers, timeout=30)
        else:
            response = requests.post(url, headers=headers, json=kwargs.get("json"), timeout=30)
        
        print(f"Status Code: {response.status_code}")
        try:
            print(f"Response: {json.dumps(response.json(), indent=2)}")
        except:
            print(f"Raw: {response.text}")
    except Exception as e:
        print(f"FAILED: {e}")

# Test the failing ones
test_endpoint("Analyze Case", "POST", "/analyze-case", json={"case_details": "Property dispute", "provider": "gemini"})
test_endpoint("Calculate Alimony", "POST", "/calculate-alimony", json={
    "financial_data": {"husband_income": 100000, "wife_income": 20000, "marriage_duration_years": 10, "children_count": 2},
    "provider": "gemini"
})
test_endpoint("Generate Draft", "POST", "/generate-draft", json={"prompt": "Draft a divorce petition", "provider": "gemini"})
