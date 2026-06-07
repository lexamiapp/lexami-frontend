import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/user_connection.dart';

class UserDetailScreen extends StatelessWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Member Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: FutureBuilder<UserProfile?>(
        future: firestore.getUserProfile(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('User profile not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildHeader(profile),
                const SizedBox(height: 32),
                _buildInfoSection(profile),
                const SizedBox(height: 32),
                if (auth.currentUserId != profile.uid)
                  _buildActions(context, auth, firestore, profile),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: profile.photoUrl != null ? NetworkImage(profile.photoUrl!) : null,
            child: profile.photoUrl == null 
              ? Text(profile.displayName[0], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white))
              : null,
          ),
          const SizedBox(height: 20),
          Text(
            profile.displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            profile.isVerifiedAdvisor ? 'VERIFIED ADVISOR' : 'COMMUNITY MEMBER',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.6), letterSpacing: 1),
          ),
          if (profile.useAliasInCommunity)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shield, size: 10, color: Colors.tealAccent),
                  SizedBox(width: 8),
                  Text('PRIVATE ALIAS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(UserProfile profile) {
    return Column(
      children: [
        _buildSectionCard('Legal Context', LucideIcons.scale, Colors.purple, [
          _buildDetailRow('Dispute Nature', profile.disputeNature),
          _buildDetailRow('Relationship', profile.relationshipWithOtherParty),
        ]),
        const SizedBox(height: 16),
        _buildSectionCard('Identity', LucideIcons.user, Colors.blue, [
          _buildDetailRow('Gender', profile.gender),
          _buildDetailRow('Location', '${profile.city}, ${profile.state}'),
          _buildDetailRow('Marital Status', profile.maritalStatus),
        ]),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 12),
              Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, AuthService auth, FirestoreService firestore, UserProfile profile) {
    return Row(
      children: [
        Expanded(
          child: StreamBuilder<ConnectionStatus?>(
            stream: firestore.streamConnectionStatus(auth.currentUserId!, profile.uid),
            builder: (context, statusSnap) {
              final status = statusSnap.data;
              return ElevatedButton.icon(
                onPressed: status != null ? null : () {
                  firestore.sendFriendRequest(auth.currentUserId!, profile.uid);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Friend request sent!')));
                },
                icon: Icon(
                  status == ConnectionStatus.accepted ? LucideIcons.users : (status == ConnectionStatus.pending ? LucideIcons.clock : LucideIcons.userPlus),
                  size: 18
                ),
                label: Text(status == ConnectionStatus.accepted ? 'FRIENDS' : (status == ConnectionStatus.pending ? 'REQUESTED' : 'CONNECT')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == ConnectionStatus.accepted ? Colors.green : (status == ConnectionStatus.pending ? Colors.orange : Colors.blue.shade600),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
            }
          ),
        ),
        const SizedBox(width: 12),
        // Admin-only action: Promote/Demote
        StreamBuilder<UserProfile?>(
          stream: firestore.streamUserProfile(auth.currentUserId!),
          builder: (context, currentAdminSnap) {
            final currentUser = currentAdminSnap.data;
            if (currentUser != null && currentUser.isAdmin) {
              return Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final newStatus = !profile.isAdmin;
                    firestore.updateAdminStatus(profile.uid, newStatus);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(newStatus ? 'Admin rights granted!' : 'Admin rights revoked.')),
                    );
                  },
                  icon: Icon(profile.isAdmin ? LucideIcons.shieldOff : LucideIcons.shieldCheck, size: 18),
                  label: Text(profile.isAdmin ? 'REVOKE ADMIN' : 'MAKE ADMIN'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: profile.isAdmin ? Colors.red : Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: profile.isAdmin ? Colors.red.shade200 : Colors.indigo.shade200),
                  ),
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ],
    );
  }
}
