import requests
import os
from dotenv import load_dotenv
import json

load_dotenv()

API_KEY = os.getenv("NYAY_MITRA_API_KEY", "nyay_mitra_secret_v1")
BASE_URL = "https://nyay-mitra-ai-281211190180.us-central1.run.app"

print(f"Testing API at {BASE_URL} with Key: {API_KEY}")

def test_endpoint(name, method, url, **kwargs):
    print(f"\n--- Testing {name} ---")
    try:
        if method == "GET":
            response = requests.get(url, headers={"x-api-key": API_KEY}, **kwargs)
        else:
            response = requests.post(url, headers={"x-api-key": API_KEY}, **kwargs)
        
        print(f"Status Code: {response.status_code}")
        try:
            print(f"Response JSON: {json.dumps(response.json(), indent=2)}")
        except:
            print(f"Response Text: {response.text}")
            
    except Exception as e:
        print(f"EXCEPTION: {e}")

# 1. Warmup
test_endpoint("Warmup", "GET", f"{BASE_URL}/warmup")

# 2. Analyze Case
payload = {
    "case_details": "Test case details for debugging connection.",
    "provider": "gemini"
}
test_endpoint("Analyze Case", "POST", f"{BASE_URL}/analyze-case", json=payload)
