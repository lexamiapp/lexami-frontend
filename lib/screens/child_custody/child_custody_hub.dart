import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../utils/app_localizations.dart';

class ChildCustodyHubScreen extends StatelessWidget {
  const ChildCustodyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('co_parenting') ?? 'Child Custody & Co-Parenting'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChildFirstBanner(context),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)?.locale.languageCode == 'hi' ? 'सह-पालन उपकरण' : 'Co-Parenting Tools',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blueGrey),
                ),
                const SizedBox(height: 16),
                _buildToolsGrid(context),
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)?.translate('harmony_compliance') ?? 'Harmony & Compliance',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.blueGrey),
                ),
                const SizedBox(height: 16),
                _buildComplianceSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildFirstBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade200,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.heartHandshake, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context)?.translate('child_first_framework') ?? 'Child-First Framework',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)?.locale.languageCode == 'hi' 
                ? 'अपने बच्चे की स्थिरता और भलाई सुनिश्चित करें। यह टूल आपको अदालती पालन-पोषण योजनाएं बनाने और सुरक्षित संवाद करने में मदद करता है।'
                : 'Ensure your child\'s stability and well-being. This tool helps you create court-friendly parenting plans and communicate without conflict.',
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    final local = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _toolCard(
          context,
          local?.translate('child_profile_context') ?? 'Child Profile\n& Context',
          local?.translate('step_1') ?? 'Step 1',
          LucideIcons.baby,
          Colors.orange,
          () => context.go('/home/custody/child-profile'),
        ),
        _toolCard(
          context,
          local?.translate('parenting_plan_builder') ?? 'Parenting Plan\nBuilder',
          local?.locale.languageCode == 'hi' ? 'मुख्य विशेषता' : 'Core Feature',
          LucideIcons.fileSignature,
          Colors.blue,
          () => context.go('/home/custody/plan-builder'),
        ),
        _toolCard(
          context,
          local?.translate('visitation_calendar') ?? 'Visitation\nCalendar',
          local?.locale.languageCode == 'hi' ? 'शेड्यूल और हैंडओवर' : 'Schedule & Handovers',
          LucideIcons.calendarCheck,
          Colors.purple,
          () => context.go('/home/custody/calendar'),
        ),
        _toolCard(
          context,
          local?.translate('secure_communication') ?? 'Secure\nCommunication',
          local?.locale.languageCode == 'hi' ? 'संघर्ष-मुक्त चैट' : 'Conflict-Free Chat',
          LucideIcons.messageCircle,
          Colors.green,
          () => context.go('/home/custody/secure-comm'),
        ),
      ],
    );
  }

  Widget _toolCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceSection(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/home/custody/compliance'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Column(
          children: [
            _complianceItem('Dispute Resolution', 'Mediator-first approach built-in'),
            const Divider(),
            _complianceItem('Legal Audit', 'Aligned with Guardians & Wards Act'),
            const Divider(),
            _complianceItem('Safety Monitoring', 'Well-being checks & abuse indicators'),
          ],
        ),
      ),
    );
  }

  Widget _complianceItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.checkCircle, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
