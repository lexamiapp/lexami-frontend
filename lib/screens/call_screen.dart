import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../models/advisor.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final firestore = Provider.of<FirestoreService>(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Consult Advisors', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: auth.currentUserId == null
        ? const Center(child: Text('Please login to use calls'))
        : StreamBuilder<UserProfile?>(
            stream: firestore.streamUserProfile(auth.currentUserId!),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final balance = profile?.walletBalance ?? 0.0;

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildWalletCard(context, balance),
                      const SizedBox(height: 32),
                      _buildLiveAdvisorsSection(context, firestore, balance),
                      const SizedBox(height: 24),
                      _buildInfoCard(),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildWalletCard(BuildContext context, double balance) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF0F766E)], // Emerald to Teal
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consult Advisory',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Per-minute consultation with verified lawyers',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'WALLET BALANCE',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${balance.toInt()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/home/wallet'),
              icon: const Icon(LucideIcons.plus, size: 16, color: Colors.black),
              label: const Text('MANAGE WALLET'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107), // Amber
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveAdvisorsSection(BuildContext context, FirestoreService firestore, double balance) {
    return StreamBuilder<List<Advisor>>(
      stream: firestore.getAdvisorsStream(),
      builder: (context, snapshot) {
        final allLive = (snapshot.data ?? []).where((a) => a.isOnline).toList();
        
        final legalAdvisory = allLive.where((a) => a.category == 'Advocate' || a.category == 'Retired Judge/Lawyer').toList();
        final counselors = allLive.where((a) => a.category == 'Counselor').toList();

        if (allLive.isEmpty) return _buildEmptyState();

        return Column(
          children: [
            if (legalAdvisory.isNotEmpty) ...[
              _buildSectionHeader('LEGAL ADVISORY'),
              const SizedBox(height: 16),
              ...legalAdvisory.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAdvisorCallCard(context, a, balance),
              )),
            ],
            if (counselors.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionHeader('COUNSELORS'),
              const SizedBox(height: 16),
              ...counselors.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAdvisorCallCard(context, a, balance),
              )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
          child: const Row(
            children: [
              Icon(Icons.circle, size: 8, color: Colors.red),
              SizedBox(width: 4),
              Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisorCallCard(BuildContext context, Advisor advisor, double balance) {
    final canAfford = balance >= (advisor.pricePerMin * 5); // Minimum 5 mins

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blue.shade50,
            backgroundImage: advisor.profileImageUrl != null ? NetworkImage(advisor.profileImageUrl!) : null,
            child: advisor.profileImageUrl == null ? Text(advisor.name[0], style: const TextStyle(fontWeight: FontWeight.bold)) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(advisor.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(advisor.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 4),
                Text('₹${advisor.pricePerMin.toInt()}/min', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (!canAfford) {
                _showLowBalanceDialog(context);
              } else {
                // TODO: Start Call Logic
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting Secure Call...')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? Colors.blueGrey.shade900 : Colors.grey.shade300,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.phone, size: 16),
                SizedBox(width: 8),
                Text('CALL'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLowBalanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Low Balance'),
        content: const Text('You need at least 5 minutes worth of balance to start a call.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/home/wallet');
            },
            child: const Text('RECHARGE'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.phoneOff, size: 48, color: Colors.grey),
          const SizedBox(height: 24),
          const Text('No Advisors Online', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Expert advisors will appear here when they are online.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.shieldCheck, size: 16, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SAFE & SECURE CONSULTATIONS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue.shade900, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your calls are end-to-end encrypted. Billing is calculated automatically per minute and deducted from your wallet.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue.shade800, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
