import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../services/gemini_service.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import '../widgets/evidence_selector.dart';
import '../models/advisor.dart';
import '../models/analysis_history.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_loader.dart';
import 'package:http_parser/http_parser.dart';

class AiMatchScreen extends StatefulWidget {
  const AiMatchScreen({super.key});

  @override
  State<AiMatchScreen> createState() => _AiMatchScreenState();
}

class _AiMatchScreenState extends State<AiMatchScreen> {
  final TextEditingController _summaryController = TextEditingController();
  String? _selectedCaseType;
  bool _isLoading = false;
  List<Advisor>? _recommendedAdvisors;
  String? _analysisResult;
  final List<PlatformFile> _attachedFiles = [];
  bool _isPickingFile = false;
  late stt.SpeechToText _speech;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String _recognizedText = '';
  double _soundLevel = 0.0;
  bool _isReprocessing = false;
  String? _translatedResult;
  bool _isTranslating = false;
  String? _selectedLanguageCode;
  List<Map<String, dynamic>> _selectedVaultEvidence = [];

  final Map<String, String> _indianLanguages = {
    'hi': 'Hindi (हिन्दी)',
    'mr': 'Marathi (मराठी)',
    'gu': 'Gujarati (ગુજરાતી)',
    'bn': 'Bengali (বাংলা)',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'ml': 'Malayalam (മലയാളം)',
    'pa': 'Punjabi (ਪੰਜਾਬੀ)',
    'en': 'English (English)',
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _summaryController.dispose();
    super.dispose();
  }

