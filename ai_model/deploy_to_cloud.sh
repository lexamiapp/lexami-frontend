#!/bin/bash

# Configuration
PROJECT_ID="legal-sathi-2025-d4124"
SERVICE_NAME="nyay-mitra-ai"
REGION="us-central1" # Or your preferred region

echo "🚀 Starting Deployment for $SERVICE_NAME..."

# Build the container image using Cloud Build
echo "📦 Building image on Cloud Build..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME .

# Deploy the image to Cloud Run
echo "🌍 Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 2Gi \
  --timeout 300 \
  --set-env-vars "GOOGLE_API_KEY=AIzaSyB4dk_SquT4pNmksWRh-LSg-MrIHYl3H_0,NYAY_MITRA_API_KEY=nyay_mitra_secret_v1"

echo "✅ Deployment Complete!"
gcloud run services describe $SERVICE_NAME --platform managed --region $REGION --format 'value(status.url)'
