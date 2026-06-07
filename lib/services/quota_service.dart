import 'package:cloud_firestore/cloud_firestore.dart';
import 'config_service.dart';

/// Tracks and enforces per-user daily AI call quotas.
///
/// Firestore path: users/{uid}/quota/{YYYY-MM-DD}
///   → { count: N, limit: 10, updatedAt: Timestamp }
class QuotaService {
  final FirebaseFirestore _db;

  QuotaService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference _quotaRef(String uid) =>
      _db.collection('users').doc(uid).collection('quota').doc(_today());

  /// Returns how many AI calls the user has made today.
  Future<int> getTodayUsage(String uid) async {
    try {
      final snap = await _quotaRef(uid).get();
      if (!snap.exists) return 0;
      return (snap.data() as Map<String, dynamic>)['count'] as int? ?? 0;
    } catch (_) {
      return 0; // Fail open — don't block user if Firestore is unreachable
    }
  }

  /// Returns true if the user still has quota remaining today.
  Future<bool> canMakeAiCall(String uid) async {
    final used = await getTodayUsage(uid);
    return used < ConfigService.dailyAiQuota;
  }

  /// Records one AI call. Returns the new usage count.
  Future<int> recordAiCall(String uid) async {
    try {
      final ref = _quotaRef(uid);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          final current = (snap.data() as Map<String, dynamic>)['count'] as int? ?? 0;
          tx.update(ref, {
            'count': current + 1,
            'limit': ConfigService.dailyAiQuota,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          tx.set(ref, {
            'count': 1,
            'limit': ConfigService.dailyAiQuota,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      return await getTodayUsage(uid);
    } catch (_) {
      return 0;
    }
  }

  /// Returns remaining calls for today.
  Future<QuotaStatus> getStatus(String uid) async {
    final used = await getTodayUsage(uid);
    final limit = ConfigService.dailyAiQuota;
    return QuotaStatus(used: used, limit: limit);
  }
}

class QuotaStatus {
  final int used;
  final int limit;

  const QuotaStatus({required this.used, required this.limit});

  int get remaining => (limit - used).clamp(0, limit);
  bool get isExceeded => used >= limit;

  /// Compact display e.g. "7/10 AI calls used today"
  String get summaryText => '$used/$limit AI analyses used today';

  /// Color: green → orange → red based on usage
  double get fractionUsed => limit > 0 ? used / limit : 1.0;
}
