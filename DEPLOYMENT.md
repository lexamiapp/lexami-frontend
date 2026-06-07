# Deploying LexAmi via WhatsApp

Follow these steps to generate the APK you can share:

## 0. Prerequisite: Firebase Console Settings
Before building, ensure your Firebase backend is ready for a Release app:
1.  Go to the **[Firebase Console](https://console.firebase.google.com/)**.
2.  Navigate to **Build -> Authentication -> Sign-in method**.
3.  Ensure **Email/Password** is set to **Enabled**.
4.  Go to **Project Settings (gear icon) -> General**.
5.  Under **Your apps**, ensure your Android app has **both** SHA-1 and SHA-256 fingerprints added.

## 1. Generate a Signing Key
Open your terminal (PowerShell) and run this command **exactly** as shown (if you are already in PowerShell, do not type "powershell" at the start):

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore c:\Users\praty\Documents\AntiGravity\family_dispute\nyay_mitra_app\android\app\upload-keystore.jks -storetype PKCS12 -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

> [!IMPORTANT]
> - **Password**: You will be asked for a password. Use a simple one like `nyayamitra123` (remember it!).
> - **Details**: It will ask for your name, organization, etc. You can just press Enter or type "LexAmi".
> - **Confirmation**: Type `yes` when it asks if the details are correct.

## 2. Update key.properties
I have created a file at [android/key.properties](file:///c:/Users/praty/Documents/AntiGravity/family_dispute/nyay_mitra_app/android/key.properties). 
Make sure the password matches what you typed in Step 1.

## 3. Add SHA Fingerprint to Firebase
1. Run this command to see your Release SHA-256:
   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore c:\Users\praty\Documents\AntiGravity\family_dispute\nyay_mitra_app\android\app\upload-keystore.jks -alias upload -storepass nyayamitra123
   ```
2. Copy the **SHA-256** value.
3. Go to [Firebase Console](https://console.firebase.google.com/).
4. Project Settings > General > Your Apps > Android.
5. Click **Add Fingerprint** and paste the SHA-256.

## 4. Build the APK
Run this final command:
```powershell
flutter build apk --release
```

The file will be at:
`build\app\outputs\flutter-apk\app-release.apk`

**You can now send this file via WhatsApp!**

---

### 💳 Razorpay Configuration (Crucial for Payments)
For the test version, you must set up your Razorpay Test Key:
1.  Log in to your [Razorpay Dashboard](https://dashboard.razorpay.com/).
2.  Go to **Settings > API Keys**.
3.  Copy your **Test Key ID**.
4.  Open [recharge_wallet_screen.dart](file:///c:/Users/praty/Documents/AntiGravity/family_dispute/nyay_mitra_app/lib/screens/recharge_wallet_screen.dart).
5.  On line 78, replace `'rzp_test_YOUR_KEY_HERE'` with your actual Key ID.

> [!IMPORTANT]
> Without a valid Test Key, the "Recharge" button will throw an exception during testing.
