import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/gemini_service.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/child_profile.dart';
import '../../utils/app_localizations.dart';

class ParentingPlanScreen extends StatefulWidget {
  const ParentingPlanScreen({super.key});

  @override
  State<ParentingPlanScreen> createState() => _ParentingPlanScreenState();
}

class _ParentingPlanScreenState extends State<ParentingPlanScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Selection
  CaseChildProfile? _selectedProfile;
  List<CaseChildProfile> _availableProfiles = [];
  bool _isLoadingProfiles = true;

  // Plan Data
  String _physicalCustody = 'Primary Physical Custody';
  String _eduAuthority = 'Joint';
  String _medAuthority = 'Joint';
  String _relAuthority = 'Joint';
  
  // AI Form Controllers (Defaults from profile if selected)
  final _childAgeController = TextEditingController();
  final _distanceController = TextEditingController();
  final _workScheduleController = TextEditingController();
  String _conflictLevel = 'Low (Amicable)';
  
  bool _isGenerating = false;
  String? _aiSuggestion;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProfiles();
  }
  
  Future<void> _loadProfiles() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    final uid = auth.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingProfiles = false);
      return;
    }

    // Timeout fallback so spinner never hangs forever
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoadingProfiles) {
        setState(() => _isLoadingProfiles = false);
      }
    });

    firestore.streamChildProfiles(uid).listen(
      (profiles) {
        if (mounted) {
          setState(() {
            _availableProfiles = profiles;
            _isLoadingProfiles = false;
            if (profiles.isNotEmpty && _selectedProfile == null) {
              _onProfileSelected(profiles.first);
            }
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoadingProfiles = false);
      },
    );
  }

  void _onProfileSelected(CaseChildProfile profile) {
    setState(() {
      _selectedProfile = profile;
      _childAgeController.text = profile.dob; // Or calculate age
      _distanceController.text = '${profile.distanceBetweenHomes.round()} km';
      _workScheduleController.text = 'A: ${profile.parentAWorkHours}, B: ${profile.parentBWorkHours}';
      _physicalCustody = profile.currentLivingArrangement == 'Split / Shared' ? 'Shared Parenting' : 'Primary Physical Custody';
      
      // Load existing plan if any
      if (profile.parentingPlan != null) {
        _aiSuggestion = profile.parentingPlan?['aiSuggestion'];
      }
    });
  }

  @override
  void dispose() {
    _childAgeController.dispose();
    _distanceController.dispose();
    _workScheduleController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateAiPlan() async {
    if (_childAgeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter child details')));
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      final service = Provider.of<GeminiService>(context, listen: false);
      final result = await service.generateParentingPlan(
        childAge: _childAgeController.text,
        distance: _distanceController.text,
        workSchedule: _workScheduleController.text,
        conflictLevel: _conflictLevel,
      );
      
      if (mounted) {
        setState(() {
          _aiSuggestion = result;
          _isGenerating = false;
        });

        // Save plan to profile
        if (_selectedProfile != null) {
          final auth = Provider.of<AuthService>(context, listen: false);
          final firestore = Provider.of<FirestoreService>(context, listen: false);
          final updatedProfile = CaseChildProfile.fromMap({
            ..._selectedProfile!.toMap(),
            'parentingPlan': {
              'aiSuggestion': result,
              'generatedAt': DateTime.now().toIso8601String(),
            }
          });
          await firestore.saveChildProfile(auth.currentUserId!, updatedProfile);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Error: $e')));
      }
    }
  }

  Future<void> _exportPdf() async {
    if (_aiSuggestion == null) return;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('Parenting Plan & Visitation Schedule')),
              pw.SizedBox(height: 10),
              pw.Text('Child: ${_selectedProfile?.name ?? "N/A"}'),
              pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
              pw.Divider(),
              pw.Text('I. CUSTODY STRUCTURE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Physical Custody: $_physicalCustody'),
              pw.Text('Educational Authority: $_eduAuthority'),
              pw.Text('Medical Authority: $_medAuthority'),
              pw.SizedBox(height: 20),
              pw.Text('II. VISITATION & PARENTING GUIDELINES (AI Generated)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_aiSuggestion!.replaceAll('#', '').replaceAll('*', '')),
              pw.SizedBox(height: 40),
              pw.Divider(),
              pw.Text('Signatures:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 50),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('____________________\nParent A / Petitioner'),
                  pw.Text('____________________\nParent B / Respondent'),
                ]
              )
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('parenting_plan_builder') ?? 'Parenting Plan Builder'),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.teal.shade100,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Custody'),
            Tab(text: 'AI Visitation'),
            Tab(text: 'Financial'),
            Tab(text: 'Review'),
          ],
        ),
      ),
      body: _isLoadingProfiles 
          ? const Center(child: CircularProgressIndicator())
          : _availableProfiles.isEmpty 
              ? _buildNoProfileState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustodyTab(),
                    _buildVisitationTab(),
                    _buildFinancialTab(),
                    _buildReviewTab(),
                  ],
                ),
    );
  }

  Widget _buildNoProfileState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.baby, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No Child Profile Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Please complete Step 1 first.'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back to Step 1'),
          )
        ],
      ),
    );
  }

  Widget _buildCustodyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _profileSelectorHeader(),
        _sectionHeader('Physical Custody'),
        _optionTile('Primary Physical Custody', 'Child lives with one parent, visits the other.', _physicalCustody == 'Primary Physical Custody', (val) => setState(() => _physicalCustody = val)),
        _optionTile('Shared Parenting', 'Child splits time roughly equally (e.g., 50/50, 60/40).', _physicalCustody == 'Shared Parenting', (val) => setState(() => _physicalCustody = val)),
        _optionTile('Bird\'s Nest', 'Child stays in one home; parents rotate in/out.', _physicalCustody == 'Bird\'s Nest', (val) => setState(() => _physicalCustody = val)),
        const SizedBox(height: 24),
        _sectionHeader('Legal Custody (Authority)'),
        _dropdownTile('Education (Schooling Decisions)', ['Joint', 'Mother', 'Father'], _eduAuthority, (val) => setState(() => _eduAuthority = val!)),
        _dropdownTile('Healthcare (Medical Decisions)', ['Joint', 'Mother', 'Father'], _medAuthority, (val) => setState(() => _medAuthority = val!)),
        _dropdownTile('Religious Upbringing', ['Joint', 'Mother', 'Father'], _relAuthority, (val) => setState(() => _relAuthority = val!)),
      ],
    );
  }

  Widget _buildVisitationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _profileSelectorHeader(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.sparkles, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('AI Co-Parenting Architect', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                  ],
                ),
                const SizedBox(height: 20),
                
                TextField(
                  controller: _childAgeController,
                  decoration: const InputDecoration(labelText: 'Child Context', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: _distanceController,
                  decoration: const InputDecoration(labelText: 'Distance Between Homes', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 12),
                
                DropdownButtonFormField<String>(
                  initialValue: _conflictLevel,
                  decoration: const InputDecoration(labelText: 'Current Conflict Level', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                  items: ['Low (Amicable)', 'Medium (Occasional)', 'High (Hostile)'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                  onChanged: (val) => setState(() => _conflictLevel = val!),
                ),
                const SizedBox(height: 20),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateAiPlan,
                    icon: _isGenerating 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.wand2),
                    label: Text(_isGenerating ? 'Analyzing...' : 'Generate AI Suggestion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_aiSuggestion != null) ...[
            const SizedBox(height: 24),
            const Text('Suggested Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: MarkdownBody(data: _aiSuggestion!),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFinancialTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _profileSelectorHeader(),
        _sectionHeader('Financial Responsibilities'),
        const Text('Specify how child-related expenses will be shared:', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        _financialRow('School Fees & Tuition'),
        _financialRow('Medical & Health Insurance'),
        _financialRow('Extra-Curricular Activities'),
        _financialRow('Clothing & Daily Essentials'),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.shade50, border: Border.all(color: Colors.amber), borderRadius: BorderRadius.circular(8)),
          child: const Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.amber, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Note: Financial agreements here should align with any Alimony/Maintenance orders from the court.', style: TextStyle(fontSize: 11))),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildReviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.fileCheck, size: 64, color: Colors.teal),
          const SizedBox(height: 16),
          Text('Parenting Plan for ${_selectedProfile?.name ?? "Child"}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Ready to generate your court-ready PDF document.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          
          _reviewItem('Physical Custody', _physicalCustody),
          _reviewItem('Legal Decision Power', 'Joint (Education, Health, Religion)'),
          _reviewItem('AI visitation Plan', _aiSuggestion != null ? 'Generated' : 'Not Started'),
          
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _aiSuggestion == null ? null : _exportPdf,
            icon: const Icon(LucideIcons.download),
            label: const Text('Export Court-Ready PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          if (_aiSuggestion == null)
            const Padding(
              padding: EdgeInsets.only(top: 12.0),
              child: Text('Please generate AI Visitation plan first.', style: TextStyle(color: Colors.red, fontSize: 12)),
            )
        ],
      ),
    );
  }

  Widget _profileSelectorHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELECT CHILD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: Colors.teal.shade200), borderRadius: BorderRadius.circular(8), color: Colors.teal.shade50),
            child: DropdownButton<CaseChildProfile>(
              value: _selectedProfile,
              isExpanded: true,
              underline: const SizedBox(),
              items: _availableProfiles.map((p) => DropdownMenuItem(value: p, child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              onChanged: (val) => _onProfileSelected(val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _financialRow(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Wrap(
            spacing: 8,
            children: [
              _choiceChip('50/50'),
              _choiceChip('A Pays'),
              _choiceChip('B Pays'),
            ],
          )
        ],
      ),
    );
  }

  Widget _choiceChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  Widget _optionTile(String title, String subtitle, bool selected, Function(String) onSelect) {
    return Card(
      elevation: 0,
      color: selected ? Colors.teal.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? Colors.teal : Colors.grey.shade300),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.teal.shade900 : Colors.black)),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(LucideIcons.checkCircle, color: Colors.teal) : const Icon(LucideIcons.circle, color: Colors.grey),
        onTap: () => onSelect(title),
      ),
    );
  }

  Widget _dropdownTile(String title, List<String> options, String currentVal, Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: currentVal,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
