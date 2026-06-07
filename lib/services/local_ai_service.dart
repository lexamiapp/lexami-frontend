import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class LocalAIService {
  final String baseUrl = AppConstants.activeAiUrl;

  Future<String> analyzeCase(String details, {String provider = "gemini"}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze-case'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.localAiApiKey,
        },
        body: jsonEncode({
          'case_details': details,
          'provider': provider,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['analysis'] ?? 'No analysis returned.';
      } else {
        return 'AI Service Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Failed to connect to AI server: $e';
    }
  }

  Future<String> calculateAlimony(Map<String, dynamic> financialData, {String provider = "gemini"}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/calculate-alimony'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.localAiApiKey,
        },
        body: jsonEncode({
          'financial_data': financialData,
          'provider': provider,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['prediction'] ?? 'No prediction returned.';
      } else {
        return 'AI Service Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Failed to connect to AI server: $e';
    }
  }

  Future<String> generateDraft(String prompt, {String provider = "gemini"}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/generate-draft'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': AppConstants.localAiApiKey,
        },
        body: jsonEncode({
          'prompt': prompt,
          'provider': provider,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['draft'] ?? 'No draft returned.';
      } else {
        return 'AI Service Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Failed to connect to AI server: $e';
    }
  }

  Future<void> warmup() async {
    try {
      // Hit the dedicated warmup endpoint to wake up Cloud Run AND load Embedding Model
      await http.get(Uri.parse('$baseUrl/warmup')).timeout(const Duration(seconds: 15));
      print("AI Backend & Knowledge Base Warmup complete.");
    } catch (_) {
      // Ignore errors during warmup
    }
  }
}
