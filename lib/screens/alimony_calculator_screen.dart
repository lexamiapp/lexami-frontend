import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/analysis_history.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../widgets/shimmer_loader.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../widgets/evidence_selector.dart';
import '../models/legal_case.dart';


class AlimonyCalculatorScreen extends StatefulWidget {
  const AlimonyCalculatorScreen({super.key});

  @override
  State<AlimonyCalculatorScreen> createState() => _AlimonyCalculatorScreenState();
}

class _AlimonyCalculatorScreenState extends State<AlimonyCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Inputs
  String _mode = 'seeking'; // 'seeking' or 'giving'
  String _gender = 'female';
  double _myIncome = 50000;
  double _spouseIncome = 80000;
  int _marriageYears = 5;
  int _childrenCount = 0;
  final _locationController = TextEditingController(text: 'Delhi');

  bool _isCalculating = false;
  String? _aiStrategy;
  final List<PlatformFile> _attachedFiles = [];
  bool _isPickingFile = false;
  String? _translatedResult;
  bool _isTranslating = false;
  String? _selectedLanguageCode;
  List<Map<String, dynamic>> _selectedVaultEvidence = [];
  
  // Additional Context
  final _additionalContextController = TextEditingController();

  final Map<String, String> _indianLanguages = {
    'hi': 'Hindi (à¤¹à¤¿à¤¨à¥à¤¦à¥€)',
    'mr': 'Marathi (à¤®àª°àª¾àª à«€)',
    'gu': 'Gujarati (àª—à«àªœàª°àª¾àª¤à«€)',
    'bn': 'Bengali (à¦¬à¦¾à¦‚à¦²à¦¾)',
    'ta': 'Tamil (à®¤à®®à®¿à®´à¯)',
    'te': 'Telugu (à°¤à±†à°²à±à°—à±)',
    'kn': 'Kannada (àª•àª¨à«àª¨àª¡)',
    'ml': 'Malayalam (à´®à´²à´¯à´¾à´³à´‚)',
    'pa': 'Punjabi (à¨ªà©°à¨œà¨¾à¨¬à©€)',
    'en': 'English (English)',
  };

  @override
  void dispose() {
    _locationController.dispose();
    _additionalContextController.dispose();
    super.dispose();
  }

  // ... [Existing methods remain unchanged until _buildNumericInputs] ...

  Future<void> _calculateAlimony() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isCalculating = true;
      _aiStrategy = null;
    });

    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      final instructions = """
      You are a legal expert specializing in Indian Alimony laws (Rajnesh v. Neha guidelines). 
      Analyze the financial details provided and generate a "Personalized Alimony strategy".
      Focus on:
      1. Entitlement Analysis: Who is likely to receive alimony and why.
      2. Quantum Estimation: Approximate monthly range and one-time settlement potential.
      3. Strategic Advice: How to maximize or minimize the amount based on current facts.
      4. Statutory References: Cite Sec 125 CrPC, Sec 24 HMA, Sec 20 DV Act as applicable.
      5. Landmark Judgments: Specifically mention Rajnesh v. Neha.
      """;

      final input = """
      User Context: I am ${_mode == 'seeking' ? 'seeking' : 'giving'} alimony.
      User Gender: $_gender
      User Monthly Income: ₹${_myIncome.toInt()}
      Spouse Monthly Income: ₹${_spouseIncome.toInt()}
      Marriage Duration: $_marriageYears years
      Number of Children: $_childrenCount
      """;

      // Prepare attachments including Vault Evidence
      List<Map<String, dynamic>> attachments = [];
      
      // 1. Add manually attached files
      for (var file in _attachedFiles) {
        if (file.bytes != null) {
          attachments.add({
            'bytes': file.bytes!,
            'mimeType': _getMimeType(file.extension),
          });
        }
      }

      // 2. Add files from Evidence Vault
      for (var evidence in _selectedVaultEvidence) {
        if (evidence['url'] != null) {
          try {
            final response = await http.get(Uri.parse(evidence['url']));
            if (response.statusCode == 200) {
              attachments.add({
                'bytes': response.bodyBytes,
                'mimeType': _getMimeType(evidence['name']?.toString().split('.').last),
              });
            }
          } catch (e) {
            print('Error downloading evidence: $e');
          }
        }
      }

      // Call Gemini
      String response;
      if (attachments.isNotEmpty) {
        final prompt = "Analyze this alimony situation based on financial data and attached evidence (bank statements, salary slips, etc.). Details:\n$input";
        final parts = <Part>[
          TextPart("$instructions\n\n$prompt"),
          ...attachments.map((a) => DataPart(a['mimeType'], a['bytes'])),
        ];
        response = await gemini.generateWithFallback([Content.multi(parts)]);
      } else {
        response = await gemini.generateWithFallback([Content.text("$instructions\n\n$input")]);
      }
      
      setState(() {
        _aiStrategy = response;
        _isCalculating = false;
      });

      // Save to History for future reference
      if (auth.currentUserId != null && _aiStrategy != null) {
        await firestore.saveAnalysis(AnalysisHistory(
          id: '',
          userId: auth.currentUserId!,
          caseType: 'Alimony Prediction',
          summary: 'Income: ${_myIncome.toInt()}, Spouse: ${_spouseIncome.toInt()}, Duration: $_marriageYears years',
          result: _aiStrategy!,
          createdAt: DateTime.now(),
        ));
      }
    } catch (e) {
      setState(() => _isCalculating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _getMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/pdf';
    }
  }

  Future<void> _pickFiles() async {
    setState(() => _isPickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result != null) {
        setState(() => _attachedFiles.addAll(result.files));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Picker Error: $e')));
    } finally {
      setState(() => _isPickingFile = false);
    }
  }

  void _removeFile(int index) {
    setState(() => _attachedFiles.removeAt(index));
  }

  Future<void> _translateAnalysis(String langCode) async {
    if (_aiStrategy == null || langCode == 'en') {
      setState(() {
        _selectedLanguageCode = 'en';
        _translatedResult = null;
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _selectedLanguageCode = langCode;
      _translatedResult = null;
    });

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final translationId = await firestore.requestTranslation(_aiStrategy!);
      
      final subscription = firestore.streamTranslation(translationId).listen((doc) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('translated')) {
            final translatedMap = data['translated'] as Map<String, dynamic>?;
            if (translatedMap != null && translatedMap.containsKey(langCode)) {
              setState(() {
                _translatedResult = translatedMap[langCode];
                _isTranslating = false;
              });
            }
          }
        }
      });

      Future.delayed(const Duration(seconds: 15), () {
        if (_isTranslating) {
          subscription.cancel();
          setState(() => _isTranslating = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Translation timed out. Please try again.')));
        }
      });
    } catch (e) {
      setState(() => _isTranslating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Translation error: $e')));
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Language', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 400,
              child: ListView(
                children: _indianLanguages.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold)),
                    leading: Radio<String>(
                      value: entry.key,
                      groupValue: _selectedLanguageCode ?? 'en',
                      onChanged: (val) {
                        Navigator.pop(context);
                        _translateAnalysis(val!);
                      },
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _translateAnalysis(entry.key);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Alimony History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: StreamBuilder<List<AnalysisHistory>>(
                stream: firestore.streamAnalysisHistory(auth.currentUserId ?? ''),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final history = (snapshot.data ?? []).where((h) => h.caseType == 'Alimony Prediction').toList();
                  if (history.isEmpty) return const Center(child: Text('No history found'));
                  
                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final h = history[index];
                      return ListTile(
                        leading: const Icon(LucideIcons.calculator, color: Colors.orange),
                        title: Text(h.summary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(h.createdAt.toString().split(' ')[0]),
                        onTap: () {
                          setState(() {
                            _aiStrategy = h.result;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAlimonyPdf() async {
    if (_aiStrategy == null) return;

    final pdf = pw.Document();
    
    String cleanText = _aiStrategy!
        .replaceAll('###', '')
        .replaceAll('##', '')
        .replaceAll('#', '')
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('_', '')
        .trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Text('ALIMONY ESTIMATE REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            pw.SizedBox(height: 5),
            pw.Divider(),
            pw.SizedBox(height: 20),
          ],
        ),
        build: (pw.Context context) => [
          pw.Text('FINANCIAL PROFILE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Bullet(text: 'Mode: ${_mode == 'seeking' ? "Seeking Alimony" : "Giving Alimony"}'),
          pw.Bullet(text: 'User Income: INR ${_myIncome.toInt()}'),
          pw.Bullet(text: 'Spouse Income: INR ${_spouseIncome.toInt()}'),
          pw.Bullet(text: 'Marriage Duration: $_marriageYears years'),
          pw.Bullet(text: 'Number of Children: $_childrenCount'),
          pw.SizedBox(height: 30),
          pw.Text('STRATEGY & ANALYSIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Paragraph(
            text: cleanText,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
          ),
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Generated via LexAni AI Advisor', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Alimony_Estimate.pdf');
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Alimony_Estimate.pdf');
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Alimony Calculator', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModeSelection(),
                    const SizedBox(height: 32),
                    _buildGenderSelection(),
                    const SizedBox(height: 32),
                    _buildNumericInputs(),
                    const SizedBox(height: 32),
                    const Text('Financial Proof (Salary Slips, Statements, etc.)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    if (_attachedFiles.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        children: _attachedFiles.asMap().entries.map((entry) => Chip(
                          label: Text(entry.value.name, style: const TextStyle(fontSize: 11)),
                          onDeleted: () => _removeFile(entry.key),
                          backgroundColor: Colors.orange.shade50,
                          side: BorderSide.none,
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: _isPickingFile ? null : _pickFiles,
                      icon: const Icon(LucideIcons.paperclip, size: 16),
                      label: Text(_isPickingFile ? 'PICKING...' : 'ATTACH NEW PROOF'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                    const SizedBox(height: 24),
                    EvidenceSelector(
                      onSelectionChanged: (selected) {
                        setState(() {
                          _selectedVaultEvidence = selected;
                        });
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCalculating ? null : _calculateAlimony,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF97316), // Orange
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: _isCalculating 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('CALCULATE ESTIMATE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_isCalculating)
                      const SkeletonResult(),
                    if (_aiStrategy != null && !_isCalculating) _buildStrategySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316), // Orange
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(LucideIcons.calculator, color: Colors.white, size: 24),
              ),
              ElevatedButton.icon(
                onPressed: _showHistory,
                icon: const Icon(LucideIcons.history, size: 16),
                label: const Text('History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Strategies for Alimony on Thousands of real court judgements',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.info, size: 18, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Your Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Are you seeking or giving alimony? *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildSelectionCard(
          'I am seeking alimony',
          'I want to maximize the amount I receive',
          LucideIcons.trendingUp,
          _mode == 'seeking',
          () => setState(() => _mode = 'seeking'),
          Colors.green,
        ),
        const SizedBox(height: 16),
        _buildSelectionCard(
          'I am giving alimony',
          'I want to minimize the amount I pay',
          LucideIcons.trendingDown,
          _mode == 'giving',
          () => setState(() => _mode = 'giving'),
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSelectionCard(String title, String subtitle, IconData icon, bool selected, VoidCallback onTap, Color activeColor) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? activeColor : Colors.grey.shade200, width: 2),
          boxShadow: [if (selected) BoxShadow(color: activeColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? activeColor : Colors.grey.shade300, width: 2),
              ),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? activeColor : Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Icon(icon, color: activeColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Gender *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildGenderChip('Male', _gender == 'male', () => setState(() => _gender = 'male')),
            const SizedBox(width: 12),
            _buildGenderChip('Female', _gender == 'female', () => setState(() => _gender = 'female')),
            const SizedBox(width: 12),
            _buildGenderChip('Other', _gender == 'other', () => setState(() => _gender = 'other')),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderChip(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? Colors.blueGrey.shade900 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? Colors.blueGrey.shade900 : Colors.grey.shade200),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.blueGrey.shade700,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveBudgetToCase(double min, double max) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    
    if (auth.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to save budget.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Budget to Case'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<List<LegalCase>>(
            stream: firestore.streamUserCases(auth.currentUserId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No active cases found. Create a case from Home.'));
              
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final c = snapshot.data![index];
                  return ListTile(
                    leading: const Icon(LucideIcons.briefcase, color: Colors.blueGrey),
                    title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c.type),
                    trailing: const Icon(LucideIcons.chevronRight, size: 16),
                    onTap: () async {
                      await firestore.updateCaseBudget(c.id, max);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Budget updated for ${c.title}!')));
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        ],
      ),
    );
  }

  Widget _buildNumericInputs() {
    return Column(
      children: [
        _buildSliderInput('Your Monthly Income', _myIncome, 0, 500000, 'currency', (val) => setState(() => _myIncome = val)),
        const SizedBox(height: 24),
        _buildSliderInput('Spouse Monthly Income', _spouseIncome, 0, 500000, 'currency', (val) => setState(() => _spouseIncome = val)),
        const SizedBox(height: 24),
        _buildSliderInput('Marriage Duration', _marriageYears.toDouble(), 0, 50, 'years', (val) => setState(() => _marriageYears = val.toInt())),
        const SizedBox(height: 24),
        _buildSliderInput('Number of Children', _childrenCount.toDouble(), 0, 5, 'kids', (val) => setState(() => _childrenCount = val.toInt())),
        const SizedBox(height: 24),
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: 'Your City / State (For Legal Cost Estimate)',
            hintText: 'e.g. Mumbai, Delhi, Bangalore',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(LucideIcons.mapPin, color: Color(0xFFF97316)),
          ),
          onChanged: (val) => setState(() {}),
        ),
        const SizedBox(height: 32),
        _buildLegalBudgetCard(),
      ],
    );
  }

  Widget _buildLegalBudgetCard() {
    if (_locationController.text.isEmpty) return const SizedBox();

    final gemini = Provider.of<GeminiService>(context, listen: false);
    final budgetData = gemini.getLegalBudgetEstimate('Maintenance / Alimony', _locationController.text);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade800, Colors.deepOrange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.gavel, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Legal Cost of Litigation',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  budgetData['location'] ?? 'India',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ESTIMATED LEGAL BUDGET',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_rupee${budgetData['totalMin']} - $_rupee${budgetData['totalMax']}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.deepOrange.shade800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Avg. Timeline: ${budgetData['timelineMin']} - ${budgetData['timelineMax']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _showDetailedBudgetBreakdown(budgetData),
                      icon: Icon(LucideIcons.info, color: Colors.deepOrange.shade800),
                      tooltip: 'View Details',
                    ),
                    IconButton(
                      onPressed: () => _saveBudgetToCase(
                        (budgetData['totalMin'] as int).toDouble(), 
                        (budgetData['totalMax'] as int).toDouble()
                      ),
                      icon: Icon(LucideIcons.save, color: Colors.deepOrange.shade800),
                      tooltip: 'Save to Case',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            budgetData['warning'] ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  void _showDetailedBudgetBreakdown(Map<String, dynamic> budgetData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade800, Colors.deepOrange.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.calculator, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Litigation Cost Breakdown', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ...((budgetData['phases'] as List<dynamic>?) ?? []).map((phase) {
                    final items = (phase['items'] as List<dynamic>?) ?? [];
                    final phaseTotal = items.fold<int>(0, (sum, item) => sum + ((item as Map<String, dynamic>)['cost'] as int? ?? 0));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(phase['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('$_rupee$phaseTotal', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.deepOrange.shade800)),
                            ],
                          ),
                          const Divider(),
                          ...items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(item['item'] ?? '', style: const TextStyle(fontSize: 12)),
                                Text('$_rupee${item['cost']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(LucideIcons.bookOpen, size: 16, color: Colors.blue.shade800),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Source: ${budgetData['dataSource']}', style: TextStyle(fontSize: 11, color: Colors.blue.shade900))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _rupee = '₹';

  Widget _buildSliderInput(String label, double value, double min, double max, String unit, Function(double) onChanged) {
    final isCurrency = unit == 'currency';
    final displayValue = isCurrency
        ? '$_rupee${NumberFormat('#,##,###').format(value.toInt())}'
        : '${value.toInt()} $unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(displayValue, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFFF97316),
          inactiveColor: Colors.orange.shade50,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildStrategySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        Row(
          children: [
            const Icon(LucideIcons.lightbulb, color: Color(0xFFF97316)),
            const SizedBox(width: 12),
            const Expanded(child: Text('Personalized Strategy', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
            IconButton(
              onPressed: _showLanguageSelector,
              icon: const Icon(LucideIcons.languages, color: Color(0xFFF97316)),
              tooltip: 'Translate',
            ),
            IconButton(
              onPressed: _downloadAlimonyPdf,
              icon: const Icon(LucideIcons.download, color: Color(0xFFF97316)),
              tooltip: 'Download Report',
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_selectedLanguageCode != null && _selectedLanguageCode != 'en')
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Viewing in: ${_indianLanguages[_selectedLanguageCode]}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF97316)),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isTranslating)
                const Column(
                  children: [
                    ShimmerLoader(width: double.infinity, height: 20),
                    SizedBox(height: 8),
                    ShimmerLoader(width: double.infinity, height: 20),
                    SizedBox(height: 8),
                    ShimmerLoader(width: 200, height: 20),
                  ],
                )
              else
                MarkdownBody(
                  data: _selectedLanguageCode == 'en' || _selectedLanguageCode == null 
                    ? _aiStrategy! 
                    : (_translatedResult ?? _aiStrategy!),
                  onTapLink: (text, href, title) {
                    if (href == '/advisors') {
                      context.go('/advisors');
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange.shade900, height: 1.6),
                    strong: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange.shade900),
                    listBullet: TextStyle(color: Colors.orange.shade900, fontSize: 16),
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.go('/home/library'),
                icon: const Icon(LucideIcons.library, size: 16),
                label: const Text('SEARCH LEGAL LIBRARY'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
