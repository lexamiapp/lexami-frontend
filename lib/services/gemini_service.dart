import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/constants.dart';
import '../utils/quota_exception.dart';
import '../services/quota_service.dart';
import '../models/legal_knowledge.dart';
import '../models/blog_post.dart';
import '../models/forum_question.dart';
import '../models/legal_case.dart';
import '../models/alimony_record.dart';

class GeminiService {
  late GenerativeModel _model;
  late String _apiKey;

  /// Set by the app after login so quota can be checked.
  String? currentUserId;

  final QuotaService _quota = QuotaService();

  void init(String apiKey) {
    _apiKey = apiKey.trim();
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  }

  /// Checks quota before every AI call. Throws [QuotaExceededException] if limit reached.
  Future<void> _checkAndRecord() async {
    final uid = currentUserId;
    if (uid == null || uid.isEmpty) return; // not logged in — allow (guest preview)
    final allowed = await _quota.canMakeAiCall(uid);
    if (!allowed) {
      final status = await _quota.getStatus(uid);
      throw QuotaExceededException(status);
    }
    await _quota.recordAiCall(uid);
  }

  Future<String> generateWithFallback(List<Content> content) async {
    // QuotaExceededException is intentionally NOT caught here —
    // it propagates to the UI so the quota-exceeded sheet can be shown.
    await _checkAndRecord();
    // Current valid models in priority order (fastest → most capable)
    final modelsToTry = [
      'gemini-2.5-flash',        // Latest fast model (replaces 2.0-flash)
      'gemini-2.5-pro',          // Latest pro model
      'gemini-1.5-pro',          // Stable pro fallback
      'gemini-1.5-flash',        // Stable fast fallback
    ];
    List<String> errors = [];
    int modelCount = 0;

    for (var modelName in modelsToTry) {
      modelCount++;
      try {
        final currentModel = GenerativeModel(model: modelName, apiKey: _apiKey);
        // 45s timeout — complex legal analysis can take time on free tier
        final response = await currentModel.generateContent(content).timeout(const Duration(seconds: 45));
        if (response.text != null && response.text!.isNotEmpty) return response.text!;
      } catch (e) {
        String err = e.toString();
        errors.add('$modelName: ${err.length > 60 ? err.substring(0, 60) + "..." : err}');
        
        // Continue to next model
        continue;
      }
    }

    // FINAL WORST-CASE FALLBACK: Call the Cloud AI Backend (which can use DeepSeek)
    try {
      final prompt = content.map((c) => c.toString()).join('\n');
      final response = await _callBackendFallback(prompt);
      if (response != null) return response;
      errors.add('Backend: returned null (check server logs)');
    } catch (e) {
      errors.add('Backend Error: $e');
    }

    return 'AI Error: All models failed.\n' + errors.map((e) => '• $e').join('\n');
  }

