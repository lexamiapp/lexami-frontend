import random
import os
import json
from locust import task, between, HttpUser, tag

from dotenv import load_dotenv

# Load environment variables explicitly
load_dotenv()

# Load API Key from environment or use a default for local testing
API_KEY = os.getenv("NYAY_MITRA_API_KEY", "nyay_mitra_secret_v1")

class NyayMitraUser(HttpUser):
    # Wait between 10 and 20 seconds between tasks to simulate a user 
    # reading the AI generated legal advice.
    wait_time = between(10, 20)
    
    # Connection timeout settings for high load
    # For HttpUser, we'll use the requests-style timeout in the post calls.

    def on_start(self):
        """Called when a User is hatched. Sets up authorization."""
        self.client.headers.update({
            "x-api-key": API_KEY,
            "Content-Type": "application/json"
        })

    @tag('analysis')
    @task(5)
    def analyze_case(self):
        case_scenarios = [
            "I am facing a child custody dispute in Bangalore. My ex-husband is refusing to let me see our 5-year-old daughter. We were married for 8 years.",
            "Property dispute between brothers regarding ancestral land in Pune. The elder brother has forged documents to show sole ownership.",
            "Domestic violence case where the victim seeks protection order and interim maintenance. The husband is a high-earning professional.",
            "Divorce petition on the grounds of cruelty and desertion. The couple has been living separately for 2 years.",
            "Alimony dispute where the wife is claiming 50% of the husband's income as maintenance, but the husband claims he lost his job."
        ]
        
        payload = {
            "case_details": random.choice(case_scenarios),
            "provider": "gemini" 
        }
        
        with self.client.post("/analyze-case", json=payload, catch_response=True, timeout=120) as response:
            if response.status_code == 200:
                try:
                    result = response.json()
                    if "analysis" in result:
                        response.success()
                    else:
                        response.failure("Response missing 'analysis' field")
                except json.JSONDecodeError:
                    response.failure("Response is not valid JSON")
            elif response.status_code == 422:
                response.failure(f"Validation Error (422): {response.text}")
            elif response.status_code == 429:
                response.failure("Rate Limit Exceeded (429) - Quota limited")
            elif response.status_code == 403:
                response.failure("Authentication failed: Invalid API Key")
            elif response.status_code == 503:
                response.failure("AI Service Overloaded (503)")
            else:
                response.failure(f"Error {response.status_code}: {response.text}")

    @tag('alimony')
    @task(2)
    def calculate_alimony(self):
        # Using a list of fixed scenarios to test caching
        scenarios = [
            {"husband_income": 100000, "wife_income": 30000, "marriage_duration_years": 10, "children_count": 2, "city_tier": "Tier 1"},
            {"husband_income": 250000, "wife_income": 0, "marriage_duration_years": 15, "children_count": 1, "city_tier": "Tier 1"},
            {"husband_income": 60000, "wife_income": 15000, "marriage_duration_years": 5, "children_count": 0, "city_tier": "Tier 2"},
            {"husband_income": 400000, "wife_income": 100000, "marriage_duration_years": 20, "children_count": 3, "city_tier": "Tier 1"},
            {"husband_income": 80000, "wife_income": 0, "marriage_duration_years": 8, "children_count": 2, "city_tier": "Tier 3"}
        ]
        
        payload = {
            "financial_data": random.choice(scenarios),
            "provider": "gemini"
        }
        
        with self.client.post("/calculate-alimony", json=payload, catch_response=True, timeout=120) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 422:
                response.failure(f"Validation Error (422): {response.text}")
            else:
                response.failure(f"Alimony calculation failed: {response.status_code}")

    @tag('drafting')
    @task(3)
    def generate_draft(self):
        draft_types = [
            "Divorce Petition under HMA Section 13",
            "Child Custody Application for Interim Visitation",
            "Legal Notice for Maintenance under Section 125 CrPC",
            "Bail Application in a Matrimonial Dispute",
            "Reply to Domestic Violence Complaint"
        ]
        
        topic = random.choice(draft_types)
        payload = {
            "prompt": f"Please generate a professional {topic}. Parties are from Delhi. Fact: 10 years of marriage, 2 kids.",
            "provider": "gemini"
        }
        
        with self.client.post("/generate-draft", json=payload, catch_response=True, timeout=120) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 422:
                response.failure(f"Validation Error (422): {response.text}")
            else:
                response.failure(f"Draft generation failed: {response.status_code}")

    @tag('system')
    @task(1)
    def system_health_check(self):
        """Checks the root and warmup endpoints periodically."""
        with self.client.get("/", catch_response=True, timeout=30) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure("System Root Unreachable")
                
        with self.client.get("/warmup", catch_response=True, timeout=30) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure("Warmup Endpoint Failed")
