class AppConstants {
  static const String usersCollection = 'users';
  static const String advisorsCollection = 'advisors';
  static const String casesCollection = 'cases';
  static const String forumCollection = 'forum_questions';
  static const String historyCollection = 'analysis_history';
  static const String alimonyCollection = 'alimony_records';
  static const String blogsCollection = 'blog_posts';
  static const String channelsCollection = 'advisor_channels';
  static const String channelMessagesCollection = 'messages'; // Deprecated
  static const String channelPostsCollection = 'posts';
  static const String channelCommentsCollection = 'comments';
  static const String connectionsCollection = 'connections';
  static const String statutesCollection = 'legal_statutes';
  static const String judgmentsCollection = 'landmark_judgments';
  static const String notificationsCollection = 'notifications';
  static const String transactionsCollection = 'transactions';
  static const String aiRequestsCollection = 'ai_requests';
  static const String translationsCollection = 'translations';
  static const String vaultCollection = 'document_vault';
  static const String proBonoCollection = 'pro_bono_requests';
  static const String childProfilesCollection = 'child_profiles';
  static const String caseChatsCollection = 'chats'; // Subcollection of a case
  
  // Gemini Prompt for Advisor Matching
  static const String advisorMatchSystemInstruction = '''
    You are an AI advisor match assistant. Your task is to analyze the user's case description and match it with the most suitable advisor specialization from the following list:
    [Divorce, Child Custody, Alimony, Domestic Violence, Property Dispute, Maintenance, Others]
    
    Output JSON format:
    {
      "recommended_specializations": ["Spec1", "Spec2"],
      "analysis": "Brief analysis of why these specializations were chosen.",
      "keywords": ["keyword1", "keyword2"]
    }
  ''';

  // AI Backend URLs
  static const String cloudAiUrl = 'https://nyay-mitra-ai-281211190180.us-central1.run.app';
  static const String localAiUrl = 'http://10.0.2.2:8000'; 
  
  // Active AI URL (Toggle this for local vs cloud)
  static const String activeAiUrl = cloudAiUrl;
  
  static const String localAiApiKey = 'nyay_mitra_secret_v1';
  
  // Admin Access List
  static const List<String> adminEmails = [
    'team@nyaymitra.in',
    'admin@nyaymitra.in',
    'pratyush@nyaymitra.in', // Placeholder for user
  ];
}
