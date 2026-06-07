# Nyay Mitra AI Load Testing

This directory contains the load testing suite for the Nyay Mitra AI Backend.

## Prerequisites

- Python 3.10+
- Locust (`pip install locust`)
- Backend dependencies (`pip install -r requirements.txt`)

## How to Run

### Automatic (Recommended)
Run the helper script:
```powershell
./run_load_test.ps1
```

### Manual
1. **Start the AI Backend**:
   ```bash
   cd ai_model
   python main.py
   ```
2. **Start Locust**:
   ```bash
   cd ai_model
   locust -f locustfile.py --host http://localhost:8000
   ```
3. **Open the UI**:
   Navigate to [http://localhost:8089](http://localhost:8089) in your browser.

## Load Test Scenarios

- **Case Analysis**: Simulates users submitting case details for AI analysis.
- **Alimony Calculation**: Simulates users inputting financial data for alimony estimates.
- **Document Drafting**: Simulates requests for legal document generation (e.g., divorce petitions).
- **System Health**: Periodic checks of the root and warmup endpoints.

## Tags

You can run specific tests using tags:
```bash
locust -f locustfile.py --tags analysis
```
