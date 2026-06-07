import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/advisor_service.dart';
import '../services/auth_service.dart';
import '../models/advisor.dart';
import '../models/user_profile.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _filterStatus = 'pending'; // 'pending' or 'under_review'

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Admin Console', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          _buildFilterChip('Pending', 'pending'),
          _buildFilterChip('Reviewing', 'under_review'),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: firestore.streamUserProfile(auth.currentUserId ?? ''),
        builder: (context, userSnap) {
          final adminUser = userSnap.data;
          
          if (adminUser == null) return const Center(child: CircularProgressIndicator());

          // SECURITY: Only users approved in Firebase Console (isAdmin: true) can see this screen
          if (adminUser.isAdmin != true) {
            return const Scaffold(
              body: Center(
                child: Text('Access Denied: You are not authorized to view the Admin Console.', 
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            );
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: AdvisorService.streamAllAdvisors(),
            builder: (context, advisorSnap) {
              if (advisorSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              final advisorsData = advisorSnap.data ?? [];
              final pendingAdvisors = advisorsData
                  .map((m) => Advisor.fromMap(m, m['_id'] ?? ''))
                  .where((a) => _filterStatus == 'pending' ? !a.isVerified : a.verificationStatus == _filterStatus)
                  .toList();
                  
                  if (pendingAdvisors.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCircle2, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('All clear! No $_filterStatus applications.', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: pendingAdvisors.length,
                    itemBuilder: (context, index) {
                      final advisor = pendingAdvisors[index];
                      final isBeingReviewed = advisor.verificationStatus == 'under_review';
                      final isReviewedByMe = advisor.reviewedBy == adminUser.uid;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
                          border: Border.all(color: isBeingReviewed ? Colors.orange.shade200 : Colors.grey.shade100),
                        ),
                        child: ExpansionTile(
                          shape: const RoundedRectangleBorder(side: BorderSide.none),
                          collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue.shade50,
                            backgroundImage: advisor.profileImageUrl != null ? NetworkImage(advisor.profileImageUrl!) : null,
                            child: advisor.profileImageUrl == null ? Icon(LucideIcons.user, color: Colors.blue.shade700) : null,
                          ),
                          title: Row(
                            children: [
                              Text(advisor.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              if (isBeingReviewed) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    isReviewedByMe ? 'YOU ARE REVIEWING' : 'BEING REVIEWED BY ${advisor.reviewerName?.toUpperCase()}',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.orange.shade700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${advisor.category} • Exp: ${advisor.experience}y • ${advisor.city}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 16),
                                  _buildInfoRow('Registration', advisor.barRegistrationNumber ?? advisor.certificationNumber ?? "N/A"),
                                  _buildInfoRow('Specialization', advisor.specialization),
                                  _buildInfoRow('Applied At', advisor.appliedAt?.toString().split('.')[0] ?? "N/A"),
                                  const SizedBox(height: 24),
                                  
                                  if (!isBeingReviewed)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => AdvisorService.verifyAdvisor(advisor.id),
                                        icon: const Icon(LucideIcons.eye, size: 16),
                                        label: const Text('APPROVE & VERIFY'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.all(16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),

                                  if (isBeingReviewed)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => AdvisorService.verifyAdvisor(advisor.id),
                                            icon: const Icon(LucideIcons.check, size: 16),
                                            label: const Text('APPROVE'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green.shade700,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => firestore.updateAdvisorStatus(advisor.id, 'rejected', false, adminUser.uid, adminUser.fullName),
                                            icon: const Icon(LucideIcons.x, size: 16),
                                            label: const Text('REJECT'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red.shade700,
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              side: BorderSide(color: Colors.red.shade100),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
    bool selected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        selected: selected,
        onSelected: (val) {
          if (val) setState(() => _filterStatus = status);
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.blue.shade50,
      ),
    );
  }

  void _showStaffManagement(BuildContext context) {
    final searchController = TextEditingController();
    List<UserProfile> results = [];
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Staff Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('Search users by email to grant admin access', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Enter email...',
                  prefixIcon: const Icon(LucideIcons.search),
                  suffixIcon: isSearching ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (val) async {
                  if (val.length < 3) {
                    setModalState(() => results = []);
                    return;
                  }
                  setModalState(() => isSearching = true);
                  final firestore = Provider.of<FirestoreService>(context, listen: false);
                  final list = await firestore.searchUserProfiles(val.toLowerCase());
                  setModalState(() {
                    results = list;
                    isSearching = false;
                  });
                },
              ),
              const SizedBox(height: 24),
              Expanded(
                child: results.isEmpty 
                  ? Center(child: Text(searchController.text.isEmpty ? 'Start typing an email...' : 'No users found', style: const TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, idx) {
                        final user = results[idx];
                        return ListTile(
                          leading: CircleAvatar(backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null),
                          title: Text(user.fullName),
                          subtitle: Text(user.email),
                          trailing: Switch(
                            value: user.isAdmin,
                            onChanged: (val) async {
                              final firestore = Provider.of<FirestoreService>(context, listen: false);
                              await firestore.updateAdminStatus(user.uid, val);
                              // Update local state
                              setModalState(() {
                                final index = results.indexWhere((u) => u.uid == user.uid);
                                if (index != -1) {
                                  results[index] = user.copyWith(isAdmin: val);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
