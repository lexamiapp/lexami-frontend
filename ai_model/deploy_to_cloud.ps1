# Configuration
$PROJECT_ID = "legal-sathi-2025-d4124"
$SERVICE_NAME = "nyay-mitra-ai"
$REGION = "us-central1"

Write-Host "Starting Deployment for $SERVICE_NAME..." -ForegroundColor Cyan

# Build the container image using Cloud Build
Write-Host "Building image on Cloud Build..." -ForegroundColor Yellow
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME .

# Deploy the image to Cloud Run
Write-Host "Deploying to Cloud Run..." -ForegroundColor Yellow
gcloud run deploy nyay-mitra-ai `
    --image gcr.io/$PROJECT_ID/nyay-mitra-ai `
    --platform managed `
    --region $REGION `
    --allow-unauthenticated `
    --memory 4Gi `
    --cpu 2 `
    --min-instances 1 `
    --set-env-vars "GOOGLE_API_KEY=AIzaSyB4dk_SquT4pNmksWRh-LSg-MrIHYl3H_0,NYAY_MITRA_API_KEY=nyay_mitra_secret_v1"

Write-Host "Deployment Complete!" -ForegroundColor Green
gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format 'value(status.url)'
