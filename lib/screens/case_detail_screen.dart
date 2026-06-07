import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/firestore_service.dart';
import '../models/legal_case.dart';
import '../services/gemini_service.dart';
import 'case_chat_screen.dart';

class CaseDetailScreen extends StatefulWidget {
  final LegalCase legalCase;
  const CaseDetailScreen({super.key, required this.legalCase});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  // --- Controllers & Date State ---
  final _updateDescController = TextEditingController();
  final _docNameController = TextEditingController(); 
  DateTime _selectedDate = DateTime.now();
  DateTime? _nextHearingDate;
  DateTime? _documentDeadline;

  // --- AI Summary & Prediction State ---
  bool _isSummarizing = false;
  String? _aiSummary;
  bool _isPredicting = false;
  String? _predictionResult;
  bool _isFetchingPrecedents = false;
  bool _isScanning = false;

  // --- Budgeting State ---
  final _budgetController = TextEditingController();
  final _expenseTitleController = TextEditingController();
  final _expenseAmountController = TextEditingController();
  final String _selectedCategory = 'Advocate Fee';
  bool _isAnalyzingBudget = false;

  // --- Witness State ---
  final _witnessNameController = TextEditingController();
  final _witnessStatementController = TextEditingController();
  String _selectedWitnessRelation = 'Plaintiff Witness';
  bool _isAnalyzingWitness = false;

  @override
  void dispose() {
    _updateDescController.dispose();
    _docNameController.dispose();
    _budgetController.dispose();
    _expenseTitleController.dispose();
    _expenseAmountController.dispose();
    _witnessNameController.dispose();
    _witnessStatementController.dispose();
    super.dispose();
  }

  // --- UI Helpers ---

