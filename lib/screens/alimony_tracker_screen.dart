import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/alimony_record.dart';
import '../services/gemini_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AlimonyTrackerScreen extends StatefulWidget {
  const AlimonyTrackerScreen({super.key});

  @override
  State<AlimonyTrackerScreen> createState() => _AlimonyTrackerScreenState();
}

class _AlimonyTrackerScreenState extends State<AlimonyTrackerScreen> {
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();
  final _spouseIncomeController = TextEditingController();
  String _type = 'paid';
  bool _isAuditing = false;

  void _showAddEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Alimony Record', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'paid', label: Text('Paid'), icon: Icon(LucideIcons.trendingDown)),
                    ButtonSegment(value: 'received', label: Text('Received'), icon: Icon(LucideIcons.trendingUp)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (val) => setDialogState(() => _type = val.first),
                ),
                const SizedBox(height: 16),
                TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'Amount (₹)'), keyboardType: TextInputType.number),
                TextField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category (e.g. Monthly)')),
                TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note (Optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final auth = Provider.of<AuthService>(context, listen: false);
                final firestore = Provider.of<FirestoreService>(context, listen: false);
                
                if (auth.currentUserId != null && _amountController.text.isNotEmpty) {
                  await firestore.addAlimonyRecord(AlimonyRecord(
                    id: '',
                    userId: auth.currentUserId!,
                    type: _type,
                    amount: double.parse(_amountController.text),
                    category: _categoryController.text.isEmpty ? 'General' : _categoryController.text,
                    date: DateTime.now(),
                    note: _noteController.text,
                  ));
                }
                Navigator.pop(context);
                _amountController.clear();
                _categoryController.clear();
                _noteController.clear();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAuditWithLatestRecords(FirestoreService firestore, String userId) async {
    setState(() => _isAuditing = true);
    try {
      final records = await firestore.getAlimonyRecordsOnce(userId);
      if (records.isEmpty) {
        setState(() => _isAuditing = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No alimony records found to audit.')));
        return;
      }
      await _runAiAudit(records);
    } catch (e) {
      setState(() => _isAuditing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch records: $e')));
    }
  }

  Future<void> _runAiAudit(List<AlimonyRecord> records) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final gemini = Provider.of<GeminiService>(context, listen: false);

    // Get spouse income via dialog
    final spouseIncome = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spouse Current Income'),
        content: TextField(
          controller: _spouseIncomeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Monthly Income (₹)', prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, double.tryParse(_spouseIncomeController.text)), child: const Text('Start Audit')),
        ],
      ),
    );

    if (spouseIncome == null) return;

    setState(() => _isAuditing = true);

    try {
      final profile = await firestore.getUserProfile(auth.currentUserId!);
      final selfIncome = (profile?.annualIncome ?? 0) / 12; // Monthly
      
      final auditResult = await gemini.suggestAlimonyAdjustment(records, selfIncome, spouseIncome);
      
      if (mounted) {
        setState(() => _isAuditing = false);
        _showAuditResult(auditResult);
      }
    } catch (e) {
      if (mounted) setState(() => _isAuditing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Audit failed: $e')));
    }
  }

  void _showAuditResult(String result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(LucideIcons.brain, color: Colors.green), SizedBox(width: 12), Text('AI Alimony Audit')]),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: MarkdownBody(data: result))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT'))],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        title: const Text('Alimony Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (auth.currentUserId != null)
            IconButton(
              onPressed: _isAuditing ? null : () => _runAuditWithLatestRecords(firestore, auth.currentUserId!),
              icon: _isAuditing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.activity, color: Colors.green),
              tooltip: 'AI Adjustment Audit',
            ),
        ],
      ),
      body: auth.currentUserId == null 
        ? const Center(child: Text('Please login to track alimony'))
        : StreamBuilder<List<AlimonyRecord>>(
            stream: firestore.streamAlimonyRecords(auth.currentUserId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final records = snapshot.data ?? [];
              
              double totalPaid = 0;
              double totalReceived = 0;
              for (var r in records) {
                if (r.type == 'paid') {
                  totalPaid += r.amount;
                } else {
                  totalReceived += r.amount;
                }
              }

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildMetricCards(totalPaid, totalReceived),
                      const SizedBox(height: 24),
                      _buildActionRow(records),
                      const SizedBox(height: 24),
                      if (records.isEmpty) 
                        const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No records found. Start adding your transactions!')))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: records.length,
                          itemBuilder: (context, index) => _buildRecordCard(records[index]),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }



  Widget _buildRecordCard(AlimonyRecord r) {
    bool isPaid = r.type == 'paid';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPaid ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPaid ? LucideIcons.trendingDown : LucideIcons.trendingUp,
              color: isPaid ? Colors.red : Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(r.date.toString().split(' ')[0], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${isPaid ? '-' : '+'}₹${r.amount.toInt()}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: isPaid ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1EA362), // Green
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1EA362).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Alimony Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Track payments and receipts for court transparency.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Icon(LucideIcons.dollarSign, size: 60, color: Colors.white.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(double paid, double received) {
    double net = received - paid;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Total Paid',
                '₹${paid.toInt()}',
                const Color(0xFFD32F2F), // Red
                LucideIcons.trendingDown,
                Colors.red.shade50,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _metricCard(
                'Total Received',
                '₹${received.toInt()}',
                const Color(0xFF1EA362), // Green
                LucideIcons.trendingUp,
                Colors.green.shade50,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _metricCard(
          'Net Balance',
          '${net < 0 ? '-' : '+'}₹${net.abs().toInt()}',
          net < 0 ? Colors.red.shade700 : Colors.green.shade700,
          null,
          Colors.transparent,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _metricCard(
    String label,
    String value,
    Color textColor,
    IconData? icon,
    Color iconBgColor, {
    bool fullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.2,
                ),
              ),
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 14, color: textColor),
                ),
            ],
          ),
          SizedBox(height: fullWidth ? 10 : 20),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(List<AlimonyRecord> records) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
           BoxShadow(color: Colors.grey.shade50, blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: records.isEmpty || _isAuditing ? null : () => _runAiAudit(records),
                  icon: const Icon(LucideIcons.brain, size: 16),
                  label: const Text('AI AUDIT & ADJUST'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueGrey.shade600,
                    side: BorderSide(color: Colors.grey.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    iconColor: Colors.blueGrey.shade400,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddEntryDialog,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Add Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1EA362),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