  void _toggleRecording() async {
    if (!_isRecording) {
      // Show recording modal
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildRecordingModal(),
      );

      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _stopRecording();
          }
        },
        onError: (val) {
          _stopRecording();
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Microphone Error: ${val.errorMsg}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );

      if (available) {
        final systemLocale = await _speech.systemLocale();
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
          _recognizedText = '';
          _soundLevel = 0.0;
        });

        // Start timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
        });

        _speech.listen(
          onResult: (val) {
            setState(() {
              _recognizedText = val.recognizedWords;
            });
          },
          onSoundLevelChange: (level) {
            setState(() {
              _soundLevel = level;
            });
          },
          listenMode: stt.ListenMode.dictation,
          localeId: systemLocale?.localeId ?? 'en_IN',
          cancelOnError: false,
          partialResults: true,
        );
      } else {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice recording not supported on this device.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      _stopRecording();
      Navigator.of(context).pop();
    }
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
    _recordingTimer?.cancel();
    _speech.stop();
  }

  Future<void> _cleanTranscriptWithAI(StateSetter setModalState) async {
    if (_recognizedText.isEmpty) return;

    setModalState(() => _isReprocessing = true);
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final cleaned = await gemini.cleanTranscript(_recognizedText);
      setState(() => _recognizedText = cleaned);
      setModalState(() => _isReprocessing = false);
    } catch (e) {
      setModalState(() => _isReprocessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cleaning failed: $e')));
    }
  }

  Future<void> _downloadVoiceAsPdf() async {
    if (_recognizedText.isEmpty) return;

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'VOICE TRANSCRIPTION REPORT',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Generated via LexAni AI on ${DateTime.now().toString().split('.')[0]}',
            ),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text(_recognizedText, style: const pw.TextStyle(fontSize: 14)),
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Note: This is an AI-generated transcript from a voice recording. Verify details before official submission.',
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Voice_Transcript.pdf',
    );
  }

  final List<String> _caseTypes = [
    'Divorce',
    'Child Custody',
    'Alimony/Maintenance',
    'Domestic Violence',
    'Property Dispute',
    'Restitution of Conjugal Rights',
    'Others',
  ];

  Future<void> _analyzeCase() async {
    if ((_summaryController.text.isEmpty && _attachedFiles.isEmpty) ||
        _selectedCaseType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a case type and provide details or attach a document',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _analysisResult = null;
    });

    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      // Build prompt with case details
      final prompt = '''
You are LexAni AI — a specialist in Indian Family Law trained on district court, High Court, and Supreme Court judgments across all Indian states.

CASE TYPE: $_selectedCaseType
CASE FACTS: ${_summaryController.text}

Analyze ONLY the facts provided above. Do NOT use generic advice. Every section must be tailored to this specific case.

Respond in the following Markdown format:

## ⚖️ Legal Analysis
Identify the exact applicable statutes (e.g., Section 13 HMA 1955, Section 125 CrPC, Protection of Women from Domestic Violence Act 2005, Section 24 HMA, etc.) relevant to THIS specific case. Explain how each applies.

## 💪 Strengths & Supporting Precedents
List 3–5 specific Supreme Court or High Court judgments that support the user's position in THIS type of case. For each, state the case name, year, court, and the precise legal principle it establishes.

## ⚠️ Risks & Counter-Arguments
List specific judgments or legal principles the opposing party could rely on. Be honest about the weaknesses in this case based on the facts given.

## ✅ Immediate Next Steps
Generate 4–6 concrete, actionable steps specific to this case and case type. Each step should be a single sentence. These must NOT be generic — they must reflect the specific facts above.

## 👨‍⚖️ Recommended Advocate Type
Specify the exact specialization needed (e.g., "Senior Family Court advocate with experience in contested divorce and Section 24 HMA interim maintenance" rather than just "family lawyer").

## 📚 Key Legal References
List the statutes and landmark cases cited above in a clean reference list.

---
*Disclaimer: This analysis is AI-generated for informational purposes. Consult a qualified advocate before taking legal action.*''';


      // If files attached, try multimodal analysis
      String result;
      if (_attachedFiles.isNotEmpty && _attachedFiles.first.bytes != null) {
        result = await gemini.generateWithFallback([
          Content.multi([
            TextPart(prompt),
            DataPart(_getMimeType(_attachedFiles.first.extension), _attachedFiles.first.bytes!),
          ]),
        ]);
      } else {
        result = await gemini.generateWithFallback([Content.text(prompt)]);
      }

      setState(() {
        _analysisResult = result;
      });

      // Save to history
      if (auth.currentUserId != null) {
        await firestore.saveAnalysis(AnalysisHistory(
          id: '',
          userId: auth.currentUserId!,
          caseType: _selectedCaseType!,
          summary: _summaryController.text,
          result: result,
          createdAt: DateTime.now(),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/pdf';
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
        setState(() {
          _attachedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File picker error: $e')));
    } finally {
      setState(() => _isPickingFile = false);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  Future<void> _downloadAnalysisPdf() async {
    if (_analysisResult == null) return;

    final pdf = pw.Document();

    // Clean up markdown for PDF more thoroughly
    String cleanText = _analysisResult!
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
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Text(
              'CASE ANALYSIS REPORT',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18),
            ),
            pw.Divider(),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
        build: (pw.Context context) => [
          pw.Text(
            'CASE SUMMARY',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Type: $_selectedCaseType',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(_summaryController.text),
          pw.SizedBox(height: 24),
          pw.Text(
            'AI ANALYSIS & RESEARCH',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 8),
          pw.Paragraph(
            text: cleanText,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            'Generated by LexAni AI',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Case_Analysis_Report.pdf',
      );
    } else {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Case_Analysis_Report.pdf',
      );
    }
  }

  Future<void> _translateAnalysis(String langCode) async {
  if (_analysisResult == null || langCode == 'en') {
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
    final gemini = Provider.of<GeminiService>(context, listen: false);
    final langName = _indianLanguages[langCode] ?? langCode;
    final translated = await gemini.translateText(_analysisResult!, langName);

    if (mounted) {
      setState(() {
        _translatedResult = translated;
        _isTranslating = false;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _isTranslating = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: $e')),
      );
    }
  }
}
 void _showLanguageSelector() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, //IMPORTANT
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6, // 60% of screen
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const Text(
                'Choose Language',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              //FIX: Expanded instead of SizedBox
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: _indianLanguages.entries.map((entry) {
                    return ListTile(
                      title: Text(
                        entry.value,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
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
        );
      },
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
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Analysis History',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<AnalysisHistory>>(
                stream: firestore.streamAnalysisHistory(
                  auth.currentUserId ?? '',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allHistory = snapshot.data ?? [];
                  // Filter for case analyzer types specifically
                  final history = allHistory
                      .where((h) => _caseTypes.contains(h.caseType))
                      .toList();

                  if (history.isEmpty) {
                    return const Center(
                      child: Text('No case analysis history found'),
                    );
                  }

                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final h = history[index];
                      return ListTile(
                        title: Text(
                          h.caseType,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          h.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(h.createdAt.toString().split(' ')[0]),
                        onTap: () {
                          setState(() {
                            _selectedCaseType = h.caseType;
                            _summaryController.text = h.summary;
                            _analysisResult = h.result;
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
        title: const Text(
          'AI Case Analyzer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showHistory,
            icon: const Icon(LucideIcons.history),
            tooltip: 'View Analysis History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputForm(),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: SkeletonResult(),
                    ),
                  if (_analysisResult != null) _buildResultSection(),
                ],
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
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)], // Purple to Blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(LucideIcons.sparkles, color: Colors.white, size: 32),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'AI-Powered Case Analyzer',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Get instant insights and cost estimation for your legal case',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.fileText, size: 20, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              const Text(
                'Enter Case Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Case Type',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text(
                  'Select case type',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _selectedCaseType,
                items: _caseTypes.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCaseType = val),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Case Summary (Be as detailed as possible)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _summaryController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText:
                  'Describe your case in detail - include dates, incidents, and relevant facts...',
              hintStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade100),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade100),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Voice Input Button
          OutlinedButton.icon(
            onPressed: _toggleRecording,
            icon: Icon(LucideIcons.mic, size: 20, color: Colors.blue.shade700),
            label: Text(
              'USE VOICE INPUT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 0.5,
                color: Colors.blue.shade700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: Colors.blue.shade200, width: 2),
              backgroundColor: Colors.blue.shade50.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Attach Documents (Legal Notices, FIR, Court Orders, etc.)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          if (_attachedFiles.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _attachedFiles.asMap().entries.map((entry) {
                final idx = entry.key;
                final file = entry.value;
                return Chip(
                  label: Text(
                    file.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                  onDeleted: () => _removeFile(idx),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          OutlinedButton.icon(
            onPressed: _isPickingFile ? null : _pickFiles,
            icon: _isPickingFile
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.paperclip, size: 16),
            label: Text(_isPickingFile ? 'PICKING...' : 'ATTACH DOCUMENTS'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: Colors.blue.shade100),
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
              onPressed: _isLoading ? null : _analyzeCase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: const Text(
                'ANALYZE CASE',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        const Text(
          'Detailed AI Analysis',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),  
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
  children: [
    const Icon(
      LucideIcons.shieldCheck,
      color: Colors.blue,
      size: 20,
    ),
    const SizedBox(width: 8),

    // FIX: make text flexible
    Expanded(
      child: Text(
        'RESEARCH ASSISTANT GUIDANCE',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.blue,
          letterSpacing: 1.0,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),

    // right side icons
    Row(
      mainAxisSize: MainAxisSize.min, //important
      children: [
        IconButton(
          onPressed: _showLanguageSelector,
          icon: const Icon(
            LucideIcons.languages,
            color: Colors.blue,
            size: 20,
          ),
          tooltip: 'Translate',
        ),
        IconButton(
          onPressed: _downloadAnalysisPdf,
          icon: const Icon(
            LucideIcons.download,
            color: Colors.blue,
            size: 20,
          ),
          tooltip: 'Download Analysis',
        ),
      ],
    ),
  ],
),
              const SizedBox(height: 24),
              if (_selectedLanguageCode != null &&
                  _selectedLanguageCode != 'en')
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Viewing in: ${_indianLanguages[_selectedLanguageCode]}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
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
                  data:
                      _selectedLanguageCode == 'en' ||
                          _selectedLanguageCode == null
                      ? _analysisResult!
                      : (_translatedResult ?? _analysisResult!),
                  onTapLink: (text, href, title) {
                    if (href == '/advisors') {
                      context.go('/advisors');
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade900,
                      height: 1.6,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.blue.shade900,
                    ),
                    h1: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    h2: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    h3: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    listBullet: TextStyle(
                      color: Colors.blue.shade900,
                      fontSize: 16,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.go('/home/library'),
                icon: const Icon(LucideIcons.library, size: 16),
                label: const Text('SEARCH LEGAL LIBRARY FOR DETAILS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade800,
                  side: BorderSide(color: Colors.blue.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildAdvisorCTA(),
        if (_isLoading) ...[
          const SizedBox(height: 48),
          const ShimmerLoader(width: 200, height: 20),
          const SizedBox(height: 24),
          const SkeletonAdvisorList(),
        ] else if (_recommendedAdvisors != null &&
            _recommendedAdvisors!.isNotEmpty) ...[
          const SizedBox(height: 48),
          const Text(
            'Recommended Advisors',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          ..._recommendedAdvisors!
              .map((advisor) => _buildSimpleAdvisorCard(advisor))
              ,
        ],
      ],
    );
  }

  Widget _buildAdvisorCTA() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            'Need professional expert advice?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/advisors'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueGrey.shade900,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'TALK TO VERIFIED ADVISORS',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAdvisorCard(Advisor advisor) {
    return GestureDetector(
      onTap: () => context.go('/advisors'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade50,
              child: Text(
                advisor.name[0],
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    advisor.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${advisor.specialization} • ${advisor.experience.toInt()} yrs experience',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Colors.blue.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.checkSquare, size: 16, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1E3A8A),
                Color(0xFF3B82F6),
              ], // Deep blue to blue
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
            ),
          ),
          child: SingleChildScrollView(
  child: Column(
    children: [
      // Handle bar
      Container(
        margin: const EdgeInsets.only(top: 16),
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      const SizedBox(height: 40),

      // Title
      const Text(
        'Voice Recording',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),

      const SizedBox(height: 8),

      Text(
        'Speak clearly about your case',
        style: TextStyle(
          fontSize: 16,
          color: Colors.white.withOpacity(0.8),
          fontWeight: FontWeight.w500,
        ),
      ),

      const SizedBox(height: 48),

      // Animated microphone icon
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: _isRecording ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2 * value),
                  blurRadius: 40 * value,
                  spreadRadius: 20 * value,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording ? Colors.red : Colors.white,
                ),
                child: Icon(
                  _isRecording ? LucideIcons.mic : LucideIcons.micOff,
                  size: 48,
                  color: _isRecording
                      ? Colors.white
                      : const Color(0xFF1E3A8A),
                ),
              ),
            ),
          );
        },
      ),

      const SizedBox(height: 32),

      // Recording duration
      if (_isRecording) ...[
        _buildWaveformAnimation(),
        const SizedBox(height: 24),
        Text(
          _formatDuration(_recordingDuration),
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            _recognizedText.isEmpty ? 'Listening...' : _recognizedText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ] else ...[
        Text(
          'Tap to start recording',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],

      const SizedBox(height: 20), // replaced Spacer()

      if (!_isRecording && _recognizedText.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isReprocessing
                      ? null
                      : () => _cleanTranscriptWithAI(setModalState),
                  icon: _isReprocessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        )
                      : const Icon(LucideIcons.sparkles, size: 14),
                  label: const Text(
                    'AI NOISE FILTER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _downloadVoiceAsPdf,
                  icon: const Icon(LucideIcons.fileText, size: 14),
                  label: const Text(
                    'VOICE TO PDF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],

      // Control buttons
      Padding(
        padding: const EdgeInsets.all(32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: LucideIcons.x,
              label: 'Cancel',
              onPressed: () {
                _stopRecording();
                setState(() {
                  _recognizedText = '';
                });
                Navigator.of(context).pop();
              },
              backgroundColor: Colors.white.withOpacity(0.2),
              iconColor: Colors.white,
            ),
            _buildControlButton(
              icon: _isRecording ? LucideIcons.square : LucideIcons.mic,
              label: _isRecording ? 'Stop' : 'Record',
              onPressed: _toggleRecording,
              backgroundColor: _isRecording ? Colors.red : Colors.white,
              iconColor: _isRecording
                  ? Colors.white
                  : const Color(0xFF1E3A8A),
              isPrimary: true,
            ),
            _buildControlButton(
              icon: LucideIcons.check,
              label: 'Done',
              onPressed: _recognizedText.isNotEmpty
                  ? () {
                      _stopRecording();
                      if (_recognizedText.isNotEmpty) {
                        if (_summaryController.text.isEmpty) {
                          _summaryController.text = _recognizedText;
                        } else {
                          _summaryController.text =
                              '${_summaryController.text} $_recognizedText';
                        }
                      }
                      Navigator.of(context).pop();
                    }
                  : null,
              backgroundColor: _recognizedText.isNotEmpty
                  ? Colors.green
                  : Colors.white.withOpacity(0.1),
              iconColor: Colors.white,
            ),
          ],
        ),
      ),
    ],
  ),
),
        );
      },
    );
  }

  Widget _buildWaveformAnimation() {
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(15, (index) {
          // Calculate high based on both base level and sound level
          // _soundLevel typically ranges from -2 to 10 depending on the platform
          double level = (_soundLevel + 2).clamp(0, 15);
          double multiplier = 1.0 + (level / 2.0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3,
            height: _isRecording ? (10 + (index % 4) * 5) * multiplier : 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color iconColor,
    bool isPrimary = false,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(35),
            child: Container(
              width: isPrimary ? 80 : 70,
              height: isPrimary ? 80 : 70,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                boxShadow: isPrimary
                    ? [
                        BoxShadow(
                          color: backgroundColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, size: isPrimary ? 36 : 28, color: iconColor),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}