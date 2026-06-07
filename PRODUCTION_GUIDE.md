# Production Architecture & Launch Guide

## 1. Concurrent Users vs Total Users
*   **Total Users**: 50,000
    *   **DAU (Daily Active Users)**: ~5,000 (10%)
    *   **CCU (Concurrent Users)**: ~500 (1%) at peak
*   **Verdict**: The current architecture (Cloud Run + Firestore) will handle 500 CCU easily. Cloud Run scales automatically to thousands of instances if needed.

## 2. Updated Architecture (Flutter + Antigravity)

### Frontend (Flutter)
- [x] **Code**: Flutter Web + Android/iOS
- [x] **Analytics**: Added `firebase_analytics` & `firebase_crashlytics` dependencies.
- [ ] **Action Required**: Run `flutterfire configure` again to link these properly if not done.

### Backend (Cloud Run - Python/FastAPI)
- [x] **Compute**: Cloud Run (Containerized, Autoscaling enabled by default).
    -   *Configuration*: Min instances: 0 (save cost), Max instances: 10 (safety cap).
- [x] **AI Layer**: 
    -   RAG implemented (FAISS vector DB).
    -   **Caching**: Added in-memory LRU cache to `main.py` to prevent re-calling AI for identical queries.
    -   **Provider**: Google Gemini (via API).

### Database (Firestore)
- [x] **Type**: NoSQL (Firestore Native Mode).
- [x] **Performance**: Fast reads/writes.
- [x] **Rules**: `firestore.rules` file created for security (User-only access).

## 3. Performance Optimization Checklist
- [x] **API Caching**: Implemented for `analyze_case`.
- [x] **RAG**: Only retrieves top-3 relevant docs to limit context window size.
- [ ] **Pagination**: Ensure list views in the app (like History) use `limit()` query modifiers.

## 4. Security & Compliance
- [x] **HTTPS**: Enforced by Cloud Run automatically.
- [x] **Privacy Policy**: Created `PRIVACY_POLICY.md`.
- [x] **Deletion**: Ensure the delete account button in Profile screen works.
- [x] **Disclaimer**: AI Disclaimer added to prompt and UI.

## 5. Deployment Steps
1.  **Redeploy Backend**:
    ```powershell
    cd ai_model
    .\deploy_to_cloud.ps1
    ```
2.  **Update Firestore Rules**:
    Paste the content of `firestore.rules` into your Firebase Console [Firestore -> Rules].
3.  **Build App**:
    ```bash
    flutter build appbundle --release
    ```
4.  **Launch**:
    Upload the `.aab` file to Google Play Console Internal Testing track first.
