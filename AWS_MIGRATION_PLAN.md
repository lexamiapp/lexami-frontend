# 🚀 AWS Migration Plan for Nyay Mitra

This guide outlines how to move your application (Frontend and AI Backend) to **AWS Cloud**.

## 🏗️ 1. Architecture Overview
To keep things simple and cost-effective, we will use **AWS App Runner** for your AI model and **AWS Amplify** for your Flutter Web app.

| Component | Current (GCP/Firebase) | New (AWS Service) | Reason |
| :--- | :--- | :--- | :--- |
| **Frontend (Web)** | Firebase Hosting | **AWS Amplify** | Automated CI/CD from GitHub. |
| **AI Backend** | Cloud Run | **AWS App Runner** | Managed containers, very easy to setup. |
| **Database** | Firestore | Firestore (Hybrid) | Keep your users and data for now. |
| **Auth** | Firebase Auth | Firebase Auth (Hybrid) | Avoid complex user migration. |

---

## 🛠️ Phase 1: Deploy AI Model to AWS App Runner

Since you have a `Dockerfile` and a Python API, **App Runner** is the best choice.

### Steps:
1.  **Connect GitHub**: Push your code to a GitHub repository if you haven't already.
2.  **Go to AWS Console**: Search for **App Runner**.
3.  **Create Service**:
    *   **Source**: Repository service.
    *   **Provider**: GitHub.
    *   **Repository**: Select your `nyay_mitra_app` repo.
    *   **Branch**: `main`.
    *   **Deployment Settings**: Automatic.
4.  **Configure Build**:
    *   **Runtime**: Python 3.
    *   **Build Command**: `pip install -r requirements.txt`.
    *   **Start Command**: `uvicorn main:app --host 0.0.0.0 --port 8080`.
    *   *Note: Ensure the directory is correct (`ai_model/`). You might need to set the context.*
5.  **Environment Variables**:
    *   `GOOGLE_API_KEY`: (Your Gemini Key)
    *   `NYAY_MITRA_API_KEY`: (Your secret key)
    *   `DEEPSEEK_API_KEY`: (Optional)

---

## 🛠️ Phase 2: Deploy Flutter Web to AWS Amplify

Amplify is the fastest way to host Flutter Web.

### Steps:
1.  **Go to AWS Console**: Search for **AWS Amplify**.
2.  **New App**: Select **Amplify Hosting**.
3.  **Connect GitHub**: Select your repository.
4.  **Build Settings**: Amplify will auto-detect it's a Flutter app. If not, use:
    ```yaml
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - git clone https://github.com/flutter/flutter.git -b stable
            - export PATH="$PATH:`pwd`/flutter/bin"
            - flutter doctor
        build:
          commands:
            - flutter build web --release
      artifacts:
        baseDirectory: build/web
        files:
          - '**/*'
    ```
5.  **Deploy**: Once finished, you will get a `.amplifyapp.com` URL.

---

## 🛠️ Phase 3: Connect Everything

Update your Flutter constants to point to the new AWS Backend.

1.  Open `lib/utils/constants.dart`.
2.  Change `cloudAiUrl` to your new **App Runner URL**.
3.  Verify that your Firebase configuration (`google-services.json` and `firebase_options.dart`) still points to your Firebase project.

---

## 🏁 Full Migration (Optional)
If you want to move **Database** and **Auth** to AWS later:
- **Auth**: Use **AWS Cognito**.
- **Database**: Use **AWS DynamoDB** (NoSQL) or **AWS Aurora** (SQL).
- **Backend Logic**: Use **AWS Lambda** for serverless functions.

**Recommendation:** Start with the Hybrid approach (Amplify + App Runner + Firebase). It gives you the power of AWS while keeping the simplicity of Firebase for user management.
