import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class AdvisorService {
  // Backend URL - Update this when deploying
  static const String baseUrl = 'https://lexami-backend-d3t5.onrender.com/api';

  // Get all verified advisors
  static Future<List<Map<String, dynamic>>> getVerifiedAdvisors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/advisors/verified'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['advisors'] != null) {
          return List<Map<String, dynamic>>.from(data['advisors']);
        }
        return [];
      } else {
        print('Error fetching verified advisors: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching verified advisors: $e');
      return [];
    }
  }

  // Get all advisors (including unverified)
  static Future<List<Map<String, dynamic>>> getAllAdvisors() async {
    try {
      final url = '$baseUrl/advisors/all';
      print('🔍 Fetching from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✓ Success: Got advisors');
        final data = jsonDecode(response.body);
        if (data['advisors'] != null) {
          return List<Map<String, dynamic>>.from(data['advisors']);
        }
        return [];
      } else if (response.statusCode == 404) {
        print('❌ ERROR 404: Endpoint not found at $url');
        print('💡 Check if backend is deployed with getAllAdvisors route');
        print('Response: ${response.body}');
        return [];
      } else {
        print('❌ Error: HTTP ${response.statusCode}');
        print('Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching all advisors: $e');
      print('💡 Check if backend is running and internet is connected');
      return [];
    }
  }

  // Get pending advisors (Admin only)
  static Future<List<Map<String, dynamic>>> getPendingAdvisors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/advisors/pending'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['advisors'] != null) {
          return List<Map<String, dynamic>>.from(data['advisors']);
        }
        return [];
      } else {
        print('Error fetching pending advisors: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Exception fetching pending advisors: $e');
      return [];
    }
  }

  // Get advisor by UID
  static Future<Map<String, dynamic>?> getAdvisorByUid(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/advisors/application/$uid'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Exception fetching advisor: $e');
      return null;
    }
  }

  // Stream advisors (for real-time updates)
  static Stream<List<Map<String, dynamic>>> streamAllAdvisors() async* {
    while (true) {
      try {
        final advisors = await getAllAdvisors();
        yield advisors;
        // Refresh every 30 seconds
        await Future.delayed(const Duration(seconds: 30));
      } catch (e) {
        print('Stream error: $e');
        yield [];
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  // Stream verified advisors
  static Stream<List<Map<String, dynamic>>> streamVerifiedAdvisors() async* {
    while (true) {
      try {
        final advisors = await getVerifiedAdvisors();
        yield advisors;
        // Refresh every 30 seconds
        await Future.delayed(const Duration(seconds: 30));
      } catch (e) {
        print('Stream error: $e');
        yield [];
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  // Submit advisor onboarding (MongoDB)
  static Future<Map<String, dynamic>> submitAdvisorOnboarding(Map<String, dynamic> advisorData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/advisors/onboarding/submit'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(advisorData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✓ Advisor application submitted to MongoDB');
        return jsonDecode(response.body);
      } else {
        print('Error submitting advisor: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to submit advisor application: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception submitting advisor: $e');
      rethrow;
    }
  }

  // Verify an advisor (Admin only)
  static Future<bool> verifyAdvisor(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/advisors/verify/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✓ Advisor verified successfully');
        return true;
      } else {
        print('Error verifying advisor: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception verifying advisor: $e');
      return false;
    }
  }
}
