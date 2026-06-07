import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../utils/app_localizations.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.currentUserId;

    if (userId == null) return const SizedBox();

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return Drawer(
      child: FutureBuilder<UserProfile?>(
        future: firestoreService.getUserProfile(userId),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          
          return Scrollbar(
            thumbVisibility: true,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF1E293B)),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  backgroundImage: (profile?.photoUrl != null) ? NetworkImage(profile!.photoUrl!) : null,
                  child: (profile?.photoUrl == null)
                      ? const Icon(Icons.person, color: Color(0xFF1E293B), size: 40)
                      : null,
                ),
                accountName: Text(profile?.fullName ?? 'LexAni User', style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(profile?.email ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: Text(AppLocalizations.of(context)?.translate('home') ?? 'Home'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/home');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.users),
                title: Text(AppLocalizations.of(context)?.translate('advisors') ?? 'Advisors'),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/advisors');
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.userPlus),
                title: const Text('Join as Advisory'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/home/register-advisor');
                },
              ),
              const Divider(),
              _buildDrawerItem(context, AppLocalizations.of(context)?.translate('analyze_case') ?? 'AI Case Analysis', LucideIcons.scale, '/home/ai-match'),
              _buildDrawerItem(context, AppLocalizations.of(context)?.translate('alimony_calc') ?? 'Alimony Calculator', LucideIcons.calculator, '/home/calculator'),
              _buildDrawerItem(context, AppLocalizations.of(context)?.translate('drafting_vault') ?? 'Drafting Vault', LucideIcons.fileText, '/home/generator'),
              _buildDrawerItem(context, AppLocalizations.of(context)?.translate('transcriber') ?? 'Evidence Transcriber', LucideIcons.mic, '/home/transcriber'),
              _buildDrawerItem(context, AppLocalizations.of(context)?.translate('evidence_vault') ?? 'Evidence Vault', LucideIcons.folderLock, '/home/vault'),
              _buildDrawerItem(context, 'Legal Library', LucideIcons.library, '/home/library'),
              _buildDrawerItem(context, AppLocalizations.of(context)?.translate('co_parenting') ?? 'Co-Parenting', LucideIcons.baby, '/home/custody'),
              _buildDrawerItem(context, AppLocalizations.of(context)?.translate('wallet') ?? 'My Wallet', LucideIcons.wallet, '/home/wallet'),
              const Divider(),
              if (profile?.isAdmin == true)
                ListTile(
                  leading: const Icon(LucideIcons.shieldCheck, color: Colors.blue),
                  title: const Text('Admin Dashboard', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/admin');
                  },
                ),
              ListTile(
                leading: Stack(
                  children: [
                    const Icon(LucideIcons.bell),
                  ],
                ),
                title: const Text('Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/notifications');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(LucideIcons.logOut, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await authService.signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
              if (kIsWeb) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(LucideIcons.downloadCloud, color: Colors.blue),
                  title: const Text('Download Android App', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse('/app-release.apk'));
                  },
                ),
              ],
            ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, String title, IconData icon, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
