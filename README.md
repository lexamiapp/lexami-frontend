# LexAmi App

Flutter application for legal assistance, featuring Lawyer Search and AI Matching.

## Setup Instructions

### 1. Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed.
- [Firebase Account](https://firebase.google.com/).

### 2. Firebase Configuration
**Important**: This app requires Firebase to function.

1. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
   **Note**: If `flutterfire` command is not found, use the full path:
   `C:\Users\praty\AppData\Local\Pub\Cache\bin\flutterfire.bat configure`

3. Configure the app (run inside `nyay_mitra_app` directory):
   ```bash
   flutterfire configure
   ```
   (or use the full path above if needed)

   - Select your project.
   - Select platforms (Android, iOS).
   - This will generate `lib/firebase_options.dart` with correct keys.

### 3. Gemini API Key
1. Get an API key from [Google AI Studio](https://makersuite.google.com/app/apikey).
2. Open `lib/main.dart`.
3. Replace `'YOUR_GEMINI_API_KEY'` with your actual key.

### 4. Run the App
```bash
flutter pub get
flutter run
```

## Features
- **User Authentication**: Login/Signup via Firebase.
- **Lawyer Search**: Find lawyers by name or specialization.
- **AI Matching**: Describe your case to get AI-powered lawyer recommendations using Gemini.
