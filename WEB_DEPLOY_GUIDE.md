# 🌐 LexAmi Web Deployment Guide

Since LexAmi is built with Flutter, it can easily be used in any modern web browser (Chrome, Safari, Edge, etc.).

## 🚀 1. Running Locally for Testing
To test the app in your browser right now, run:
```powershell
flutter run -d chrome
```

## 🌍 2. Deploying to Firebase Hosting
To make the app accessible to everyone via a public URL (e.g., `nyay-mitra.web.app`), follow these steps:

### Step A: Build the Web Project
This command compiles your Flutter code into highly optimized JavaScript/HTML/CSS:
```powershell
flutter build web --release
```

### Step B: Deploy to Firebase
Since I have already added the hosting configuration to your `firebase.json`, you just need to run:
```powershell
firebase deploy --only hosting
```

## 🛠️ Web-Specific Configurations
1. **CORS (Cross-Origin Resource Sharing)**: The AI backend on Cloud Run is already configured to allow requests from any origin, so the browser won't block AI results.
2. **Browser Compatibility**: Best experiences are on Desktop Chrome or Mobile Safari/Chrome.
3. **Features**: Most features like Alimony Calculator, AI Case Analysis, and Community Hub work perfectly. Voice-to-Text works best in Chrome.

## 🔗 Public URL
Once deployed, your app will be available at:
`https://legal-sathi-2025-d4124.web.app`
