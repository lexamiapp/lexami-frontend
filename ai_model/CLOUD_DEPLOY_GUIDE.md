# 🚀 Google Cloud Run Deployment Guide

Since I don't have access to run `gcloud` commands on your machine, you'll need to run these steps to get your AI model online.

## Prerequisites
1.  **Install Google Cloud SDK:** [Download here](https://cloud.google.com/sdk/docs/install) (or use Google Cloud Shell).
2.  **Enable APIs:** Go to your Google Cloud Console and enable:
    - Cloud Build API
    - Cloud Run API

## Steps to Deploy

### 1. Login and Set Project
Open your terminal (CMD or PowerShell) in the `ai_model` folder and run:
```bash
gcloud auth login
gcloud config set project legal-sathi-2025-d4124
```
> [!IMPORTANT]
> From your list, select **`legal-sathi-2025-d4124`**. This matches your app's existing Firebase project, which is required for everything to work together.

### 2. Run the Deployment Script
I've created a script for you. Just run:
```bash
sh deploy_to_cloud.sh
```
*Note: If you are on Windows and don't have a bash terminal, run these commands manually:*
```bash
gcloud builds submit --tag gcr.io/legal-sathi-2025-d4124/nyay-mitra-ai
gcloud run deploy nyay-mitra-ai --image gcr.io/legal-sathi-2025-d4124/nyay-mitra-ai --platform managed --region us-central1 --memory 2Gi --timeout 300 --allow-unauthenticated --set-env-vars "GOOGLE_API_KEY=AIzaSyB4dk_SquT4pNmksWRh-LSg-MrIHYl3H_0,NYAY_MITRA_API_KEY=nyay_mitra_secret_v1"
```

> [!NOTE]
> I have fixed a technical error in the `Dockerfile` (`main.py:app` -> `main:app`) and increased the memory to **2Gi**. AI models like the one we are using for Legal RAG need a bit more "breathing room" to start up.

### 3. Get your URL
Once successful, Google will give you a URL like `https://nyay-mitra-ai-xxxxx.a.run.app`.

### 4. Update Flutter
Change the `localAiUrl` in `lib/utils/constants.dart`:
```dart
static const String localAiUrl = 'https://YOUR_NEW_CLOUD_RUN_URL';
```

---

### Phase 3: Final APK
Once the URL is updated, you can build your final APK:
```bash
flutter build apk --release
```

> [!IMPORTANT]
> Keep your `ai_model/.env` secret. The deployment script automatically sets these as environment variables in the cloud for you.
