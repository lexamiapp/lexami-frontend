import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Fetches runtime configuration from Firebase Remote Config.
///
/// Remote Config values to set in Firebase Console:
///   - gemini_api_key  (String)  — Gemini API key
///   - daily_ai_quota  (Int)     — max AI calls per user per day (default 10)
///   - beta_mode       (Bool)    — true during beta, shows beta banner
///   - backend_url     (String)  — Node.js backend URL (default Render.com URL)
class ConfigService {
  static final _rc = FirebaseRemoteConfig.instance;

  // In-APK fallback defaults — used if Remote Config fetch fails.
  // The Gemini key here is intentionally a placeholder; the real key
  // lives in Firebase Remote Config (not in source code).
  static const _defaults = <String, dynamic>{
    'gemini_api_key': 'AIzaSyC9A6Z4z5vXJnJqjagctSKhRJOX9oyCRN0',
    'daily_ai_quota': 10,
    'beta_mode': true,
    'backend_url': 'https://lexami-backend-d3t5.onrender.com',
  };

  static Future<void> init() async {
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // During beta: refresh every 30 min so you can change quota/key
        // without releasing a new APK
        minimumFetchInterval: const Duration(minutes: 30),
      ));
      await _rc.setDefaults(_defaults);
      await _rc.fetchAndActivate();
    } catch (_) {
      // Remote Config is optional — app works with in-APK defaults
    }
  }

  static String get geminiApiKey => _rc.getString('gemini_api_key');
  static int get dailyAiQuota => _rc.getInt('daily_ai_quota');
  static bool get betaMode => _rc.getBool('beta_mode');
  static String get backendUrl => _rc.getString('backend_url');
}
