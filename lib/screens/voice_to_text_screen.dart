import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:file_picker/file_picker.dart';
import '../services/gemini_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/analysis_history.dart';
import '../widgets/shimmer_loader.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import '../widgets/evidence_selector.dart';

class VoiceToTextScreen extends StatefulWidget {
  const VoiceToTextScreen({super.key});

  @override
  State<VoiceToTextScreen> createState() => _VoiceToTextScreenState();
}

class _VoiceToTextScreenState extends State<VoiceToTextScreen> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isRecording = false;
  String _selectedLanguage = 'English';
  final TextEditingController _evidenceController = TextEditingController();
  bool _isSummarizing = false;
  bool _isTranscribing = false;
  String? _legalSummary;
  late AnimationController _animationController;
  final List<PlatformFile> _attachedDocuments = [];
  bool _isPickingDocument = false;
  List<Map<String, dynamic>> _selectedVaultEvidence = [];

  final Map<String, String> _languageCodes = {
    'English': 'en-US',
    'Hindi (हिन्दी)': 'hi-IN',
    'Marathi (ಮರಾಠि)': 'mr-IN',
    'Tamil (தமிழ்)': 'ta-IN',
    'Telugu (తెలుగు)': 'te-IN',
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  void _toggleRecording() async {
    if (!_isRecording) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done') setState(() => _isRecording = false);
        },
        onError: (val) {
          setState(() => _isRecording = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mic Error: ${val.errorMsg}'), backgroundColor: Colors.red),
          );
        },
      );
      if (available) {
        setState(() => _isRecording = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _evidenceController.text = val.recognizedWords;
            });
          },
          localeId: _languageCodes[_selectedLanguage] ?? 'en-US',
          cancelOnError: true,
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice recording not supported on this device or permission denied.')),
        );
      }
    } else {
      setState(() => _isRecording = false);
      _speech.stop();
    }
  }

  Future<void> _pickAndUploadAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isTranscribing = true);

    try {
      final bytes = kIsWeb ? result.files.single.bytes! : await io.File(result.files.single.path!).readAsBytes();
      final mimeType = _getMimeType(result.files.single.extension);

      final gemini = Provider.of<GeminiService>(context, listen: false);
      final transcription = await gemini.transcribeAudioFile(bytes, mimeType);

      setState(() {
        _evidenceController.text = transcription;
        _isTranscribing = false;
      });

      // Save to History (Transcription)
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      if (auth.currentUserId != null) {
        await firestore.saveAnalysis(AnalysisHistory(
          id: '',
          userId: auth.currentUserId!,
          caseType: 'Voice Transcription',
          summary: 'Transcription ($_selectedLanguage)',
          result: transcription,
          createdAt: DateTime.now(),
        ));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio transcribed successfully!')),
      );
    } catch (e) {
      setState(() => _isTranscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transcription failed: $e')),
      );
    }
  }

  String _getMimeType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'mp3': return 'audio/mpeg';
      case 'wav': return 'audio/wav';
      case 'm4a': return 'audio/mp4';
      case 'aac': return 'audio/aac';
      case 'ogg': return 'audio/ogg';
      case 'pdf': return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      default: return 'application/pdf';
    }
  }

  Future<void> _pickDocuments() async {
    setState(() => _isPickingDocument = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
        withData: true,
      );
      if (result != null) {
        setState(() => _attachedDocuments.addAll(result.files));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Picker Error: $e')));
    } finally {
      setState(() => _isPickingDocument = false);
    }
  }

  void _removeDocument(int index) {
    setState(() => _attachedDocuments.removeAt(index));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(LucideIcons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Voice to Text Proof', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showHistory,
            icon: const Icon(LucideIcons.history),
            tooltip: 'View Voice History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildHero(),
              const SizedBox(height: 24),
              _buildRecordingControls(),
              const SizedBox(height: 24),
              _buildSummarySection(context),
              const SizedBox(height: 24),
              _buildNoteCard(),
              const SizedBox(height: 24),
              _buildRecentRecords(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E24AA), Color(0xFFD81B60)], // Purple to Pink
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice to Text Proof',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Transcribe audio evidence in multiple languages for court submission.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade50, blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AUDIO LANGUAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                isExpanded: true,
                items: ['English', 'Hindi (हिन्दी)', 'Marathi (ಮರಾಠಿ)', 'Tamil (தமிழ்)', 'Telugu (తెలుగు)']
                    .map((lang) => DropdownMenuItem(value: lang, child: Text(lang, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedLanguage = val!),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('PROCESS AUDIO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          // Record Button
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 64,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.blueGrey.shade900 : const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _isRecording ? Colors.black26 : Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isRecording)
                    FadeTransition(
                      opacity: _animationController,
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(LucideIcons.mic, color: Colors.white, size: 20),
                    ),
                  Text(
                    _isRecording ? 'STOP RECORDING' : 'START RECORDING',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('OR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _isTranscribing ? null : _pickAndUploadAudioFile,
            icon: _isTranscribing 
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.fileUp, size: 18),
            label: Text(_isTranscribing ? 'TRANSCRIBING...' : 'UPLOAD AUDIO FILE'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   Icon(LucideIcons.sparkles, size: 18, color: Colors.purple.shade600),
                   const SizedBox(width: 8),
                   const Text('LEGAL SUMMARIZER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
                ],
              ),
              IconButton(
                onPressed: _downloadTranscriptPdf,
                icon: const Icon(LucideIcons.download, color: Colors.purple, size: 20),
                tooltip: 'Download Transcript',
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _evidenceController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter incident details or paste transcription here...',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          const Text('SUPPORTING DOCUMENTS (PHOTOS/PDFs)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
          const SizedBox(height: 12),
          if (_attachedDocuments.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: _attachedDocuments.asMap().entries.map((entry) => Chip(
                label: Text(entry.value.name, style: const TextStyle(fontSize: 10)),
                onDeleted: () => _removeDocument(entry.key),
                backgroundColor: Colors.purple.shade50,
                side: BorderSide.none,
              )).toList(),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: _isPickingDocument ? null : _pickDocuments,
            icon: const Icon(LucideIcons.image, size: 16),
            label: Text(_isPickingDocument ? 'PICKING...' : 'ADD PHYSICAL PROOF'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              foregroundColor: Colors.purple.shade700,
              side: BorderSide(color: Colors.purple.shade100),
            ),
          ),
          const SizedBox(height: 16),
          EvidenceSelector(
            onSelectionChanged: (selected) {
              setState(() {
                _selectedVaultEvidence = selected;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSummarizing ? null : _generateSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSummarizing 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SUMMARIZE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSummarizing ? null : _generateFormalDraft,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSummarizing 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('DRAFT APPLICATION', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                ),
              ),
            ],
          ),
          if (_isSummarizing) ...[
            const SizedBox(height: 24),
            const SkeletonResult(),
          ] else if (_legalSummary != null) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            const Text('AI LEGAL INSIGHTS / DRAFT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.purple, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            MarkdownBody(
              data: _legalSummary!,
              onTapLink: (text, href, title) {
                if (href == '/advisors') {
                  context.go('/advisors');
                }
              },
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 14, color: Colors.blueGrey.shade900, height: 1.5, fontWeight: FontWeight.bold),
                strong: TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloadEvidenceCertificate,
                icon: const Icon(LucideIcons.fileCheck, size: 16),
                label: const Text('GENERATE LEGAL EVIDENCE CERTIFICATE (Sec 65B)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple.shade700,
                  side: BorderSide(color: Colors.purple.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateSummary() async {
    _performAIAction(action: 'summary');
  }

  Future<void> _generateFormalDraft() async {
    _performAIAction(action: 'draft');
  }

  Future<void> _performAIAction({required String action}) async {
    if (_evidenceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter evidence/thoughts first.')));
      return;
    }

    setState(() => _isSummarizing = true);
    
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      String instructions = "";
      if (action == 'summary') {
        instructions = """
        You are a legal expert specializing in Indian Family Law. 
        Analyze the provided transcription/text and provide:
        1. COURT-READY LEGAL SUMMARY: Structured facts.
        2. CASE STRENGTHENING ANALYSIS: Explain how this evidence helps.
        3. SUGGESTED EVIDENCE TYPE: Oral, Documentary, or Electronic (Sec 65B IEA).
        4. LEGAL REFERENCES: Specific sections and landmark judgments.
        """;
      } else {
        instructions = """
        You are an expert Indian Family Law legal drafter. 
        Based on the user's spoken thoughts/transcription, generate a FORMAL LEGAL APPLICATION or PETITION ready for court submission.
        - Use formal legal language (CPC/HMA).
        - Include sections: In the Court of..., Petitioner vs Respondent, Application under Section..., Facts, and Prayer.
        - Integrate relevant Supreme Court citations.
        """;
      }

      // Prepare attachments
      List<Map<String, dynamic>> attachments = [];
      
      // 1. Manually attached documents
      for (var file in _attachedDocuments) {
        if (file.bytes != null || file.path != null) {
          final bytes = file.bytes ?? (kIsWeb ? null : await io.File(file.path!).readAsBytes());
          if (bytes != null) {
            attachments.add({
              'bytes': Uint8List.fromList(bytes),
              'mimeType': _getMimeType(file.extension),
            });
          }
        }
      }

      // 2. Vault Evidence
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

      if (attachments.isNotEmpty) {
        await for (final text in gemini.streamMultimodalAnalysis(instructions, _evidenceController.text, attachments)) {
          setState(() {
            _legalSummary = text;
            _isSummarizing = false;
          });
        }
      } else {
        await for (final text in gemini.streamCustomPrompt(instructions, _evidenceController.text)) {
          setState(() {
            _legalSummary = text;
            _isSummarizing = false;
          });
        }
      }

      // Save to History (Final version)
      if (auth.currentUserId != null && _legalSummary != null) {
        await firestore.saveAnalysis(AnalysisHistory(
          id: '',
          userId: auth.currentUserId!,
          caseType: action == 'summary' ? 'Legal Summary' : 'Voice-to-Draft',
          summary: action == 'summary' ? 'Summary of Evidence' : 'Formal Application Draft',
          result: _legalSummary!,
          createdAt: DateTime.now(),
        ));
      }
    } catch (e) {
      setState(() => _isSummarizing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
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
              child: Text('Voice & Summary History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: StreamBuilder<List<AnalysisHistory>>(
                stream: firestore.streamAnalysisHistory(auth.currentUserId ?? ''),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final history = (snapshot.data ?? []).where((h) => h.caseType == 'Voice Transcription' || h.caseType == 'Legal Summary').toList();
                  if (history.isEmpty) return const Center(child: Text('No history found'));
                  
                  return ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final h = history[index];
                      return ListTile(
                        leading: Icon(h.caseType == 'Legal Summary' ? LucideIcons.sparkles : LucideIcons.mic, color: Colors.purple),
                        title: Text(h.summary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${h.caseType} • ${h.createdAt.toString().split(' ')[0]}'),
                        onTap: () {
                          setState(() {
                            if (h.caseType == 'Legal Summary') {
                              _legalSummary = h.result;
                            } else {
                              _evidenceController.text = h.result;
                            }
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

  Future<void> _downloadTranscriptPdf() async {
    if (_evidenceController.text.isEmpty) return;

    final pdf = pw.Document();
    
    String cleanTranscript = _evidenceController.text.replaceAll('*', '').replaceAll('_', '').trim();
    String? cleanSummary = _legalSummary?.replaceAll('###', '').replaceAll('##', '').replaceAll('#', '').replaceAll('**', '').replaceAll('*', '').replaceAll('_', '').trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Text('EVIDENCE TRANSCRIPT REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            pw.SizedBox(height: 5),
            pw.Divider(),
            pw.SizedBox(height: 20),
          ],
        ),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ),
        build: (pw.Context context) => [
          pw.Text('DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Language: $_selectedLanguage'),
          pw.Text('Date: ${DateTime.now().toLocal()}'),
          pw.SizedBox(height: 30),
          pw.Text('TRANSCRIPTION TEXT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.Paragraph(
            text: cleanTranscript,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
          ),
          if (cleanSummary != null) ...[
            pw.SizedBox(height: 30),
            pw.Text('LEGAL SUMMARY & ANALYSIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            pw.Paragraph(
              text: cleanSummary,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),
          ],
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Generated via LexAni AI Evidence Assistant', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Evidence_Transcript.pdf');
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Evidence_Transcript.pdf');
    }
  }

  Future<void> _downloadEvidenceCertificate() async {
     if (_evidenceController.text.isEmpty || _legalSummary == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please generate a Legal Summary first to create a Certificate.')));
       return;
     }

    final pdf = pw.Document();
    String cleanTranscript = _evidenceController.text.replaceAll('*', '').replaceAll('_', '').trim();
    String cleanSummary = _legalSummary!.replaceAll('###', '').replaceAll('##', '').replaceAll('#', '').replaceAll('**', '').replaceAll('*', '').replaceAll('_', '').trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text('LEXANI LEGAL VAULT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24, color: PdfColors.blue900)),
                pw.SizedBox(height: 4),
                pw.Text('CERTIFICATE OF DIGITAL EVIDENCE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                pw.SizedBox(height: 20),
                pw.Container(height: 2, color: PdfColors.blue900),
                pw.SizedBox(height: 20),
              ],
            ),
          ),
          pw.Text('DECLARATION UNDER SECTION 65B OF INDIAN EVIDENCE ACT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          pw.SizedBox(height: 10),
          pw.Text(
            'This is to certify that the following transcription is a true and accurate record of the audio/incident description processed by LexAni AI systems. The digital hash of this record is stored in our secure Legal Vault for validation.',
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 24),
          
          pw.Text('RECORD PARTICULARS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.grey800)),
          pw.Divider(height: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Language: $_selectedLanguage', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Date of Generation: ${DateTime.now().toLocal().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 24),

          pw.Text('TRANSCRIPTION RECORD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.grey800)),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8))),
            child: pw.Paragraph(text: cleanTranscript, style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4)),
          ),
          pw.SizedBox(height: 24),

          pw.Text('CASE STRENGTHENING ANALYSIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue800)),
          pw.SizedBox(height: 8),
          pw.Paragraph(text: cleanSummary, style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.4)),
          
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Digitally Verified by', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('LEXANI AI SYSTEMS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Container(
                width: 80, height: 40,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue100)),
                child: pw.Center(child: pw.Text('STAMP', style: pw.TextStyle(fontSize: 8, color: PdfColors.blue100))),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.Center(child: pw.Text('THIS DOCUMENT IS GENERATED FOR LEGAL PRE-VALIDATION PURPOSE. CONSULT AN ADVOCATE FOR FINAL FILING.', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500))),
        ],
      ),
    );

    if (kIsWeb) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Legal_Evidence_Certificate.pdf');
    } else {
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Legal_Evidence_Certificate.pdf');
    }
  }

  Widget _buildNoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertCircle, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text('NOTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue.shade700, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Court evidence requires clear audio. Transcripts are timestamped for legal accuracy.',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade900, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRecords() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('RECENT RECORDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(LucideIcons.playCircle, size: 48, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                Text('EMPTY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade400, letterSpacing: 1.2)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