  Future<void> _smartScanDocument(Function setSheetState) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null) return;
      
      setSheetState(() => _isScanning = true);
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final extractedText = await gemini.parseDocumentImage(result.files.first.bytes!, result.files.first.extension ?? 'jpg');
      
      setSheetState(() {
        _updateDescController.text = extractedText;
        _isScanning = false;
      });
    } catch (e) {
      setSheetState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  void _showAddUpdateDialog() {
    _selectedDate = DateTime.now();
    _nextHearingDate = null;
    _documentDeadline = null;
    _updateDescController.clear();
    _docNameController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Case Update', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _isScanning ? null : () => _smartScanDocument(setSheetState),
                    icon: _isScanning ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.scanLine, size: 18),
                    label: Text(_isScanning ? 'SCANNING...' : 'SMART SCAN'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) setSheetState(() => _selectedDate = picked);
                },
                child: _buildPickerField('Date of Update', DateFormat('MMM dd, yyyy').format(_selectedDate), LucideIcons.calendar, Colors.blue),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _updateDescController,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Brief Description / Proceedings (or Scanned Content)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _nextHearingDate ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (picked != null) setSheetState(() => _nextHearingDate = picked);
                },
                child: _buildPickerField('Next Hearing (Optional)', _nextHearingDate != null ? DateFormat('MMM dd, yyyy').format(_nextHearingDate!) : 'Not Scheduled', LucideIcons.gavel, Colors.amber),
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _documentDeadline ?? DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (picked != null) setSheetState(() => _documentDeadline = picked);
                },
                child: _buildPickerField('Document Deadline (Optional)', _documentDeadline != null ? DateFormat('MMM dd, yyyy').format(_documentDeadline!) : 'None Set', LucideIcons.fileClock, Colors.deepPurple),
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_updateDescController.text.isEmpty) return;

                    final entry = CaseTimelineEntry(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      date: _selectedDate,
                      description: _updateDescController.text,
                      nextHearingDate: _nextHearingDate,
                      documentDeadline: _documentDeadline,
                      documents: _docNameController.text.isNotEmpty ? [{'name': _docNameController.text, 'uploadedAt': DateTime.now().toIso8601String()}] : [],
                    );

                    final firestore = Provider.of<FirestoreService>(context, listen: false);
                    await firestore.addCaseUpdate(widget.legalCase.id, entry);
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add Update', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddWitnessDialog(String caseId) {
    _witnessNameController.clear();
    _witnessStatementController.clear();
    _selectedWitnessRelation = 'Plaintiff Witness';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Record Witness Statement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _witnessNameController,
                decoration: InputDecoration(labelText: 'Witness Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedWitnessRelation,
                items: ['Plaintiff Witness', 'Defendant Witness', 'Neutral']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) => setSheetState(() => _selectedWitnessRelation = val!),
                decoration: InputDecoration(labelText: 'Relation to Case', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _witnessStatementController,
                maxLines: 5,
                decoration: InputDecoration(labelText: 'Detailed Statement', alignLabelWithHint: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_witnessNameController.text.isEmpty || _witnessStatementController.text.isEmpty) return;
                    
                    final witness = WitnessStatement(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _witnessNameController.text,
                      relation: _selectedWitnessRelation,
                      statement: _witnessStatementController.text,
                      date: DateTime.now(),
                    );

                    final firestore = Provider.of<FirestoreService>(context, listen: false);
                    await firestore.addWitnessStatement(caseId, witness);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('SAVE STATEMENT'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerField(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  // --- AI Logic Methods ---

  Future<void> _generateAiSummary(List<CaseTimelineEntry> timeline) async {
    if (timeline.isEmpty) return;
    setState(() { _isSummarizing = true; _aiSummary = null; });
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final summary = await gemini.summarizeCaseHistory(timeline);
      if (mounted) setState(() { _aiSummary = summary; _isSummarizing = false; });
    } catch (e) {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  Future<void> _analyzeBudgetWithAI(LegalCase liveCase) async {
    setState(() { _isAnalyzingBudget = true; });
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final analysis = await gemini.analyzeCaseBudget(liveCase.totalBudget, liveCase.expenses);
      if (mounted) {
        setState(() { _isAnalyzingBudget = false; });
        _showReportDialog('Financial Audit', analysis, LucideIcons.indianRupee, Colors.green);
      }
    } catch (e) {
      if (mounted) setState(() => _isAnalyzingBudget = false);
    }
  }

  Future<void> _predictOutcomeWithAI(LegalCase liveCase) async {
    setState(() { _isPredicting = true; });
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final result = await gemini.predictCaseOutcome(liveCase);
      if (mounted) {
        setState(() { _isPredicting = false; });
        _showReportDialog('Outcome Prediction', result, LucideIcons.trendingUp, Colors.blue);
      }
    } catch (e) {
      if (mounted) setState(() => _isPredicting = false);
    }
  }

  Future<void> _analyzeWitnessWithAI(String caseId, WitnessStatement witness) async {
    setState(() { _isAnalyzingWitness = true; });
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final analysis = await gemini.analyzeWitnessStatement(witness.statement, witness.name, witness.relation);
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      await firestore.updateWitnessAnalysis(caseId, witness.id, analysis);
      if (mounted) {
        setState(() { _isAnalyzingWitness = false; });
        _showReportDialog('Witness Profiling: ${witness.name}', analysis, LucideIcons.users, Colors.deepPurple);
      }
    } catch (e) {
      if (mounted) setState(() => _isAnalyzingWitness = false);
    }
  }

  Future<void> _fetchPrecedents(LegalCase liveCase) async {
    setState(() { _isFetchingPrecedents = true; });
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final result = await gemini.getLegalPrecedents(liveCase);
      if (mounted) {
        setState(() { _isFetchingPrecedents = false; });
        _showReportDialog('Landmark Precedents', result, LucideIcons.bookOpen, Colors.orange);
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingPrecedents = false);
    }
  }

  Future<void> _downloadWitnessExamPdf(WitnessStatement witness) async {
    if (witness.aiAnalysis == null) return;

    final pdf = pw.Document();
    
    String cleanText = witness.aiAnalysis!
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
            pw.Text('WITNESS CROSS-EXAMINATION PLAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            pw.SizedBox(height: 5),
            pw.Divider(),
            pw.SizedBox(height: 20),
          ],
        ),
        build: (pw.Context context) => [
          pw.Text('WITNESS PROFILE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 12),
          pw.Bullet(text: 'Name: ${witness.name}'),
          pw.Bullet(text: 'Relation: ${witness.relation}'),
          pw.Bullet(text: 'Statement Date: ${DateFormat('MMM dd, yyyy').format(witness.date)}'),
          pw.SizedBox(height: 24),
          
          pw.Text('ORIGINAL STATEMENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Text(witness.statement, style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.2)),
          ),
          pw.SizedBox(height: 24),

          pw.Text('AI ANALYSIS & STRATEGY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.Paragraph(
            text: cleanText,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4),
          ),
          
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Generated via LexAni AI Advisor', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Cross_Exam_${witness.name}.pdf');
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Cross_Exam_${witness.name}.pdf');
    }
  }

  void _showReportDialog(String title, String content, IconData icon, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Expanded(child: Text(title, style: const TextStyle(fontSize: 18)))]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: MarkdownBody(data: content)),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT'))],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  // --- Main Build ---

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context);
    return StreamBuilder<List<LegalCase>>(
      stream: firestore.streamUserCases(widget.legalCase.userId),
      builder: (context, snapshot) {
        LegalCase liveCase = widget.legalCase;
        if (snapshot.hasData) {
          try { liveCase = snapshot.data!.firstWhere((c) => c.id == widget.legalCase.id); } catch (e) {}
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(liveCase.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(liveCase.type, style: const TextStyle(fontSize: 12)),
            ]),
            backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black,
            actions: [
              IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CaseChatScreen(legalCase: liveCase))), icon: const Icon(LucideIcons.messagesSquare, size: 20)),
              IconButton(onPressed: () => _fetchPrecedents(liveCase), icon: _isFetchingPrecedents ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.bookOpen, size: 20)),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAiInsightSection(liveCase),
                const SizedBox(height: 16),
                _buildOutcomePredictionTrigger(liveCase),
                const SizedBox(height: 24),
                _buildBudgetingSection(liveCase),
                const SizedBox(height: 24),
                _buildWitnessSection(liveCase),
                const SizedBox(height: 32),
                
                const Text('CASE HISTORY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 16),
                
                if (liveCase.timeline.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No updates yet.')))
                else
                  ListView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    itemCount: liveCase.timeline.length,
                    itemBuilder: (context, index) {
                      final entry = liveCase.timeline[index];
                      return _buildTimelineItem(entry, liveCase, index == liveCase.timeline.length - 1);
                    },
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddUpdateDialog,
            backgroundColor: Colors.blue.shade900,
            icon: const Icon(LucideIcons.plus, color: Colors.white),
            label: const Text('Add Update', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        );
      },
    );
  }

  // --- Section Widgets ---

  Widget _buildAiInsightSection(LegalCase liveCase) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.indigo.shade800], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(LucideIcons.sparkles, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          const Text('AI CASE INSIGHTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          const Spacer(),
          if (_aiSummary == null && !_isSummarizing)
            TextButton(
              onPressed: () => _generateAiSummary(liveCase.timeline),
              style: TextButton.styleFrom(backgroundColor: Colors.white10),
              child: const Text('GENERATE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 16),
        if (_isSummarizing) const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (_aiSummary != null) MarkdownBody(data: _aiSummary!, styleSheet: MarkdownStyleSheet(p: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)))
        else const Text('Get a strategic executive summary of your entire case history using AI.', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }

  Widget _buildWitnessSection(LegalCase liveCase) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('WITNESS MANAGEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          IconButton(onPressed: () => _showAddWitnessDialog(liveCase.id), icon: const Icon(LucideIcons.userPlus, size: 18, color: Colors.blue)),
        ]),
        const SizedBox(height: 16),
        if (liveCase.witnesses.isEmpty)
          const Text('No witness statements recorded.', style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          ...liveCase.witnesses.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(LucideIcons.user, size: 16, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(child: InkWell(
                  onTap: () => _showReportDialog(w.name, w.aiAnalysis ?? 'AI Analysis not generated yet.', LucideIcons.users, Colors.deepPurple),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(w.relation, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                  ]),
                )),
                if (w.aiAnalysis == null)
                  IconButton(
                    onPressed: _isAnalyzingWitness ? null : () => _analyzeWitnessWithAI(liveCase.id, w),
                    icon: _isAnalyzingWitness ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.brain, size: 16, color: Colors.deepPurple),
                  )
                else
                  IconButton(
                    onPressed: () => _downloadWitnessExamPdf(w), 
                    icon: const Icon(LucideIcons.download, size: 16, color: Colors.green),
                    tooltip: 'Download Exam Plan',
                  ),
              ]),
            ),
          )),
      ]),
    );
  }

  Widget _buildOutcomePredictionTrigger(LegalCase liveCase) {
    return InkWell(
      onTap: _isPredicting ? null : () => _predictOutcomeWithAI(liveCase),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade100)),
        child: Row(children: [
          const Icon(LucideIcons.trendingUp, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CASE OUTCOME PREDICTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
            Text(_isPredicting ? 'Simulating...' : 'Predict likely resolution timeline.', style: const TextStyle(fontSize: 12)),
          ])),
          if (_isPredicting) const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else const Icon(LucideIcons.chevronRight, color: Colors.blue, size: 16),
        ]),
      ),
    );
  }

  Widget _buildBudgetingSection(LegalCase liveCase) {
    double progress = liveCase.totalBudget > 0 ? (liveCase.totalSpent / liveCase.totalBudget) : 0.0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('LEGAL BUDGETING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          IconButton(onPressed: () => _showDialogSetBudget(liveCase), icon: const Icon(LucideIcons.edit3, size: 18, color: Colors.blue)),
        ]),
        const SizedBox(height: 4),
        Text('₹${liveCase.totalSpent.toStringAsFixed(0)} / ₹${liveCase.totalBudget.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 8, backgroundColor: Colors.grey.shade100, color: progress > 0.9 ? Colors.red : Colors.green)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _showAddExpenseDialog(liveCase), child: const Text('ADD EXPENSE', style: TextStyle(fontSize: 10)))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(onPressed: _isAnalyzingBudget ? null : () => _analyzeBudgetWithAI(liveCase), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900), child: _isAnalyzingBudget ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('AI AUDIT', style: TextStyle(fontSize: 10, color: Colors.white)))),
        ]),
      ]),
    );
  }

  void _showDialogSetBudget(LegalCase liveCase) {
    _budgetController.text = liveCase.totalBudget.toString();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Set Budget'),
      content: TextField(controller: _budgetController, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '₹ ')),
      actions: [ElevatedButton(onPressed: () async {
        await Provider.of<FirestoreService>(context, listen: false).updateCaseBudget(liveCase.id, double.tryParse(_budgetController.text) ?? 0);
        Navigator.pop(context);
      }, child: const Text('SAVE'))],
    ));
  }

  void _showAddExpenseDialog(LegalCase liveCase) {
    _expenseTitleController.clear();
    _expenseAmountController.clear();
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Add Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(controller: _expenseTitleController, decoration: const InputDecoration(labelText: 'Title')),
        TextField(controller: _expenseAmountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
          final expense = CaseExpense(id: DateTime.now().millisecondsSinceEpoch.toString(), title: _expenseTitleController.text, amount: double.tryParse(_expenseAmountController.text) ?? 0, date: DateTime.now(), category: 'Other');
          await Provider.of<FirestoreService>(context, listen: false).addCaseExpense(liveCase.id, expense);
          Navigator.pop(context);
        }, child: const Text('SAVE'))),
        const SizedBox(height: 32),
      ]),
    ));
  }

  Widget _buildTimelineItem(CaseTimelineEntry entry, LegalCase liveCase, bool isLast) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue.shade600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
          if (!isLast) Expanded(child: Container(width: 2, color: Colors.grey.shade200))
        ]),
        const SizedBox(width: 20),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(DateFormat('MMM dd, yyyy').format(entry.date), style: const TextStyle(fontWeight: FontWeight.bold)),
              if (entry.nextHearingDate != null || entry.documentDeadline != null)
                IconButton(onPressed: () => _addReminderToCalendar(entry, liveCase), icon: const Icon(LucideIcons.bellPlus, size: 16, color: Colors.blue)),
            ]),
            const SizedBox(height: 8),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.description, style: const TextStyle(height: 1.5)),
                const SizedBox(height: 8),
                if (entry.nextHearingDate != null) _buildTag('Hearing: ${DateFormat('MMM dd').format(entry.nextHearingDate!)}', Colors.amber),
                if (entry.documentDeadline != null) _buildTag('Due: ${DateFormat('MMM dd').format(entry.documentDeadline!)}', Colors.deepPurple),
              ]),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 4, right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _addReminderToCalendar(CaseTimelineEntry entry, LegalCase liveCase) {
    if (entry.nextHearingDate != null) {
      Add2Calendar.addEvent2Cal(Event(title: '${liveCase.title} - Hearing', startDate: entry.nextHearingDate!, endDate: entry.nextHearingDate!.add(const Duration(hours: 1)), allDay: true));
    }
    if (entry.documentDeadline != null) {
      Add2Calendar.addEvent2Cal(Event(title: 'Deadline: ${liveCase.title}', startDate: entry.documentDeadline!, endDate: entry.documentDeadline!.add(const Duration(hours: 1)), allDay: true));
    }
  }
}
