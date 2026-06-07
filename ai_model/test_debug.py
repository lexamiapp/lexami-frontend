from ai_service import AIService
import os
from dotenv import load_dotenv

load_dotenv()

def test_analyze():
    print("Testing AIService.analyze_case...")
    try:
        service = AIService(provider_type="deepseek")
        print("AIService initialized.")
        result = service.analyze_case("Test case details")
        print("Analysis successful!")
        print(result)
    except Exception as e:
        print(f"FAILED with error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    if not os.getenv("DEEPSEEK_API_KEY"):
        print("Error: DEEPSEEK_API_KEY not found in .env")
    else:
        test_analyze()
