import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../services/quota_service.dart';

/// Drop-in card shown when the user hits their daily AI quota.
class QuotaExceededCard extends StatelessWidget {
  final QuotaStatus status;
  final VoidCallback? onDismiss;

  const QuotaExceededCard({super.key, required this.status, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    // Time until midnight (quota reset)
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final diff = midnight.difference(now);
    final hoursLeft = diff.inHours;
    final minsLeft = diff.inMinutes % 60;
    final resetStr = hoursLeft > 0 ? '${hoursLeft}h ${minsLeft}m' : '${minsLeft}m';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.deepOrange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.zap, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          const Text(
            "Daily AI Limit Reached",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            "You've used all ${status.limit} free AI analyses for today.\nResets in $resetStr.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss ?? () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/wallet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepOrange.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Upgrade Pro', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the quota exceeded card as a bottom sheet.
void showQuotaExceededSheet(BuildContext context, QuotaStatus status) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => QuotaExceededCard(
      status: status,
      onDismiss: () => Navigator.of(context).maybePop(),
    ),
  );
}