  /// Ultimate fallback: Call the Node.js backend (lexami-backend)
  Future<String?> _callBackendFallback(String prompt) async {
    try {
      // Backend endpoint: POST /api/analyze  (lexami-backend on Render.com)
      const backendUrl = 'https://lexami-backend-d3t5.onrender.com';
      final response = await http.post(
        Uri.parse('$backendUrl/api/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'caseType': 'General',
          'summary': prompt,
        }),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend returns { success: true, result: "..." }
        return data['result'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// NEW: Streaming support for instant feedback with Precedent Analysis
  Stream<String> streamAnalysis(String caseDescription) {
    final instructions = """
    You are LexAni AI, a senior legal researcher specializing in Indian Family Law. 
    Analyze the provided case details and provide a comprehensive legal report:
    1. LEGAL ANALYSIS: Explain the applicable statutes (HMA, DV Act, etc.).
    2. STRENGTHS (PRECEDENTS): List specific Supreme Court or High Court cases that make the user's position STRONGER. Explain the 'Point of Law'.
    3. WEAKNESSES (RISKS): List specific cases or legal points that make the user's position WEAKER or show potential risks.
    4. STRATEGIC GUIDANCE: Immediate next steps.
    
    Use a professional markdown format with clear headings.
    """;

    final content = [
      Content.text('$instructions\n\nCase Description: $caseDescription')
    ];
    
    return streamWithFallback(content);
  }

  /// Generic streaming method
  Stream<String> streamCustomPrompt(String instructions, String input) {
    final content = [Content.text('/$instructions\n\nInput: $input')];
    return streamWithFallback(content);
  }

  /// Multimodal streaming for processing documents + text
  Stream<String> streamMultimodalAnalysis(String instructions, String input, List<Map<String, dynamic>> attachments) {
    final List<Part> parts = [
      TextPart("""
      $instructions
      
      ADDITIONAL TASK:
      Analyze the provided documents AND the user summary. 
      - Identify specific 'Points of Strength' backed by Supreme Court/High Court precedents.
      - Identify 'Points of Weakness' or risks based on the documents provided.
      - List supporting cases and explain why they apply.
      
      User Input: $input
      """),
    ];

    for (var attachment in attachments) {
      parts.add(DataPart(attachment['mimeType'], attachment['bytes']));
    }

    final content = [Content.multi(parts)];
    return streamWithFallback(content);
  }

  /// ROBUST STREAMING FALLBACK
  Stream<String> streamWithFallback(List<Content> content) async* {
    try {
      await _checkAndRecord();
    } on QuotaExceededException catch (e) {
      yield 'QUOTA_EXCEEDED:${e.status.used}:${e.status.limit}';
      return;
    }
    final modelsToTry = [
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
    ];

    String lastError = '';
    bool success = false;

    for (var modelName in modelsToTry) {
      try {
        final currentModel = GenerativeModel(
          model: modelName, 
          apiKey: _apiKey,
        );
        
        final responseStream = currentModel.generateContentStream(content)
            .timeout(const Duration(seconds: 60));

        String fullText = '';
        await for (final chunk in responseStream) {
          if (chunk.text != null) {
            fullText += chunk.text!;
            yield fullText;
            success = true;
          }
        }

        if (success) return;
      } catch (e) {
        lastError = e.toString();
        // Always try next model regardless of error type
        if (lastError.contains('404') ||
            lastError.contains('not found') ||
            lastError.contains('not supported') ||
            lastError.contains('429') ||
            lastError.contains('quota') ||
            lastError.contains('503') ||
            lastError.contains('TimeoutException')) {
          continue;
        }
        continue; // Try next model even on unexpected errors
      }
    }

    // FINAL FALLBACK: Backend
    if (!success) {
      yield '🔄 Model failed. Falling back to backend AI...';
      try {
        final prompt = content.map((c) => c.toString()).join('\n');
        final response = await _callBackendFallback(prompt);
        if (response != null) {
          yield response;
          return;
        }
      } catch (e) {
        lastError += ' | Backend failed: $e';
      }
      yield 'AI Error: All models failed. Last error: $lastError';
    }
  }

  Future<String> analyzeCaseRAG({
    required String query,
    required List<LegalStatute> statutes,
    required List<LandmarkJudgment> judgments,
    required List<BlogPost> blogs,
    required List<ForumQuestion> forumPosts,
  }) async {
    final statuteContext = statutes.map((s) => "Act: ${s.actName}, Section: ${s.section}\nDescription: ${s.description}").join("\n\n");
    final judgmentContext = judgments.map((j) => "Case: ${j.caseName}, Court: ${j.court} (${j.year})\nSummary: ${j.summary}\nRuling: ${j.ruling}").join("\n\n");
    final blogContext = blogs.map((b) => "Blog Title: ${b.title}\nAuthor: ${b.authorName}\nContent: ${b.content}").join("\n\n");
    final forumContext = forumPosts.map((f) => "Forum Topic: ${f.title}\nDescription: ${f.description}\nTags: ${f.tags.join(', ')}").join("\n\n");

    final fullPrompt = '''
You are "LexAni AI", a compassionate and expert legal research assistant for Indian Family Law.
Your goal is to provide a context-aware, grounded response to the user's query using the provided knowledge base.

Guidelines:
1. Grounding: Use ONLY the provided context. If a blog contains emotional advice or a statute provides legal rules, cite them specifically.
2. Empathy: Start with a brief empathetic acknowledgement of the user's situation.
3. Clarity: Differentiate between "Official Law" (Statutes/Judgments) and "Community Experience" (Blogs/Forum).
4. Citing Sources: When mentioning information, cite it like [Act: HMA Section 13] or [Blog: Recovery Guide].
5. No Final Advice: Always include a disclaimer that this is information, not official legal advice.

Context Info:
---
OFFICIAL STATUTES:
$statuteContext

LANDMARK JUDGMENTS:
$judgmentContext

EXPERT BLOGS:
$blogContext

COMMUNITY FORUM DISCUSSIONS:
$forumContext
---

User Query: $query

Format your response as follows:

Initial Greeting & Empathy:
[Empathy-first acknowledgement]

Legal Framework (Statutes & Laws):
- [List relevant laws with source citations]

Judicial Precedents:
- [Reference judgments and their relevance]

Community & Expert Insights:
- [Include wisdom from blogs and forum discussions with citations]

Actionable Roadmap:
- [Suggested next legal or emotional steps]

Disclaimer:
This information is grounded in LexAni's knowledge base and does not constitute official legal advice. Please consult a qualified [legal professional](/advisors) or legal expert.
''';

    return await generateWithFallback([Content.text(fullPrompt)]);
  }

  Future<String> analyzeCase(String caseDescription) async {
    final content = [
      Content.text('${AppConstants.advisorMatchSystemInstruction}\n\nCase Description: $caseDescription')
    ];
    return await generateWithFallback(content);
  }

  Future<String> analyzeAlimony(String prompt) async {
    final content = [
      Content.text('You are a legal expert specializing in Indian Alimony laws (Rajnesh v. Neha guidelines). Analyze the following financial details and provide a "Personalized Alimony Strategy". Focus on whether alimony should be maximized or minimized, the approximate range, and the legal rationale. \n\nIMPORTANT: Include a "Legal References" section at the end listing specific sections (e.g. Sec 125 CrPC, Sec 24 HMA) and Landmark Judgments relevant to this calculation. ALWAYS add a disclaimer: "Please consult a [legal professional](/advisors) for final confirmation."\n\n$prompt')
    ];
    return await generateWithFallback(content);
  }

  Future<String> generateLegalDraft(String prompt) async {
    final content = [
      Content.text('''You are an expert Indian Family Law legal drafter. Generate a professional, court-ready legal document based on the following details. Use formal legal language as used in Indian Courts (CPC/HMA).

If the Document Type is "Affidavit of Assets and Liabilities (Rajnesh v. Neha)", follow these specific requirements:
1. Comply strictly with the format prescribed by the Supreme Court in Rajnesh v. Neha (2021).
2. Sections to include: 
   - Personal Information of the Deponent.
   - Details of Income, Assets, and Liabilities.
   - Monthly expenses and standard of living.
   - Details of legal proceedings and maintenance already being paid.
   - Formal verification and non-disclosure warning.

Else if the Document Type is "Memorandum of Settlement", focus on:
1. Recitals (Background of the dispute).
2. Terms of Settlement (Specific agreements on alimony, custody, assets, and future conduct).
3. Withdrawal of Cases (Agreement to withdraw pending litigations).
4. Full and Final Settlement clause.
5. Verification/Signature section for both parties.
6. Verification section for identifying parties by their respective advocates.

Otherwise, include standard sections: Petitioner, Respondent, Jurisdiction, Facts, and Prayer sections.

IMPORTANT: At the very end of the document, add a separate "Legal References & Statutory Notes" section listing the specific laws and sections (e.g. Sec 13B HMA, Sec 89 CPC for settlements) that the user should read to understand their rights better.

$prompt''')
    ];
    // This method seems to be used as a non-streaming fallback or specific tool.
    // However, DocGeneratorScreen is now mostly using streaming.
    return await generateWithFallback(content);
  }

  Future<String> summarizeEvidence(String rawEvidence) async {
    final content = [
      Content.text('You are a legal expert specializing in Indian Family Law. Analyze the following raw incident description or audio transcript and provide a "Court-Ready Legal Summary". Structure it with: 1. Key Facts, 2. Legal Relevance, 3. Suggested Evidence Type (e.g., Oral Evidence, Documentary Evidence), and 4. Legal References (Specific Sections or Case Laws relevant to this evidence).\n\nRaw Evidence: $rawEvidence\n\nNote: Please consult a [legal professional](/advisors) before using this evidence in court.\n')
    ];
    return await generateWithFallback(content);
  }

  Future<String> transcribeAudioFile(Uint8List bytes, String mimeType) async {
    final content = [
      Content.multi([
        DataPart(mimeType, bytes),
        TextPart('Transcribe this audio file accurately for legal evidence. Return only the transcription text.'),
      ])
    ];

    final audioModels = [
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-1.5-pro',
      'gemini-1.5-flash',
    ];

    String lastError = '';

    for (var modelName in audioModels) {
      try {
        final currentModel = GenerativeModel(model: modelName, apiKey: _apiKey);
        final response = await currentModel.generateContent(content).timeout(const Duration(seconds: 30));
        return response.text ?? 'AI Error: Transcription yielded no results.';
      } catch (e) {
        lastError = e.toString();
        if (lastError.contains('404') || lastError.contains('not supported')) continue;
        return 'AI Error: $e';
      }
    }

    return 'AI Error: Transcription failed. $lastError';
  }

  Future<String> extractFacts(String rawStory) async {
    final prompt = """
    You are "Tathya AI", an intelligent fact extraction system for Indian Family Law cases.
    
    Extract ALL relevant information from the following user story and format it EXACTLY as shown below.
    If any information is not mentioned, write "Not mentioned" for that field.
    
    REQUIRED OUTPUT FORMAT:
    
    === PETITIONER DETAILS ===
    Petitioner Name: [Full name of the person telling the story]
    Petitioner Father/Husband Name: [Father's or Husband's name if mentioned]
    Petitioner Age: [Age if mentioned, otherwise "Not mentioned"]
    Petitioner Address: [Full address if mentioned]
    Petitioner City: [City if mentioned]
    Petitioner State: [State if mentioned]
    
    === RESPONDENT DETAILS ===
    Respondent Name: [Name of spouse/other party]
    Respondent Father/Husband Name: [Father's or Husband's name if mentioned]
    Respondent Age: [Age if mentioned, otherwise "Not mentioned"]
    Respondent Address: [Address if mentioned]
    Respondent City: [City if mentioned]
    Respondent State: [State if mentioned]
    
    === MARRIAGE DETAILS ===
    Marriage Date: [Date in YYYY-MM-DD format if mentioned]
    Marriage Place: [Place/City where marriage was solemnized]
    Children Count: [Number of children, or 0 if none mentioned]
    
    === CASE FACTS ===
    [Detailed chronological summary of the key legal facts, incidents, and grievances mentioned in the story. Format as bullet points.]
    
    === ADDITIONAL CONTEXT ===
    [Any other relevant information like financial details, employment, property, incidents of violence, etc.]
    
    User Story:
    $rawStory
    
    IMPORTANT: Extract information intelligently. For example:
    - If user says "I am Rajesh", extract "Rajesh" as Petitioner Name
    - If user says "my wife Sunita", extract "Sunita" as Respondent Name
    - If user says "we married on 12th Jan 2015", extract "2015-01-12" as Marriage Date
    - If user says "we have two kids", extract "2" as Children Count
    - Infer relationships and roles from context
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> extractAlimonyInfo(String rawStory) async {
    final prompt = """
    You are "Tathya AI", an intelligent information extraction system for Alimony calculations.
    
    Extract ALL relevant financial and personal information from the following user story.
    If any information is not mentioned, write "Not mentioned" for that field.
    
    REQUIRED OUTPUT FORMAT:
    
    Mode: [seeking/giving - based on whether user is asking for alimony or paying it]
    Gender: [male/female/other - gender of the person telling the story]
    My Income: [Monthly income in numbers only, no currency symbol]
    Spouse Income: [Spouse's monthly income in numbers only]
    Marriage Years: [Duration of marriage in years]
    Children Count: [Number of children]
    
    === ADDITIONAL CONTEXT ===
    [Any other relevant financial information like property, employment status, health issues, etc.]
    
    User Story:
    $rawStory
    
    IMPORTANT: Extract information intelligently. For example:
    - If user says "I earn 50000 per month", extract "50000" as My Income
    - If user says "my husband makes 80000", extract "80000" as Spouse Income
    - If user says "we've been married for 5 years", extract "5" as Marriage Years
    - If user says "we have 2 children", extract "2" as Children Count
    - If user says "I want alimony" or "I need maintenance", set Mode to "seeking"
    - If user says "I have to pay alimony" or "my wife is asking for maintenance", set Mode to "giving"
    - Infer gender from pronouns and context
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> parseDocumentImage(Uint8List bytes, String mimeType) async {
    final prompt = """
    You are an AI document scanner for legal documents. Extract the following details from this image (e.g., Marriage Certificate, ID proof, or Court Order):
    - Full Names of Parties
    - Date of Event (Marriage/Order)
    - Place/City
    - Document Serial Number
    
    Format the output as a structured list of key-value pairs.
    """;

    final content = [
      Content.multi([
        DataPart(mimeType, bytes),
        TextPart(prompt),
      ])
    ];

    return await generateWithFallback(content);
  }

  /// Get comprehensive legal budget estimate based on real Indian court data
  /// Data sources: National Judicial Data Grid (NJDG), Law Commission Report No. 245
  Map<String, dynamic> getLegalBudgetEstimate(String caseType, String state) {
    // Normalize inputs
    final normalizedType = caseType.toLowerCase();
    final normalizedState = state.toLowerCase();
    
    // Determine if it's a metro city (higher costs)
    final metroCities = ['delhi', 'mumbai', 'maharashtra', 'bangalore', 'karnataka', 'chennai', 'tamil nadu', 'kolkata', 'west bengal', 'hyderabad', 'telangana'];
    final isMetro = metroCities.any((city) => normalizedState.contains(city));
    final locationMultiplier = isMetro ? 1.3 : 1.0;
    
    // Base data structure for different case types
    Map<String, dynamic> budgetData;
    
    if (normalizedType.contains('mutual consent')) {
      budgetData = _getMutualConsentBudget(locationMultiplier);
    } else if (normalizedType.contains('divorce') || normalizedType.contains('judicial separation')) {
      budgetData = _getContestedDivorceBudget(locationMultiplier);
    } else if (normalizedType.contains('maintenance') || normalizedType.contains('alimony')) {
      budgetData = _getMaintenanceBudget(locationMultiplier);
    } else if (normalizedType.contains('custody') || normalizedType.contains('child')) {
      budgetData = _getCustodyBudget(locationMultiplier);
    } else if (normalizedType.contains('domestic violence') || normalizedType.contains('dv')) {
      budgetData = _getDomesticViolenceBudget(locationMultiplier);
    } else {
      budgetData = _getGenericFamilyLawBudget(locationMultiplier);
    }
    
    budgetData['location'] = isMetro ? 'Metro City' : 'Tier-2/3 City';
    budgetData['state'] = state;
    return budgetData;
  }
  
  Map<String, dynamic> _getMutualConsentBudget(double multiplier) {
    return {
      'caseType': 'Mutual Consent Divorce',
      'phases': [
        {
          'name': 'Filing & First Motion (Month 1)',
          'duration': '1 month',
          'items': [
            {'item': 'Court filing fees', 'cost': (100 * multiplier).round()},
            {'item': 'Lawyer consultation & drafting', 'cost': (8000 * multiplier).round()},
            {'item': 'Notary & documentation', 'cost': (2000 * multiplier).round()},
          ],
        },
        {
          'name': 'Cooling Period (6 months mandatory)',
          'duration': '6 months',
          'items': [
            {'item': 'Lawyer retainer (if needed)', 'cost': (5000 * multiplier).round()},
            {'item': 'Mediation sessions (optional)', 'cost': (3000 * multiplier).round()},
          ],
        },
        {
          'name': 'Second Motion & Decree (Month 7-8)',
          'duration': '1-2 months',
          'items': [
            {'item': 'Final hearing appearance', 'cost': (5000 * multiplier).round()},
            {'item': 'Decree processing', 'cost': (2000 * multiplier).round()},
          ],
        },
      ],
      'totalMin': (20000 * multiplier).round(),
      'totalMax': (30000 * multiplier).round(),
      'timelineMin': '7 months',
      'timelineMax': '10 months',
      'dataSource': 'Sec 13B HMA mandates 6-month cooling period. NJDG data shows avg 8-9 months for MCD cases.',
      'warning': '⚠️ Beware of lawyers quoting ₹5,000-₹8,000 total. This usually covers only initial filing, not the full 7-10 month process.',
    };
  }
  
  Map<String, dynamic> _getContestedDivorceBudget(double multiplier) {
    return {
      'caseType': 'Contested Divorce',
      'phases': [
        {
          'name': 'Filing & Initial Hearings (2-4 months)',
          'duration': '2-4 months',
          'items': [
            {'item': 'Court filing fees', 'cost': (3000 * multiplier).round()},
            {'item': 'Lawyer consultation & petition drafting', 'cost': (12000 * multiplier).round()},
            {'item': 'First 3-4 hearings', 'cost': (8000 * multiplier).round()},
            {'item': 'Service of summons', 'cost': (2000 * multiplier).round()},
          ],
        },
        {
          'name': 'Evidence & Arguments (8-15 months)',
          'duration': '8-15 months',
          'items': [
            {'item': 'Document preparation & affidavits', 'cost': (6000 * multiplier).round()},
            {'item': 'Witness examination (3-5 witnesses)', 'cost': (5000 * multiplier).round()},
            {'item': 'Ongoing hearings (10-15 hearings)', 'cost': (15000 * multiplier).round()},
            {'item': 'Expert witness fees (if needed)', 'cost': (5000 * multiplier).round()},
          ],
        },
        {
          'name': 'Final Arguments & Judgment (3-6 months)',
          'duration': '3-6 months',
          'items': [
            {'item': 'Final arguments preparation', 'cost': (10000 * multiplier).round()},
            {'item': 'Final hearings (2-3 sessions)', 'cost': (6000 * multiplier).round()},
            {'item': 'Decree processing', 'cost': (3000 * multiplier).round()},
          ],
        },
      ],
      'totalMin': (45000 * multiplier).round(),
      'totalMax': (90000 * multiplier).round(),
      'timelineMin': '13 months',
      'timelineMax': '25 months',
      'dataSource': 'Law Commission Report 245: Avg contested divorce takes 18-24 months. NJDG 2023 data shows Family Courts avg 19.3 months.',
      'warning': '⚠️ Many lawyers quote ₹10,000-₹15,000 initially to attract clients. This typically covers only consultation and filing. Actual costs accumulate over 1.5-2 years of hearings.',
    };
  }
  
  Map<String, dynamic> _getMaintenanceBudget(double multiplier) {
    return {
      'caseType': 'Maintenance / Alimony',
      'phases': [
        {
          'name': 'Filing & Interim Relief (2-3 months)',
          'duration': '2-3 months',
          'items': [
            {'item': 'Court filing fees', 'cost': (50 * multiplier).round()},
            {'item': 'Lawyer fees for application', 'cost': (8000 * multiplier).round()},
            {'item': 'Interim maintenance hearings', 'cost': (5000 * multiplier).round()},
          ],
        },
        {
          'name': 'Evidence & Final Order (6-12 months)',
          'duration': '6-12 months',
          'items': [
            {'item': 'Income affidavits & documentation', 'cost': (4000 * multiplier).round()},
            {'item': 'Ongoing hearings (6-10 hearings)', 'cost': (12000 * multiplier).round()},
            {'item': 'Final arguments', 'cost': (6000 * multiplier).round()},
          ],
        },
      ],
      'totalMin': (25000 * multiplier).round(),
      'totalMax': (45000 * multiplier).round(),
      'timelineMin': '8 months',
      'timelineMax': '15 months',
      'dataSource': 'Sec 125 CrPC cases avg 10-14 months (NJDG). Interim relief usually granted in 2-3 months per Rajnesh v. Neha guidelines.',
      'warning': '⚠️ Initial quotes of ₹5,000-₹8,000 usually cover only the application filing, not the full 8-15 month process including evidence and final hearings.',
    };
  }
  
  Map<String, dynamic> _getCustodyBudget(double multiplier) {
    return {
      'caseType': 'Child Custody',
      'phases': [
        {
          'name': 'Filing & Interim Custody (2-4 months)',
          'duration': '2-4 months',
          'items': [
            {'item': 'Court filing fees', 'cost': (50 * multiplier).round()},
            {'item': 'Lawyer consultation & petition', 'cost': (10000 * multiplier).round()},
            {'item': 'Interim custody hearings', 'cost': (6000 * multiplier).round()},
          ],
        },
        {
          'name': 'Investigation & Evidence (6-10 months)',
          'duration': '6-10 months',
          'items': [
            {'item': 'Child welfare report (court-ordered)', 'cost': (5000 * multiplier).round()},
            {'item': 'Witness statements & affidavits', 'cost': (5000 * multiplier).round()},
            {'item': 'Ongoing hearings (8-12 hearings)', 'cost': (15000 * multiplier).round()},
          ],
        },
        {
          'name': 'Final Order (2-4 months)',
          'duration': '2-4 months',
          'items': [
            {'item': 'Final arguments', 'cost': (8000 * multiplier).round()},
            {'item': 'Final hearings', 'cost': (5000 * multiplier).round()},
          ],
        },
      ],
      'totalMin': (40000 * multiplier).round(),
      'totalMax': (70000 * multiplier).round(),
      'timelineMin': '10 months',
      'timelineMax': '18 months',
      'dataSource': 'Guardianship cases avg 12-16 months (NJDG 2023). Courts prioritize child welfare per Sec 26 Hindu Marriage Act.',
      'warning': '⚠️ Custody battles are emotionally and financially draining. Initial low quotes (₹8,000-₹12,000) rarely cover the full investigation and hearing process.',
    };
  }
  
  Map<String, dynamic> _getDomesticViolenceBudget(double multiplier) {
    return {
      'caseType': 'Domestic Violence (DV Act)',
      'phases': [
        {
          'name': 'Filing & Protection Order (1-2 months)',
          'duration': '1-2 months',
          'items': [
            {'item': 'Court filing fees', 'cost': 0}, // Free under DV Act Sec 12
            {'item': 'Lawyer fees (if not using Legal Aid)', 'cost': (6000 * multiplier).round()},
            {'item': 'Interim protection order hearings', 'cost': (4000 * multiplier).round()},
          ],
        },
        {
          'name': 'Evidence & Final Order (4-8 months)',
          'duration': '4-8 months',
          'items': [
            {'item': 'Medical reports & evidence', 'cost': (3000 * multiplier).round()},
            {'item': 'Witness statements', 'cost': (3000 * multiplier).round()},
            {'item': 'Ongoing hearings (5-8 hearings)', 'cost': (8000 * multiplier).round()},
          ],
        },
      ],
      'totalMin': (15000 * multiplier).round(),
      'totalMax': (30000 * multiplier).round(),
      'timelineMin': '5 months',
      'timelineMax': '10 months',
      'dataSource': 'DV Act 2005 mandates fast-track disposal. NJDG shows avg 6-8 months. Legal Aid available under Sec 12 for free representation.',
      'warning': '💡 TIP: DV cases have NO court fees. Legal Aid is available for free lawyer representation. Don\'t pay upfront fees without verifying eligibility for free legal aid.',
    };
  }
  
  Map<String, dynamic> _getGenericFamilyLawBudget(double multiplier) {
    return {
      'caseType': 'Family Law Case',
      'phases': [
        {
          'name': 'Filing & Initial Hearings (2-4 months)',
          'duration': '2-4 months',
          'items': [
            {'item': 'Court filing fees', 'cost': (100 * multiplier).round()},
            {'item': 'Lawyer consultation & drafting', 'cost': (10000 * multiplier).round()},
            {'item': 'Initial hearings', 'cost': (6000 * multiplier).round()},
          ],
        },
        {
          'name': 'Evidence & Arguments (6-12 months)',
          'duration': '6-12 months',
          'items': [
            {'item': 'Document preparation', 'cost': (5000 * multiplier).round()},
            {'item': 'Ongoing hearings', 'cost': (12000 * multiplier).round()},
          ],
        },
        {
          'name': 'Final Order (2-4 months)',
          'duration': '2-4 months',
          'items': [
            {'item': 'Final arguments & hearings', 'cost': (8000 * multiplier).round()},
          ],
        },
      ],
      'totalMin': (30000 * multiplier).round(),
      'totalMax': (55000 * multiplier).round(),
      'timelineMin': '10 months',
      'timelineMax': '20 months',
      'dataSource': 'General family law cases avg 12-18 months in Family Courts (NJDG 2023 data).',
      'warning': '⚠️ Legal costs accumulate over time. Initial low quotes often don\'t reflect the full timeline of hearings and evidence stages.',
    };
  }
  
  /// Legacy method for backward compatibility - returns simple string
  String getCourtFeeEstimate(String caseType, String state) {
    final budget = getLegalBudgetEstimate(caseType, state);
    return "₹${budget['totalMin']}-₹${budget['totalMax']} (${budget['timelineMin']}-${budget['timelineMax']})";
  }

  Future<String> cleanTranscript(String rawTranscript) async {
    final prompt = """
    You are an AI Audio Post-Processor. The following text is a transcription of a live voice recording which may contain background noise artifacts, stutters, repetitions, and grammatical inconsistencies. 
    
    TASK:
    1. Remove background noise "artifacts" (words that don't belong in the context).
    2. Correct stutters and repetitions.
    3. Improve flow while maintaining the EXACT original meaning and tone.
    4. Return ONLY the cleaned text.
    
    Raw Transcript:
    $rawTranscript
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> summarizeCaseHistory(List<CaseTimelineEntry> timeline) async {
    final history = timeline.map((e) => "Date: ${e.date}\nDescription: ${e.description}").join("\n---\n");
    final prompt = """
    You are "LexAni Case Reviewer". Analyze the following case history and provide:
    1. EXECUTIVE SUMMARY: A 2-sentence summary of the case progress.
    2. KEY MILESTONES: List top 3 critical events.
    3. TREND ANALYSIS: Are things moving towards resolution or escalating?
    4. STRATEGIC INSIGHT: What should the user focus on for the next hearing?
    
    Case History:
    $history
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> analyzeCaseBudget(double budget, List<CaseExpense> expenses) async {
    final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final expenseDetails = expenses.map((e) => "${e.date.toString().split(' ')[0]}: ${e.title} - ₹${e.amount} (${e.category})").join("\n");
    
    final prompt = """
    You are "LexAni Financial Legal Auditor". Analyze the following case budget and expenses:
    
    Total Budget: ₹$budget
    Total Spent: ₹$totalSpent
    Remaining: ₹${budget - totalSpent}
    
    Expense Breakdown:
    $expenseDetails
    
    TASK:
    1. EFFICIENCY RATING: Is the user overspending in certain categories?
    2. SAVING TIPS: How can they optimize their legal spend (e.g., mediation, consolidating hearings)?
    3. PROJECTION: Based on current spend, will the budget hold until case resolution?
    4. LEGAL HACK: Mention if "Pro Bono" or "Legal Aid" is an option if budget is tight.
    
    Provide a professional, empathetic financial report.
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> predictCaseOutcome(LegalCase liveCase) async {
    final history = liveCase.timeline.map((e) => "Date: ${e.date}\nDescription: ${e.description}").join("\n---\n");
    final expenses = liveCase.expenses.map((e) => "${e.title}: ₹${e.amount}").join(", ");
    
    final prompt = """
    You are "LexAni Case Strategist". Based on the following historical timeline and financial commitment, predict the likely outcome and direction of this case.
    
    Case Type: ${liveCase.type}
    History:
    $history
    
    Financial Commitment:
    Budget: ₹${liveCase.totalBudget}
    Spent: ₹${liveCase.totalSpent}
    Expenses: $expenses
    
    TASK:
    1. PROBABILITY SCORE: Estimated % chance of a favorable outcome (Mutual Settlement vs. Court Order).
    2. ESTIMATED TIMELINE: How many more months/years till resolution?
    3. CRITICAL RISKS: What could derail the case?
    4. STRATEGIC DISCLOSURE: Are there any gaps in the documented history?
    
    Return a strategic, data-driven prediction.
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> analyzeWitnessStatement(String statement, String witnessName, String relation) async {
    final prompt = """
    You are "LexAni Witness Profiler". Analyze the following statement given by a witness:
    
    Witness Name: $witnessName
    Relation: $relation
    Statement:
    $statement
    
    TASK:
    1. CONSISTENCY CHECK: Are there logical contradictions or vague areas in the narrative?
    2. BIAS DETECTION: Does the statement show clear bias based on the relation to the parties?
    3. CROSS-EXAMINATION STRATEGY: List 5 crucial questions the opposing counsel might ask to challenge this statement.
    4. STRENGTH RATING: Rate the reliability of this witness from 1-10.
    
    Format the response with professional legal headings.
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> getLegalPrecedents(LegalCase liveCase) async {
    final history = liveCase.timeline.map((e) => e.description).join(" ");
    
    final prompt = """
    You are "LexAni Precedent Researcher". Search and identify 3-5 Landmark Supreme Court or High Court of India judgments relevant to the following case:
    
    Case Type: ${liveCase.type}
    Case Summary: $history
    
    TASK:
    1. CASE NAME & CITATION: Provide the full name and citation (e.g., 2021 SCC 123).
    2. RELEVANCE: Why does this judgment apply to the user's situation?
    3. FAVORABLE OR ADVERSE: Explain if this helps the user or if they should be cautious of it.
    4. SUMMARY OF RULE: What was the primary legal principle established?
    
    Provide actionable legal research.
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> suggestAlimonyAdjustment(List<AlimonyRecord> records, double currentMyIncome, double currentSpouseIncome) async {
    final history = records.map((e) => "${e.date.toString().split(' ')[0]}: ${e.type} ₹${e.amount} (${e.category})").join("\n");
    
    final prompt = """
    You are "LexAni Alimony Auditor". Analyze the alimony payment history and current financial status:
    
    Current Monthly Income (Self): ₹$currentMyIncome
    Current Monthly Income (Spouse): ₹$currentSpouseIncome
    
    Payment History:
    $history
    
    TASK:
    1. ADJUSTMENT SUGGESTION: Based on Rajnesh v. Neha, should the alimony be increased or decreased?
    2. REASONING: Explain why (e.g., inflation, change in income, lifestyle maintenance).
    3. ARREARS CHECK: Are there any inconsistencies in payment frequency?
    4. LEGAL ADVICE: Mention Sec 127 CrPC for modification of maintenance.
    
    Provide a concise, strategic financial adjustment report.
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> checkDraftFormatting(String draft, Map<String, String> formData) async {
    final prompt = """
    You are a legal auditor. Examine the following legal draft and the provided form fields for inconsistencies, missing information (like dates, addresses, or specific names), and formatting errors based on Indian CPC standards.
    
    Draft:
    $draft
    
    Form Data:
    $formData
    
    Provide a concise report highlighting:
    - CRITICAL MISSING INFO (e.g. missing signature line, empty address)
    - CONSISTENCY ERRORS (e.g. name in form vs name in draft)
    - SUGGESTED IMPROVEMENTS
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }
  Future<String> translateText(String text, String targetLanguage) async {
    final prompt = """
    Translate the following legal text into $targetLanguage.
    Maintain professional legal terminology and tone. Only return the translated text.
    
    Text:
    $text
    """;
    return await generateWithFallback([Content.text(prompt)]);
  }

  Future<String> generateParentingPlan({
    required String childAge,
    required String distance,
    required String workSchedule,
    required String conflictLevel,
  }) async {
    final prompt = """
    You are "LexAni Co-Parenting Architect", an expert in Indian Family Law and Child Psychology.
    Generate a concise, court-admissible Visitation Schedule & Co-Parenting Plan based on the following constraints:

    === INPUTS ===
    Child Age: $childAge
    Distance Between Homes: $distance
    Parents' Work Schedule: $workSchedule
    Conflict Level: $conflictLevel

    === REQUIRED OUTPUT SECTIONS ===
    1. RECOMMENDED SCHEDULE MODEL:
       - Name the model (e.g., "2-2-3", "Alternate Weekends", "Week-on/Week-off").
       - Explain WHY this fits the child's age and parents' distance.
       - Provide a sample 2-week calendar view (text format).

    2. HANDOVER PROTOCOLS:
       - Where (neutral location logic if high conflict).
       - Who does pickup/drop-off.

    3. HOLIDAY & SUMMER BREAKS:
       - Fair division strategy (e.g., "Split summer 50/50", "Alternate Diwali").

    4. COMMUNICATION CLAUSE:
       - Rules for communication (e.g., "App-only", "Email-only" if high conflict).

    5. INDIA-SPECIFIC LEGAL NOTE:
       - Mention relevant Guardians & Wards Act considerations.

    Keep the tone professional, child-centric, and constructive.
    """;

    return await generateWithFallback([Content.text(prompt)]);
  }
}
