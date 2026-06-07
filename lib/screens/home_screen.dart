import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../widgets/app_drawer.dart';
import '../utils/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/quota_service.dart';
import '../services/config_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset('assets/images/app_icon.png', width: 24, height: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LexAni',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Your Legal Partner',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Replace with your actual APK URL or ensure file is at this path
                  launchUrl(Uri.parse('https://lexani-5df0d.web.app/app-release.apk'));
                },
                icon: const Icon(Icons.android, size: 18),
                label: const Text('Download App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
           IconButton(
            icon: const Icon(LucideIcons.bell),
            onPressed: () {
            context.go('/notifications');
          }
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => context.go('/profile'),
              borderRadius: BorderRadius.circular(50),
              child: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Text('P', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildHeroSection(context),
              const SizedBox(height: 16),
              _buildQuotaBanner(context),
              const SizedBox(height: 8),
              _buildStatsGrid(),
              const SizedBox(height: 24),
              _buildLegalToolkit(context),
              const SizedBox(height: 24),
              _buildCaseStatus(context),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildQuotaBanner(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUserId;
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<QuotaStatus>(
      future: QuotaService().getStatus(uid),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final status = snap.data!;

        // Only show banner if >50% used or exceeded
        if (status.fractionUsed < 0.5) return const SizedBox.shrink();

        final isExceeded = status.isExceeded;
        final color = isExceeded ? Colors.red.shade700 : Colors.orange.shade700;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(isExceeded ? LucideIcons.zapOff : LucideIcons.zap, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isExceeded
                      ? 'Daily AI limit reached — resets at midnight'
                      : '${status.remaining} AI ${status.remaining == 1 ? "analysis" : "analyses"} left today',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (!isExceeded)
                SizedBox(
                  width: 60,
                  child: LinearProgressIndicator(
                    value: status.fractionUsed,
                    backgroundColor: color.withOpacity(0.2),
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              if (isExceeded) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push('/wallet'),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.grey.shade600),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: () {
        context.pop(); // Close drawer
        context.go(route);
      },
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.blue.shade100, blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LexAni',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your personal AI companion for Indian family law and dispute resolution.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/home/ai-match'),
                icon: const Icon(LucideIcons.brainCircuit, size: 16),
                label: const Text('Case Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _showSupportModal(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white30),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
                 child: const Text('Find Help'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('How can we help you?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 32),
              _buildSupportOption(
                context,
                'Find Expert Advisors',
                'Browse verified experts near you',
                LucideIcons.search,
                Colors.blue,
                () {
                  Navigator.pop(context);
                  context.go('/advisors');
                },
              ),
              const SizedBox(height: 16),
              _buildSupportOption(
                context,
                'LexAni Support',
                'Talk to our helpdesk team',
                LucideIcons.headphones,
                Colors.green,
                () {
                  Navigator.pop(context);
                  context.go('/call');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSupportOption(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _statCard('Advisors', '120+', LucideIcons.users, Colors.blue)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Active Cases', '0', LucideIcons.scale, Colors.amber)),
        const SizedBox(width: 10),
        Expanded(child: _statCard('Success', 'High', LucideIcons.fileCheck, Colors.green)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade50, blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)),
               Icon(icon, size: 14, color: color),
             ],
           ),
           const SizedBox(height: 5),
           Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildLegalToolkit(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LEGAL TOOLKIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _toolCard(context, AppLocalizations.of(context)?.translate('co_parenting') ?? 'Co-Parenting', AppLocalizations.of(context)?.translate('custody_plans') ?? 'Custody & Plans', LucideIcons.baby, Colors.teal, '/home/custody'),
            _toolCard(context, AppLocalizations.of(context)?.translate('alimony_calc') ?? 'Alimony Calc', 'Court estimates', LucideIcons.calculator, Colors.orange, '/home/calculator'),
            _toolCard(context, AppLocalizations.of(context)?.translate('my_cases') ?? 'My Cases', 'Payment records', LucideIcons.briefcase, Colors.green, '/my-cases'),
            _toolCard(context, AppLocalizations.of(context)?.translate('voice_draft') ?? 'Voice Draft', 'Speak to draft', LucideIcons.mic, Colors.purple, '/home/transcriber'),
            _toolCard(context, AppLocalizations.of(context)?.translate('drafting_vault') ?? 'Drafting Vault', 'Draft petitions', LucideIcons.fileText, Colors.blue, '/home/generator'),
            _toolCard(context, AppLocalizations.of(context)?.translate('evidence_vault') ?? 'Evidence Vault', 'Store proof', LucideIcons.folderLock, Colors.indigo, '/home/vault'),
            _toolCard(context, 'Family Solution', 'Dispute guide', LucideIcons.heartHandshake, Colors.pink, '/home/family-solution'),
            _toolCard(context, AppLocalizations.of(context)?.translate('advisors') ?? 'Advisors', 'Verified experts', LucideIcons.search, Colors.amber, '/advisors'),
          ],
        ),
      ],
    );
  }

  Widget _toolCard(BuildContext context, String title, String subtitle, IconData icon, Color color, String route) {
    // Determine background color based on the primary color (lighter shade)
    Color bg = color.withOpacity(0.05);
    Color border = color.withOpacity(0.1);

    return InkWell(
      onTap: () {
        if (route == 'support') {
          _showSupportModal(context);
        } else if (route == '/home/ai-match') {
          context.go('/home/ai-match');
        } else {
          // If route exists in bottom nav, goBranch, otherwise go
          context.go(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: color),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(subtitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseStatus(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.shield, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('LEGAL STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                  ],
                ),
                Icon(LucideIcons.edit3, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('JURISDICTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                    Text('Mumbai, India', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                 Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('NATURE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
                    Text('Financial', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: const Text(
              'Objective: Secure a fair settlement via Indian Family Court precedents.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
