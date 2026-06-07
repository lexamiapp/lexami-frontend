import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const _localizedValues = {
    'en': {
      'app_title': 'LexAni',
      'home': 'Home',
      'advisors': 'Advisors',
      'join_as_advisory': 'Join as Advisory',
      'legal_advisory': 'Legal Advisory',
      'counselors': 'Counselors',
      'call': 'Call',
      'wallet': 'My Wallet',
      'profile': 'Profile',
      'settings': 'Settings',
      'language': 'Language',
      'consultation': 'Advisory Consultations',
      'low_balance': 'Low Balance',
      'analyze_case': 'AI Case Analysis',
      'alimony_calc': 'Alimony Calculator',
      'drafting_vault': 'Drafting Vault',
      'transcriber': 'Evidence Transcriber',
      'my_cases': 'My Cases',
      'community': 'Community',
      'evidence_vault': 'Evidence Vault',
      'voice_draft': 'AI Voice Draft',
      'localization': 'App Localization',
      'categorize_evidence': 'Categorize your court evidence',
      'speak_to_draft': 'Speak thoughts to draft application',
      'co_parenting': 'Co-Parenting',
      'custody_plans': 'Custody & Plans',
      'legal_library': 'Legal Library',
      'child_first_framework': 'Child-First Framework',
      'step_1': 'Step 1',
      'child_profile_context': 'Child Profile & Context',
      'parenting_plan_builder': 'Parenting Plan Builder',
      'visitation_calendar': 'Visitation Calendar',
      'secure_communication': 'Secure Communication',
      'harmony_compliance': 'Harmony & Compliance',
    },
    'hi': {
      'app_title': 'LexAni',
      'home': 'होम',
      'advisors': 'सलाहकार',
      'join_as_advisory': 'सलाहकार के रूप में जुड़ें',
      'legal_advisory': 'कानूनी सलाह',
      'counselors': 'परामर्शदाता',
      'call': 'कॉल',
      'wallet': 'मेरा वॉलेट',
      'profile': 'प्रोफ़ाइल',
      'settings': 'सेटिंग्स',
      'language': 'भाषा',
      'consultation': 'सलाहकार परामर्श',
      'low_balance': 'कम बैलेंस',
      'analyze_case': 'एआई केस विश्लेषण',
      'alimony_calc': 'गुजारा भत्ता कैलकुलेटर',
      'drafting_vault': 'ड्राफ्टिंग वॉल्ट',
      'transcriber': 'सबूत ट्रांसक्राइबर',
      'my_cases': 'मेरे केस',
      'community': 'समुदाय',
      'evidence_vault': 'सबूत तिजोरी',
      'voice_draft': 'एआई वॉयस ड्राफ्ट',
      'localization': 'ऐप स्थानीयकरण',
      'categorize_evidence': 'अपने अदालती सबूतों को वर्गीकृत करें',
      'speak_to_draft': 'आवेदन का मसौदा तैयार करने के लिए बोलें',
      'co_parenting': 'सह-पालन (को-पेरेंटिंग)',
      'custody_plans': 'हिरासत और योजनाएं',
      'legal_library': 'कानूनी पुस्तकालय',
      'child_first_framework': 'बाल-प्रथम ढांचा',
      'step_1': 'चरण 1',
      'child_profile_context': 'बच्चे की प्रोफाइल और संदर्भ',
      'parenting_plan_builder': 'पालन-पोषण योजना निर्माता',
      'visitation_calendar': 'मुलाकात कैलेंडर',
      'secure_communication': 'सुरक्षित संचार',
      'harmony_compliance': 'सामंजस्य और अनुपालन',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
