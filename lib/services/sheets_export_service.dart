import 'dart:convert';
import 'package:http/http.dart' as http;

class SheetsExportService {
  static const String _exportUrl = 'https://asia-south1-legal-sathi-2025-d4124.cloudfunctions.net/ext-http-export-sheets-saveRecord';

  /// Exports data to the linked Google Sheet via the extension.
  Future<bool> exportRecord(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(_exportUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          // App Check token would go here if enabled:
          // 'X-Firebase-AppCheck': token,
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Sheets Export Failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Sheets Export Error: $e');
      return false;
    }
  }

  /// Specialized method to log Admin actions for auditing.
  Future<void> logAdminAction({
    required String adminName,
    required String action,
    required String targetId,
    required String details,
  }) async {
    await exportRecord({
      'timestamp': DateTime.now().toIso8601String(),
      'admin_name': adminName,
      'action_type': action,
      'target_id': targetId,
      'details': details,
      'module': 'Admin Dashboard',
    });
  }

  /// Specialized method to log financial transactions.
  Future<void> logTransaction({
    required String userId,
    required String email,
    required double amount,
    required String type,
  }) async {
    await exportRecord({
      'timestamp': DateTime.now().toIso8601String(),
      'user_id': userId,
      'user_email': email,
      'amount': amount,
      'type': type,
      'module': 'Wallet',
    });
  }
}
