# 🚀 Nyay Mitra - Google Play Store Launch Checklist

This document serves as your verified guide to publishing **Nyay Mitra** to the Google Play Store. ensure every item is checked to prevent rejection.

---

## 1. ✅ App Content & Compliance
- [ ] **Privacy Policy**: 
    - You must host the content of `PRIVACY_POLICY.md` on a public URL (e.g., Google Docs, Notion, or a simple Website).
    - Paste this URL in Play Console -> App Content -> Privacy Policy.
- [ ] **Data Safety Form**:
    - **Data Collected**: Name, Email, Phone, Photos (User Profile), Files (Legal Docs).
    - **Purpose**: App Functionality, Account Management.
    - **Sharing**: Data is shared with 3rd parties (Google Cloud, Firebase) for processing, not sold.
    - **Data Deletion**: **YES**, you provide a way for users to request deletion (We just added this feature!).
- [ ] **App Access**: 
    - Provide a **Demo Account** (Email/Password) for Google Reviewers.  
    - *Tip: Create a user `reviewer@nyaymitra.in` / `Review123!` and give it verifying advisor data if needed.*
- [ ] **Target Audience**: Select "18+". If you select "13-17", laws are stricter.

## 2. 🎨 Store Listing
- [ ] **App Name**: Nyay Mitra: Legal Aid & Advice
- [ ] **Short Description**: (Max 80 chars) "Instant legal advice, alimony calculator, and community for family disputes."
- [ ] **Full Description**:
    - Highlight AI features: "AI Case Analysis", "Alimony Calculator".
    - Highlight Community: "Anonymous Forum", "Legal Spaces".
    - Highlight Experts: "Verified Advocates & Counselors".
- [ ] **Graphics**:
    - **App Icon**: 512x512 PNG.
    - **Feature Graphic**: 1024x500 PNG (Use the image I generated earlier!).
    - **Screenshots**: At least 2 for Phone. (Take screenshots of Home, Profile, AI Chat, Community).

## 3. ⚙️ Technical Setup
- [ ] **Package Name**: `com.antigravity.nyay_mitra` (Verify in `AndroidManifest.xml`).
- [ ] **Version Code**: Ensure it increments with every update (currently `1.0.0`).
- [ ] **Signing**:
    - You need a `.jks` keystore file to sign the release APK/AAB.
    - *Command:* `keytool -genkey -v -keystore RELEASE-KEY.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nyaymitra`
- [ ] **Build Bundle**:
    - Run: `flutter build appbundle --release`
    - Upload the `.aab` file to "Output" in Play Console.

## 4. 🌍 Distribution
- [ ] **Countries**: Select "India" (and others if you want global availability).
- [ ] **Price**: Free.

## 5. 🧪 Testing (Optional but Recommended)
- [ ] **Internal Testing**: Add your own email list.
- [ ] **Closed Testing**: Required for new personal developer accounts (20 testers for 14 days).
    - *Note:* If you have an old/organization account, you can skip this. If it's a new personal account, you MUST do this.

---

## 🛑 Common Rejection Reasons to Avoid
1.  **Broken Features**: Ensure the AI backend is running (It is! We verified it).
2.  **Incomplete Login**: The reviewer must be able to log in. Test the demo credentials yourself.
3.  **Permissions**: If you ask for Camera/Storage, you must explain WHY in the permission prompt (We did this in `AndroidManifest.xml`).
4.  **Impersonation**: Do not use logos of the Supreme Court or Government of India in your icon or screenshots.

---

## 📅 Maintenance
- **Firebase Bill**: Monitor usage. The "Min Instances" for AI will cost ~$5-10/month.
- **Advisor Verification**: Check the Firestore console weekly to approve new lawyers.

**Good Luck! 🚀**
