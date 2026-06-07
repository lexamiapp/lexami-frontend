import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/legal_case.dart';
import 'case_detail_screen.dart';

class MyCasesScreen extends StatefulWidget {
  const MyCasesScreen({super.key});

  @override
  State<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends State<MyCasesScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = 'Divorce';

  final List<String> _caseTypes = [
    'Divorce',
    'Child Custody',
    'Alimony',
    'Property Dispute',
    'Maintenance',
    'Domestic Violence',
    'Others'
  ];

  bool _isSavingCase = false;

  void _showAddCaseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('New Legal Case', style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Case Details', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController, 
                  decoration: InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Property Dispute - XYZ Colony',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Type of Lawsuit',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _caseTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => _selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Initial Entry', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: 'Brief Description',
                    hintText: 'Summarize the legal context...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSavingCase ? null : () => Navigator.pop(dialogContext), 
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: _isSavingCase ? null : () async {
                if (_titleController.text.isEmpty || _descController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields.')),
                  );
                  return;
                }

                setDialogState(() => _isSavingCase = true);

                try {
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final firestore = Provider.of<FirestoreService>(context, listen: false);
                  
                  if (auth.currentUserId != null) {
                    final initialEntry = CaseTimelineEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      date: DateTime.now(),
                      description: _descController.text,
                      documents: [], // Initial documents could be added here if valid UI exists
                    );

                    await firestore.addCase(LegalCase(
                      id: '',
                      userId: auth.currentUserId!,
                      title: _titleController.text,
                      type: _selectedType,
                      status: 'Active',
                      createdAt: DateTime.now(),
                      timeline: [initialEntry],
                    ));

                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Case added successfully!')),
                      );
                      _titleController.clear();
                      _descController.clear();
                      _selectedType = 'Divorce';
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add case: $e')),
                  );
                } finally {
                  setDialogState(() => _isSavingCase = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSavingCase 
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Add Case', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final firestore = Provider.of<FirestoreService>(context);

    return Scaffold(
      drawer: const AppDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('My Cases', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: auth.currentUserId == null 
        ? const Center(child: Text('Please login to view cases'))
        : StreamBuilder<List<LegalCase>>(
            stream: firestore.streamUserCases(auth.currentUserId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final cases = snapshot.data ?? [];
              
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsRow(cases),
                    const SizedBox(height: 32),
                    if (cases.isEmpty)
                      _buildEmptyState()
                    else
                      ...cases.map((c) => _buildCaseCard(c)),
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCaseDialog,
        backgroundColor: Colors.blue.shade600,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text('Add Case', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildStatsRow(List<LegalCase> cases) {
    int active = cases.where((c) => c.status == 'Active').length;
    return Row(
      children: [
        Expanded(child: _buildCounterCard('ACTIVE', active.toString(), Colors.blue, LucideIcons.activity)),
        const SizedBox(width: 16),
        Expanded(child: _buildCounterCard('PENDING', '0', Colors.amber, LucideIcons.clock)),
        const SizedBox(width: 16),
        Expanded(child: _buildCounterCard('CLOSED', '0', Colors.green, LucideIcons.checkCircle)),
      ],
    );
  }

  IconData _getCaseIcon(String type) {
    switch (type) {
      case 'Divorce': return LucideIcons.scissors;
      case 'Child Custody': return LucideIcons.baby;
      case 'Alimony': return LucideIcons.banknote;
      case 'Property Dispute': return LucideIcons.home;
      case 'Maintenance': return LucideIcons.heartHandshake;
      case 'Domestic Violence': return LucideIcons.shieldAlert;
      default: return LucideIcons.fileText;
    }
  }

  Widget _buildCaseCard(LegalCase c) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CaseDetailScreen(legalCase: c))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Icon(_getCaseIcon(c.type), color: Colors.blue.shade600, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13)),
                        Text(c.type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(c.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.green.shade600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(c.latestDescription, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(LucideIcons.calendar, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 8),
                Text('Added: ${c.createdAt.toLocal().toString().split(' ')[0]}', style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterCard(String label, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                count,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(24)),
              child: Icon(LucideIcons.fileText, size: 40, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 24),
            Text(
              "You haven't added any cases yet.\nTap the button to get started.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade400, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
