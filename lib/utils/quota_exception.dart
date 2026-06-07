import '../services/quota_service.dart';

class QuotaExceededException implements Exception {
  final QuotaStatus status;
  const QuotaExceededException(this.status);

  @override
  String toString() => 'Daily AI limit reached (${status.used}/${status.limit}). Resets at midnight.';
}
