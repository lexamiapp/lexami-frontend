# Start a Launch Project for LexAmi

## 1. Cost Breakdown (Estimated)

### One-Time Store Fees
| Platform | Cost | Frequency |
| :--- | :--- | :--- |
| **Google Play Store** | $25 USD | One-time |
| **Apple App Store** | $99 USD | Yearly |

### Monthly Infrastructure Costs (Google Cloud)
Currently, your app uses:
1.  **Cloud Run (AI Model)**: The most resource-intensive part.
    *   *Free Tier*: First 2 million requests/month are free (conditions apply).
    *   *Estimated*: $0 - $5/month for low traffic. If you get 10,000+ users, this could go up to $20-$50/month.
2.  **Firebase (Auth/Firestore)**:
    *   *Spark Plan*: Free. Good for up to ~50k daily active users.
3.  **Gemini API**:
    *   *Flash Model*: Free tier (15 RPM). Paid tier is \$0.35 / 1M input tokens.
    *   *Pro Model*: \$3.50 / 1M input tokens.
    *   *Recommendation*: Stick to Flash for free tier initially.

**Total Estimated Monthly Cost:** **$0 - $10** (for < 1000 users).

---

## 2. Launch Readiness Checklist

### ✅ Completed
- [x] AI Integration (Cloud Run + Fallback)
- [x] Core Features (Analysis, Calculator, Drafting)
- [x] App Icon & Splash Screen (Default Flutter, needs custom)

### ⚠️ Needs Attention
- [ ] **Privacy Policy URL**: Required by Play Store. You must generate one and host it (can be a simple GitHub gist or Notion page).
- [ ] **Terms of Service**: Recommend having one.
- [ ] **Delete Account Feature**: Mandatory for Data Safety compliance.
- [ ] **Real Advisor Data**: The app currently uses "Fake Lawyers". You must either:
    -   Recruit real lawyers.
    -   Label them clearly as "Demo/AI Agents".
    -   Or remove the specific "Booking" feature for launch until verified.

### 🛑 iOS Limitation
-   **You are on Windows.** You cannot build an iOS app (`.ipa`) directly.
-   **Solution**: Use a cloud build tool like **Codemagic** or **GitHub Actions** (Mac runner), or borrow a Mac.

---

## 3. Recommended Next Steps

### Phase 1: Internal Testing (Google Play)
1.  Create a Google Play Console Account ($25).
2.  Generate a **Privacy Policy** (Use a free generator).
3.  Build an App Bundle (`.aab`) instead of APK:
    ```bash
    flutter build appbundle
    ```
4.  Upload to **Internal Testing** track.
5.  Add your email as a tester and download it from the Play Store.

### Phase 2: Beta Launch
1.  Verify the "Delete Account" button works (Settings -> Delete Account).
2.  Update the "Advisors" list to be either empty or real.

### Phase 3: iOS
1.  Once Android is stable, use **Codemagic** to build the iOS version from your code.
