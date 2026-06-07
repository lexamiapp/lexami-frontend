import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_localizations.dart';

class ComplianceSafetyScreen extends StatelessWidget {
  const ComplianceSafetyScreen({super.key});

  void _openGuide(BuildContext context, String title, String content, String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(LucideIcons.bookOpen, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(url)),
                  icon: const Icon(LucideIcons.externalLink),
                  label: const Text('VIEW ORIGINAL STATUTE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('harmony_compliance') ?? 'Harmony & Compliance'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildComplianceCard(
              context,
              'Guardians & Wards Act, 1890',
              'Key provisions related to child custody in India. Learn about the "welfare of the child" principle used by family courts.',
              LucideIcons.scale,
              Colors.blue,
              """Section 7: Power of the Court to make order as to guardianship.
Section 17: Matters to be considered by the Court in appointing guardian. The court shall be guided by what, consistently with the law to which the minor is subject, appears in the circumstances to be for the welfare of the minor.

The 'Welfare of the Child' is the paramount consideration. Courts look at:
1. The age, sex, and religion of the minor.
2. The character and capacity of the proposed guardian.
3. The wishes of the deceased parent (if any).
4. Any existing or previous relations of the proposed guardian with the minor or his property.
5. If the minor is old enough to form an intelligent preference, the court may consider that preference.""",
              'https://www.indiacode.nic.in/handle/123456789/2344'
            ),
            const SizedBox(height: 16),
            _buildComplianceCard(
              context,
              'Dispute Resolution Pathway',
              'Before going to court, try mandatory mediation. This tool helps you prepare for a more amicable negotiation.',
              LucideIcons.heartHandshake,
              Colors.orange,
              """Mediation is a voluntary, confidential process where a neutral third party (the mediator) helps parents reach their own agreement.

Benefits for Parents:
- Less expensive than litigation.
- Faster resolution.
- You keep control over the decisions (instead of a judge).
- Less stress for the child.

Steps in the Pathway:
1. Initial Consult: Understand your legal rights.
2. Selection of Mediator: Mutually agree on a neutral expert.
3. Joint & Separate Sessions: Identify core issues (Education, Health, Finances).
4. MOU Drafting: Formalizing the agreement.
5. Court Filing: Turning the MOU into a binding court order.""",
              'https://nalsa.gov.in/services/mediation'
            ),
            const SizedBox(height: 16),
            _buildComplianceCard(
              context,
              'Safety & Well-being Checks',
              'Monitor for indicators of distress in children. Guidelines for ensuring stable environments in both homes.',
              LucideIcons.activity,
              Colors.red,
              """Guidelines for Monitoring Well-being:

1. Emotional Stability: Watch for sudden changes in behavior, regression (like bedwetting), or extreme separation anxiety.
2. Educational Progress: Stay in touch with teachers. A drop in grades or school refusal can be a sign of stress at home.
3. Physical Health: Ensure consistent nutrition, sleep hygiene, and medical care in both residences.
4. Social Integration: The child should maintain friendships and activities outside the family dispute.

Red Flags (Contact Authorities/Mediator if seen):
- Expressions of fear regarding handover.
- Unexplained bruises or physical marks.
- Intentional withholding of food or basic necessities as punishment.
- Exposure to domestic violence or substance abuse.""",
              'https://wcd.nic.in/'
            ),
            const SizedBox(height: 32),
            const Text('Legal Reference Library', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            _libraryItem(context, 'Custody of Minors in India: A Guide', 'Comprehensive guide on types of custody (Physical, Legal, Shared).', 'https://lawcommissionofindia.nic.in/'),
            _libraryItem(context, 'Shared Parenting: Landmark Judgments', 'Review of Supreme Court rulings on joint parenting.', 'https://main.sci.gov.in/'),
            _libraryItem(context, 'Visitation Rights: Do\'s and Don\'ts', 'A handbook for non-custodial parents on handover etiquette.', 'https://districts.ecourts.gov.in/'),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceCard(BuildContext context, String title, String desc, IconData icon, Color color, String fullContent, String url) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)?.locale.languageCode == 'hi' 
                ? 'भारत में बाल हिरासत से संबंधित प्रमुख प्रावधान। पारिवारिक न्यायालयों द्वारा उपयोग किए जाने वाले "बच्चे के कल्याण" सिद्धांत के बारे में जानें।'
                : desc,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openGuide(context, title, fullContent, url),
              icon: const Icon(LucideIcons.bookOpen, size: 16),
              label: Text(AppLocalizations.of(context)?.locale.languageCode == 'hi' ? 'पूरा गाइड पढ़ें' : 'READ FULL GUIDE'),
              style: TextButton.styleFrom(foregroundColor: color),
            ),
          )
        ],
      ),
    );
  }

  Widget _libraryItem(BuildContext context, String title, String summary, String url) {
    return ListTile(
      leading: const Icon(LucideIcons.fileText, color: Colors.blueGrey),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: () => _openGuide(context, title, summary, url),
    );
  }
}
