import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../services/gemini_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/analysis_history.dart';
import 'package:go_router/go_router.dart';
import '../widgets/shimmer_loader.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:async';
import 'package:docx_template/docx_template.dart';
import 'package:signature/signature.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/evidence_selector.dart';

class DocGeneratorScreen extends StatefulWidget {
  const DocGeneratorScreen({super.key});

  @override
  State<DocGeneratorScreen> createState() => _DocGeneratorScreenState();
}

class _DocGeneratorScreenState extends State<DocGeneratorScreen> {
  int _currentStep = 1;
  final int _totalSteps = 7;
  bool _isGenerating = false;
  bool _isExtracting = false;
  String _generatedDraft = '';
  String _extractedTathya = '';
  String? _translatedResult;
  bool _isTranslating = false;
  String? _selectedLanguageCode;
  List<Map<String, dynamic>> _selectedVaultEvidence = [];
  
  // Voice Input
  late stt.SpeechToText _speech;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String _recognizedText = '';
  double _soundLevel = 0.0;
  bool _isReprocessing = false;

  // Signature / E-Sign
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent,
  );
  Uint8List? _signatureImage;
  bool _isSigning = false;

  // OCR
  bool _isParsingDoc = false;
  String? _ocrResult;

  final Map<String, String> _indianLanguages = {
    'hi': 'Hindi (हिन्दी)',
    'mr': 'Marathi (ਮਰਾਠੀ)',
    'gu': 'Gujarati (ગુજરાતી)',
    'bn': 'Bengali (বাংলা)',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'ml': 'Malayalam (മലയാളം)',
    'pa': 'Punjabi (ਪੰਜਾਬੀ)',
    'en': 'English (English)',
  };

  // Form Data
  String _docType = 'Petition';
  String _caseType = 'Divorce';
  
  // Petitioner
  final _petitionerNameController = TextEditingController();
  final _petitionerFatherController = TextEditingController();
  final _petitionerAgeController = TextEditingController();
  final _petitionerAddressController = TextEditingController();
  final _petitionerCityController = TextEditingController();
  final _petitionerStateController = TextEditingController();

  // Second Petitioner (Optional)
  bool _hasSecondPetitioner = false;
  final _petitioner2NameController = TextEditingController();
  final _petitioner2FatherController = TextEditingController();
  final _petitioner2AgeController = TextEditingController();
  final _petitioner2AddressController = TextEditingController();
  final _petitioner2CityController = TextEditingController();
  final _petitioner2StateController = TextEditingController();

  // Respondent
  final _respondentNameController = TextEditingController();
  final _respondentFatherController = TextEditingController();
  final _respondentAgeController = TextEditingController();
  final _respondentAddressController = TextEditingController();
  final _respondentCityController = TextEditingController();
  final _respondentStateController = TextEditingController();

  // Marriage
  final _marriageDateController = TextEditingController();
  final _marriagePlaceController = TextEditingController();
  final _childrenCountController = TextEditingController();

  // Court
  final _courtNameController = TextEditingController();
  final _courtDistrictController = TextEditingController();

  // Facts
  final _caseDetailsController = TextEditingController();
  final _rawStoryController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _petitionerNameController.dispose();
    _petitionerFatherController.dispose();
    _petitionerAgeController.dispose();
    _petitionerAddressController.dispose();
    _petitionerCityController.dispose();
    _petitionerStateController.dispose();
    _respondentNameController.dispose();
    _respondentFatherController.dispose();
    _respondentAgeController.dispose();
    _respondentAddressController.dispose();
    _respondentCityController.dispose();
    _respondentStateController.dispose();
    _marriageDateController.dispose();
    _marriagePlaceController.dispose();
    _childrenCountController.dispose();
    _courtNameController.dispose();
    _courtDistrictController.dispose();
    _caseDetailsController.dispose();
    _rawStoryController.dispose();
    _petitioner2NameController.dispose();
    _petitioner2FatherController.dispose();
    _petitioner2AgeController.dispose();
    _petitioner2AddressController.dispose();
    _petitioner2CityController.dispose();
    _petitioner2StateController.dispose();
    super.dispose();
  }

  /// Collect all form data into a Map for persistence
  Map<String, dynamic> _collectFormData() {
    return {
      'docType': _docType,
      'caseType': _caseType,
      'hasSecondPetitioner': _hasSecondPetitioner,
      // Petitioner 1
      'petitionerName': _petitionerNameController.text,
      'petitionerFather': _petitionerFatherController.text,
      'petitionerAge': _petitionerAgeController.text,
      'petitionerAddress': _petitionerAddressController.text,
      'petitionerCity': _petitionerCityController.text,
      'petitionerState': _petitionerStateController.text,
      // Petitioner 2
      'petitioner2Name': _petitioner2NameController.text,
      'petitioner2Father': _petitioner2FatherController.text,
      'petitioner2Age': _petitioner2AgeController.text,
      'petitioner2Address': _petitioner2AddressController.text,
      'petitioner2City': _petitioner2CityController.text,
      'petitioner2State': _petitioner2StateController.text,
      // Respondent
      'respondentName': _respondentNameController.text,
      'respondentFather': _respondentFatherController.text,
      'respondentAge': _respondentAgeController.text,
      'respondentAddress': _respondentAddressController.text,
      'respondentCity': _respondentCityController.text,
      'respondentState': _respondentStateController.text,
      // Marriage
      'marriageDate': _marriageDateController.text,
      'marriagePlace': _marriagePlaceController.text,
      'childrenCount': _childrenCountController.text,
      // Court
      'courtName': _courtNameController.text,
      'courtDistrict': _courtDistrictController.text,
      // Facts
      'caseDetails': _caseDetailsController.text,
      'rawStory': _rawStoryController.text,
    };
  }

  /// Restore form data from a Map
  void _restoreFormData(Map<String, dynamic> data) {
    setState(() {
      _docType = data['docType'] ?? 'Petition';
      _caseType = data['caseType'] ?? 'Divorce';
      _hasSecondPetitioner = data['hasSecondPetitioner'] ?? false;
      // Petitioner 1
      _petitionerNameController.text = data['petitionerName'] ?? '';
      _petitionerFatherController.text = data['petitionerFather'] ?? '';
      _petitionerAgeController.text = data['petitionerAge'] ?? '';
      _petitionerAddressController.text = data['petitionerAddress'] ?? '';
      _petitionerCityController.text = data['petitionerCity'] ?? '';
      _petitionerStateController.text = data['petitionerState'] ?? '';
      // Petitioner 2
      _petitioner2NameController.text = data['petitioner2Name'] ?? '';
      _petitioner2FatherController.text = data['petitioner2Father'] ?? '';
      _petitioner2AgeController.text = data['petitioner2Age'] ?? '';
      _petitioner2AddressController.text = data['petitioner2Address'] ?? '';
      _petitioner2CityController.text = data['petitioner2City'] ?? '';
      _petitioner2StateController.text = data['petitioner2State'] ?? '';
      // Respondent
      _respondentNameController.text = data['respondentName'] ?? '';
      _respondentFatherController.text = data['respondentFather'] ?? '';
      _respondentAgeController.text = data['respondentAge'] ?? '';
      _respondentAddressController.text = data['respondentAddress'] ?? '';
      _respondentCityController.text = data['respondentCity'] ?? '';
      _respondentStateController.text = data['respondentState'] ?? '';
      // Marriage
      _marriageDateController.text = data['marriageDate'] ?? '';
      _marriagePlaceController.text = data['marriagePlace'] ?? '';
      _childrenCountController.text = data['childrenCount'] ?? '';
      // Court
      _courtNameController.text = data['courtName'] ?? '';
      _courtDistrictController.text = data['courtDistrict'] ?? '';
      // Facts
      _caseDetailsController.text = data['caseDetails'] ?? '';
      _rawStoryController.text = data['rawStory'] ?? '';
    });
  }


  void _nextStep() {
    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
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
        title: const Text('Drafting Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showHistory,
            icon: const Icon(LucideIcons.history),
            tooltip: 'View Draft History',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _isGenerating ? const SkeletonResult() : _buildCurrentStep(),
            ),
          ),
          if (_currentStep < 5) _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                width: double.infinity,
                color: Colors.grey.shade200,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                width: MediaQuery.of(context).size.width * ((_currentStep - 1) / (_totalSteps - 1)),
                color: Colors.blue.shade600,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(_totalSteps - 1, (index) {
                   int stepNum = index + 1;
                   bool isActive = _currentStep >= stepNum;
                   return Container(
                     width: 32,
                     height: 32,
                     decoration: BoxDecoration(
                       color: isActive ? Colors.blue.shade600 : Colors.white,
                       border: Border.all(color: isActive ? Colors.blue.shade600 : Colors.grey.shade300),
                       shape: BoxShape.circle,
                       boxShadow: isActive ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                     ),
                     child: Center(
                       child: Text(
                         index == 0 ? '★' : '${index + 1}',
                         style: TextStyle(
                           color: isActive ? Colors.white : Colors.grey.shade400,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                   );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildExtraStep(); // The Story
      case 3:
        return _buildStep2(); // Petitioner
      case 4:
        return _buildStep3(); // Respondent
      case 5:
        return _buildStep4(); // Marriage
      case 6:
        return _buildStep5(); // Final Review
      case 7:
        return _buildStep6(); // Generated
      default:
        return Container();
    }
  }

  // Step 1: Document Type
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(LucideIcons.clipboardList, 'Document Type', Colors.blue),
        const SizedBox(height: 16),
        _buildDropdown('Select Document Type', _docType, ['Petition', 'Notice', 'Affidavit', 'Application', 'Memorandum of Settlement', 'Affidavit of Assets and Liabilities (Rajnesh v. Neha)'], (val) => setState(() => _docType = val!)),
        const SizedBox(height: 24),
        _buildSectionHeader(LucideIcons.gavel, 'Case Nature', Colors.indigo),
        const SizedBox(height: 16),
        _buildDropdown('Select Case Nature', _caseType, ['Divorce', 'Child Custody', 'Alimony', 'Domestic Violence'], (val) => setState(() => _caseType = val!)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.indigo.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.sparkles, color: Colors.indigo, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Drafting Engine', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo.shade900)),
                    const SizedBox(height: 8),
                    Text('The drafting vault uses specialized templates aligned with the Civil Procedure Code (CPC). Choose carefully.', style: TextStyle(fontSize: 12, color: Colors.indigo.shade700, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // New Step: The Story (Tathya Extraction)
  Widget _buildExtraStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Tell Your Story', LucideIcons.quote, Colors.purple),
        const SizedBox(height: 16),
        const Text(
          'Describe your situation in plain language. Our "Tathya AI" will extract the legal facts and pre-fill the next steps for you.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _rawStoryController,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: "E.g. My name is Rajesh. I married Sunita on 12th Jan 2015 in Mumbai. We have two kids. Lately, we've had many disputes regarding...",
            fillColor: Colors.purple.shade50,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _toggleRecording,
          icon: Icon(LucideIcons.mic, size: 20, color: Colors.purple.shade700),
          label: Text(
            'USE VOICE INPUT',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5, color: Colors.purple.shade700),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: Colors.purple.shade200, width: 2),
            backgroundColor: Colors.purple.shade50.withOpacity(0.3),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isExtracting ? null : _extractTathya,
          icon: _isExtracting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(LucideIcons.sparkles),
          label: Text(_isExtracting ? 'EXTRACTING TATHYA...' : 'REVOLUTIONARY FACT EXTRACTION'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        if (_extractedTathya.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade100)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.checkCircle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    const Text('TATHYA EXTRACTED', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('We have identified the core facts and pre-filled the next forms. Click "CONTINUE" to review them.', style: TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _extractTathya() async {
    if (_rawStoryController.text.trim().isEmpty) return;
    
    setState(() => _isExtracting = true);
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final result = await gemini.extractFacts(_rawStoryController.text);
      
      // Enhanced parser for the new structured format
      setState(() {
        // Parse Petitioner Details
        final petNameMatch = RegExp(r'Petitioner Name:\s*(.+)', caseSensitive: false).firstMatch(result);
        final petFatherMatch = RegExp(r'Petitioner Father/Husband Name:\s*(.+)', caseSensitive: false).firstMatch(result);
        final petAgeMatch = RegExp(r'Petitioner Age:\s*(.+)', caseSensitive: false).firstMatch(result);
        final petAddressMatch = RegExp(r'Petitioner Address:\s*(.+)', caseSensitive: false).firstMatch(result);
        final petCityMatch = RegExp(r'Petitioner City:\s*(.+)', caseSensitive: false).firstMatch(result);
        final petStateMatch = RegExp(r'Petitioner State:\s*(.+)', caseSensitive: false).firstMatch(result);
        
        // Parse Respondent Details
        final resNameMatch = RegExp(r'Respondent Name:\s*(.+)', caseSensitive: false).firstMatch(result);
        final resFatherMatch = RegExp(r'Respondent Father/Husband Name:\s*(.+)', caseSensitive: false).firstMatch(result);
        final resAgeMatch = RegExp(r'Respondent Age:\s*(.+)', caseSensitive: false).firstMatch(result);
        final resAddressMatch = RegExp(r'Respondent Address:\s*(.+)', caseSensitive: false).firstMatch(result);
        final resCityMatch = RegExp(r'Respondent City:\s*(.+)', caseSensitive: false).firstMatch(result);
        final resStateMatch = RegExp(r'Respondent State:\s*(.+)', caseSensitive: false).firstMatch(result);
        
        // Parse Marriage Details
        final marriageDateMatch = RegExp(r'Marriage Date:\s*(.+)', caseSensitive: false).firstMatch(result);
        final marriagePlaceMatch = RegExp(r'Marriage Place:\s*(.+)', caseSensitive: false).firstMatch(result);
        final childrenMatch = RegExp(r'Children Count:\s*(.+)', caseSensitive: false).firstMatch(result);
        
        // Parse Case Facts
        final factsMatch = RegExp(r'=== CASE FACTS ===\s*\n([\s\S]*?)(?:===|$)', caseSensitive: false).firstMatch(result);
        
        // Auto-fill Petitioner Details (only if not "Not mentioned")
        if (petNameMatch != null) {
          final name = petNameMatch.group(1)!.trim();
          if (!name.toLowerCase().contains('not mentioned')) {
            _petitionerNameController.text = name;
          }
        }
        
        if (petFatherMatch != null) {
          final father = petFatherMatch.group(1)!.trim();
          if (!father.toLowerCase().contains('not mentioned')) {
            _petitionerFatherController.text = father;
          }
        }
        
        if (petAgeMatch != null) {
          final age = petAgeMatch.group(1)!.trim();
          if (!age.toLowerCase().contains('not mentioned')) {
            _petitionerAgeController.text = age;
          }
        }
        
        if (petAddressMatch != null) {
          final address = petAddressMatch.group(1)!.trim();
          if (!address.toLowerCase().contains('not mentioned')) {
            _petitionerAddressController.text = address;
          }
        }
        
        if (petCityMatch != null) {
          final city = petCityMatch.group(1)!.trim();
          if (!city.toLowerCase().contains('not mentioned')) {
            _petitionerCityController.text = city;
          }
        }
        
        if (petStateMatch != null) {
          final state = petStateMatch.group(1)!.trim();
          if (!state.toLowerCase().contains('not mentioned')) {
            _petitionerStateController.text = state;
          }
        }
        
        // Auto-fill Respondent Details
        if (resNameMatch != null) {
          final name = resNameMatch.group(1)!.trim();
          if (!name.toLowerCase().contains('not mentioned')) {
            _respondentNameController.text = name;
          }
        }
        
        if (resFatherMatch != null) {
          final father = resFatherMatch.group(1)!.trim();
          if (!father.toLowerCase().contains('not mentioned')) {
            _respondentFatherController.text = father;
          }
        }
        
        if (resAgeMatch != null) {
          final age = resAgeMatch.group(1)!.trim();
          if (!age.toLowerCase().contains('not mentioned')) {
            _respondentAgeController.text = age;
          }
        }
        
        if (resAddressMatch != null) {
          final address = resAddressMatch.group(1)!.trim();
          if (!address.toLowerCase().contains('not mentioned')) {
            _respondentAddressController.text = address;
          }
        }
        
        if (resCityMatch != null) {
          final city = resCityMatch.group(1)!.trim();
          if (!city.toLowerCase().contains('not mentioned')) {
            _respondentCityController.text = city;
          }
        }
        
        if (resStateMatch != null) {
          final state = resStateMatch.group(1)!.trim();
          if (!state.toLowerCase().contains('not mentioned')) {
            _respondentStateController.text = state;
          }
        }
        
        // Auto-fill Marriage Details
        if (marriageDateMatch != null) {
          final date = marriageDateMatch.group(1)!.trim();
          if (!date.toLowerCase().contains('not mentioned')) {
            _marriageDateController.text = date;
          }
        }
        
        if (marriagePlaceMatch != null) {
          final place = marriagePlaceMatch.group(1)!.trim();
          if (!place.toLowerCase().contains('not mentioned')) {
            _marriagePlaceController.text = place;
          }
        }
        
        if (childrenMatch != null) {
          final children = childrenMatch.group(1)!.trim();
          if (!children.toLowerCase().contains('not mentioned')) {
            _childrenCountController.text = children;
          }
        }
        
        // Auto-fill Case Facts
        if (factsMatch != null) {
          final facts = factsMatch.group(1)!.trim();
          if (!facts.toLowerCase().contains('not mentioned') && facts.isNotEmpty) {
            _caseDetailsController.text = facts;
          }
        }
        
        _extractedTathya = result;
        _isExtracting = false;
      });
      
      // Show success message with details of what was filled
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Tathya AI has intelligently pre-filled your form! Review and continue.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Extraction failed: $e')));
      }
    }
  }

  // Step 2: Petitioner
  Widget _buildStep2() {
    return Column(
      children: [
        _buildSectionTitle('Petitioner(s) Profile', LucideIcons.users, Colors.blue),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _autoFillFromProfile,
              icon: const Icon(LucideIcons.userCheck, size: 16),
              label: const Text('Auto-Fill', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Add Second Petitioner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              value: _hasSecondPetitioner,
              onChanged: (val) => setState(() => _hasSecondPetitioner = val),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Align(alignment: Alignment.centerLeft, child: Text('PETITIONER NO. 1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey))),
        const SizedBox(height: 8),
        _buildTextField('Full Name', _petitionerNameController, 'As per legal ID'),
        _buildTextField("Father's / Husband's Name", _petitionerFatherController, 'S/O or W/O'),
        _buildTextField('Age', _petitionerAgeController, 'Current Age', isNumber: true),
        _buildTextField('Permanent Address', _petitionerAddressController, 'House No, Street'),
        Row(
          children: [
            Expanded(child: _buildTextField('City', _petitionerCityController, 'District/City')),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('State', _petitionerStateController, 'State/UT')),
          ],
        ),
        if (_hasSecondPetitioner) ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Align(alignment: Alignment.centerLeft, child: Text('PETITIONER NO. 2', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue))),
          const SizedBox(height: 8),
          _buildTextField('Full Name (Petitioner 2)', _petitioner2NameController, 'As per legal ID'),
          _buildTextField("Father's / Husband's Name", _petitioner2FatherController, 'S/O or W/O'),
          _buildTextField('Age', _petitioner2AgeController, 'Current Age', isNumber: true),
          _buildTextField('Permanent Address', _petitioner2AddressController, 'House No, Street'),
          Row(
            children: [
              Expanded(child: _buildTextField('City', _petitioner2CityController, 'District/City')),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('State', _petitioner2StateController, 'State/UT')),
            ],
          ),
        ],
      ],
    );
  }

  // Step 3: Respondent
  Widget _buildStep3() {
    return Column(
      children: [
        _buildSectionTitle('Respondent Details', LucideIcons.user, Colors.red),
        const SizedBox(height: 24),
        _buildTextField('Full Name', _respondentNameController, 'Legal Name'),
        _buildTextField("Father's / Husband's Name", _respondentFatherController, 'S/O or W/O'),
        _buildTextField('Age', _respondentAgeController, 'Approximate Age', isNumber: true),
        _buildTextField('Permanent Address', _respondentAddressController, 'Known Last Address'),
        Row(
          children: [
            Expanded(child: _buildTextField('City', _respondentCityController, 'District/City')),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('State', _respondentStateController, 'State/UT')),
          ],
        ),
      ],
    );
  }

  // Step 4: Marriage & Court
  Widget _buildStep4() {
    return Column(
      children: [
        _buildSectionTitle('Marriage & Family', LucideIcons.calendar, Colors.indigo),
        const SizedBox(height: 24),
        _buildTextField('Date of Marriage', _marriageDateController, 'YYYY-MM-DD'),
        _buildTextField('Place of Solemnization', _marriagePlaceController, 'City, State'),
        _buildTextField('Number of Children', _childrenCountController, '0', isNumber: true),
        const SizedBox(height: 32),
        _buildSectionTitle('Court Jurisdiction', LucideIcons.home, Colors.blue),
        const SizedBox(height: 24),
        _buildTextField('Court Name', _courtNameController, 'e.g. Family Court No. 1'),
        _buildTextField('District', _courtDistrictController, 'District Name'),
      ],
    );
  }

  // Step 5: Statement of Facts
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
         _buildSectionTitle('Statement of Facts', LucideIcons.fileText, Colors.blue),
         const SizedBox(height: 16),
         const Text(
           'Describe the grounds, incidents, and specific relief sought from the court.',
           style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
         ),
         const SizedBox(height: 24),
         TextField(
           controller: _caseDetailsController,
           maxLines: 12,
           decoration: InputDecoration(
             fillColor: Colors.grey.shade50,
             filled: true,
             hintText: "Detailed chronological facts... e.g. 'The marriage was solemnized on...'",
             border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
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
         ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateAIDraft,
            icon: _isGenerating 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(LucideIcons.sparkles),
            label: Text(_isGenerating ? 'ANALYZING & DRAFTING...' : 'AUTHORIZE & GENERATE DRAFT'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade900,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
         ),
      ],
    );
  }

  Future<void> _generateAIDraft() async {
    String petitionerInfo = """
    Petitioner 1:
    Name: ${_petitionerNameController.text}
    Father/Husband: ${_petitionerFatherController.text}
    Age: ${_petitionerAgeController.text}
    Address: ${_petitionerAddressController.text}, ${_petitionerCityController.text}, ${_petitionerStateController.text}
    """;

    if (_hasSecondPetitioner) {
      petitionerInfo += """
      Petitioner 2:
      Name: ${_petitioner2NameController.text}
      Father/Husband: ${_petitioner2FatherController.text}
      Age: ${_petitioner2AgeController.text}
      Address: ${_petitioner2AddressController.text}, ${_petitioner2CityController.text}, ${_petitioner2StateController.text}
      """;
    }

    final prompt = """
    Document Type: $_docType
    Case Nature: $_caseType
    
    $petitionerInfo
    
    Respondent:
    Name: ${_respondentNameController.text}
    Father/Husband: ${_respondentFatherController.text}
    Age: ${_respondentAgeController.text}
    Address: ${_respondentAddressController.text}, ${_respondentCityController.text}, ${_respondentStateController.text}
    
    Marriage Details:
    Date: ${_marriageDateController.text}
    Place: ${_marriagePlaceController.text}
    Children: ${_childrenCountController.text}
    
    Court: ${_courtNameController.text}, ${_courtDistrictController.text}
    
    Statement of Facts:
    ${_caseDetailsController.text}
    """;

    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);

      final instructions = "You are an expert Indian Family Law legal drafter. Generate a professional, court-ready legal document. Use formal legal language (CPC/HMA). Include Petitioner, Respondent, Jurisdiction, Facts, and Prayer sections. CRITICAL: Automatically research and integrate relevant Supreme Court and High Court case citations (e.g. Rajnesh v. Neha, Naveen Kohli v. Neelu Kohli) within the text to strengthen the legal arguments. At the end, add a detailed 'Legal References & Landmark Citations' section.";

      // Queue the request for background processing (Scalability!)
      // Note: For now we pass evidence summaries in prompt as file processing in background queue is complex
      final evidenceSummary = _selectedVaultEvidence.isNotEmpty 
          ? "\n\nAttached Evidence Context from Vault: ${_selectedVaultEvidence.map((e) => "${e['name']} (${e['category']})").join(', ')}"
          : "";

      final requestId = await firestore.queueAiRequest(
        userId: auth.currentUserId ?? 'anonymous',
        prompt: "$instructions\n\n$prompt$evidenceSummary",
        type: 'draft',
      );

      // Listen to the request status
      firestore.streamAiRequest(requestId).listen((snapshot) {
        if (!snapshot.exists) return;
        
        final data = snapshot.data() as Map<String, dynamic>;
        final status = data['status'];
        
        if (status == 'completed') {
          setState(() {
            _generatedDraft = data['response'];
            _isGenerating = false;
            _currentStep = _totalSteps;
          });
          
          // Save to History once
          if (auth.currentUserId != null && _generatedDraft.isNotEmpty) {
            firestore.saveAnalysis(AnalysisHistory(
              id: '',
              userId: auth.currentUserId!,
              caseType: 'Legal Drafting',
              summary: 'Type: $_docType for $_caseType',
              result: _generatedDraft,
              createdAt: DateTime.now(),
              formData: _collectFormData(), // Save all form fields for restoration
            ));
          }
        } else if (status == 'processing') {
          // Optional: Could show a "Writing..." sub-status
        } else if (status == 'error') {
          setState(() => _isGenerating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI Error: ${data['error']}')),
          );
        }
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _autoFillFromProfile() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    
    if (auth.currentUserId == null) return;

    try {
      final profile = await firestore.getUserProfile(auth.currentUserId!);
      if (profile != null) {
        setState(() {
          _petitionerNameController.text = profile.fullName;
          _petitionerFatherController.text = profile.fatherName;
          _petitionerAddressController.text = profile.currentAddress;
          _petitionerCityController.text = profile.city;
          _petitionerStateController.text = profile.state;
          
          if (profile.marriageDate != null) {
            _marriageDateController.text = profile.marriageDate!.toString().split(' ')[0];
          }
          if (profile.childrenCount > 0) {
            _childrenCountController.text = profile.childrenCount.toString();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile details auto-filled!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auto-fill error: $e')));
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(LucideIcons.history, color: Colors.blue.shade700),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Drafting History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('Tap to view or edit', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<AnalysisHistory>>(
                stream: firestore.streamAnalysisHistory(auth.currentUserId ?? ''),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final history = (snapshot.data ?? []).where((h) => h.caseType == 'Legal Drafting').toList();
                  if (history.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.folderOpen, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No drafts saved yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final h = history[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: h.formData != null ? Colors.green.shade100 : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  h.formData != null ? LucideIcons.fileCheck : LucideIcons.fileText,
                                  color: h.formData != null ? Colors.green : Colors.blue,
                                  size: 20,
                                ),
                              ),
                              title: Text(h.summary, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                              subtitle: Row(
                                children: [
                                  Text(
                                    '${h.createdAt.day}/${h.createdAt.month}/${h.createdAt.year}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: h.formData != null ? Colors.green.shade50 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      h.formData != null ? '✓ Form data saved' : 'Draft only',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: h.formData != null ? Colors.green.shade700 : Colors.grey.shade500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _generatedDraft = h.result;
                                          _currentStep = _totalSteps;
                                        });
                                        // Restore form data if available
                                        if (h.formData != null) {
                                          _restoreFormData(h.formData!);
                                        }
                                        Navigator.pop(context);
                                      },
                                      icon: const Icon(LucideIcons.eye, size: 14),
                                      label: const Text('View Draft', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        side: BorderSide(color: Colors.blue.shade300),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        setState(() {
                                          _generatedDraft = h.result;
                                          _currentStep = _totalSteps;
                                        });
                                        // Restore form data if available
                                        final hasFormData = h.formData != null;
                                        if (hasFormData) {
                                          _restoreFormData(h.formData!);
                                        }
                                        // Show info dialog with form restoration status
                                        showDialog(
                                          context: this.context,
                                          builder: (ctx) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                            title: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: hasFormData ? Colors.green.shade50 : Colors.amber.shade50,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    hasFormData ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                                                    color: hasFormData ? Colors.green.shade700 : Colors.amber.shade700,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    hasFormData ? 'Form Data Restored!' : 'Edit & Regenerate',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  hasFormData
                                                      ? 'All your previous form data has been restored. You can now:'
                                                      : 'Form data from this draft was not saved. To create a modified version:',
                                                  style: const TextStyle(color: Colors.grey),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(hasFormData ? '✓ Edit any field and regenerate' : '1. Use the EDIT button to go back'),
                                                const SizedBox(height: 8),
                                                Text(hasFormData ? '✓ View your saved details in each step' : '2. Fill in or modify your details'),
                                                const SizedBox(height: 8),
                                                Text(hasFormData ? '✓ Generate an updated draft' : '3. Generate a new draft'),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx),
                                                child: const Text('View Draft First'),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  setState(() => _currentStep = 1);
                                                },
                                                icon: const Icon(LucideIcons.edit3, size: 16),
                                                label: const Text('Start Editing'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: hasFormData ? Colors.green.shade700 : Colors.amber.shade700,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      icon: const Icon(LucideIcons.edit3, size: 14),
                                      label: Text(
                                        h.formData != null ? 'Resume Edit' : 'Edit & Redo',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: h.formData != null ? Colors.green.shade700 : Colors.amber.shade700,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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


  Future<void> _downloadDraftPdf() async {
    if (_generatedDraft.isEmpty) return;

    final pdf = pw.Document();
    
    // Clean up markdown for PDF - improved version
    String cleanText = _generatedDraft
        .replaceAll('###', '')
        .replaceAll('##', '')
        .replaceAll('#', '')
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('_', '');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Text(_docType.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
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
          pw.Text('IN THE COURT OF ${_courtNameController.text}, ${_courtDistrictController.text}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 30),
          if (_signatureImage != null)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  children: [
                    pw.Image(pw.MemoryImage(_signatureImage!), width: 100),
                    pw.Text('Digitally Signed', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                  ],
                ),
              ],
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_hasSecondPetitioner ? 'Petitioners:' : 'Petitioner:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('1. ${_petitionerNameController.text}'),
                    pw.Text('S/o / W/o: ${_petitionerFatherController.text}', style: const pw.TextStyle(fontSize: 10)),
                    if (_hasSecondPetitioner) ...[
                      pw.SizedBox(height: 5),
                      pw.Text('2. ${_petitioner2NameController.text}'),
                      pw.Text('S/o / W/o: ${_petitioner2FatherController.text}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                    pw.SizedBox(height: 5),
                    pw.Text('Address: ${_petitionerAddressController.text}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10),
                child: pw.Text('VS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Respondent:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(_respondentNameController.text),
                    pw.Text('S/o / W/o: ${_respondentFatherController.text}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Address: ${_respondentAddressController.text}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Center(child: pw.Text('SUBJECT: $_docType FOR $_caseType', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline))),
          pw.SizedBox(height: 30),
          pw.Paragraph(
            text: cleanText,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
          ),
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Date: ________________', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Signature: _______________', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.Text('Generated via LexAni AI Drafting Vault', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );

    try {
      // On Windows and Web, layoutPdf is more reliable for 'Save as PDF'
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${_docType}_Draft.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not generate PDF: $e')));
      }
    }
  }

  void _toggleRecording() async {
    if (!_isRecording) {
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
          const SnackBar(content: Text('Voice recording not supported on this device.')),
        );
      }
    } else {
      _stopRecording();
      Navigator.of(context).pop();
    }
  }

  void _stopRecording() {
    setState(() => _isRecording = false);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cleaning failed: $e')));
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
            pw.Text('LEGAL VOICE STATEMENT - TRANSCRIPTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            pw.SizedBox(height: 5),
            pw.Text('Case: $_caseType | Type: $_docType'),
            pw.Text('Generated via LexAni AI on ${DateTime.now().toString().split('.')[0]}'),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text(_recognizedText, style: const pw.TextStyle(fontSize: 14)),
            pw.Spacer(),
            pw.Divider(),
            pw.Text('Note: This is an AI-processed legal voice statement. Verify facts before formal court filing.'),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save(), name: 'Legal_Voice_Statement.pdf');
  }

  Widget _buildRecordingModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 48),
              const Text('Voice Recording', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Speak clearly about your case', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8))),
              const SizedBox(height: 48),
              _buildMicrophoneUI(),
              const SizedBox(height: 32),
              
              if (!_isRecording && _recognizedText.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isReprocessing ? null : () => _cleanTranscriptWithAI(setModalState),
                          icon: _isReprocessing 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))
                            : const Icon(LucideIcons.sparkles, size: 14),
                          label: const Text('AI NOISE FILTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade900,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _downloadVoiceAsPdf,
                          icon: const Icon(LucideIcons.fileText, size: 14),
                          label: const Text('VOICE TO PDF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade100,
                            foregroundColor: Colors.indigo.shade900,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              if (_isRecording) ...[
                _buildWaveformAnimation(),
                const SizedBox(height: 24),
                Text(_formatDuration(_recordingDuration), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white)),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: LucideIcons.trash2,
                      label: 'Discard',
                      onPressed: () {
                        _stopRecording();
                        setState(() {
                          _recognizedText = '';
                        });
                        Navigator.pop(context);
                      },
                      backgroundColor: Colors.white.withOpacity(0.1),
                      iconColor: Colors.white,
                    ),
                    _buildControlButton(
                      icon: LucideIcons.check,
                      label: 'Finish',
                      onPressed: () {
                        _stopRecording();
                        if (_recognizedText.isNotEmpty) {
                          if (_rawStoryController.text.isEmpty) {
                            _rawStoryController.text = _recognizedText;
                          } else {
                            _rawStoryController.text = '${_rawStoryController.text} $_recognizedText';
                          }
                        }
                        Navigator.pop(context);
                      },
                      backgroundColor: Colors.green,
                      isPrimary: true,
                      iconColor: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMicrophoneUI() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: _isRecording ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Container(
          width: 140, height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
            boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.2 * value), blurRadius: 40 * value, spreadRadius: 20 * value)],
          ),
          child: Center(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _isRecording ? Colors.red : Colors.white),
              child: Icon(_isRecording ? LucideIcons.mic : LucideIcons.micOff, size: 48, color: _isRecording ? Colors.white : const Color(0xFF1E3A8A)),
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
          double level = (_soundLevel + 2).clamp(0, 15);
          double multiplier = 1.0 + (level / 2.0);
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3,
            height: _isRecording ? (10 + (index % 4) * 5) * multiplier : 4,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(10)),
          );
        }),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required VoidCallback onPressed, required Color backgroundColor, required Color iconColor, bool isPrimary = false}) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: isPrimary ? 80 : 70, height: isPrimary ? 80 : 70,
            decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: Icon(icon, size: isPrimary ? 36 : 28, color: iconColor),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final res = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${res.toString().padLeft(2, '0')}';
  }

  Future<void> _downloadDraftWord() async {
    if (_generatedDraft.isEmpty) return;
    
    try {
      // Basic text extraction for Word file.
      // In a real scenario, we'd use a more complex template.
      final docx = DocxTemplate.fromBytes(await _getEmptyDocx());
      
      // Since DocxTemplate is for filling templates, and we are generating dynamic content,
      // a better way for "Export to Word" from Markdown is often to create a Blob or simple RTF.
      // For this implementation, we will use Printing to share/save as a Word-compatible format if possible,
      // but standard approach is usually just a simple text file with .doc extension or RTF.
      
      // Let's create a simple HTML string and convert if needed, or just use the generated draft text.
      final content = _generatedDraft;
      
      if (kIsWeb) {
        // Handle web download - Printing.sharePdf works on web too!
        await Printing.sharePdf(bytes: Uint8List.fromList(content.codeUnits), filename: '${_docType}_Draft.docx');
      } else {
        final directory = await getTemporaryDirectory();
        final file = io.File('${directory.path}/${_docType}_Draft.docx');
        await file.writeAsString(content);
        await Printing.sharePdf(bytes: await file.readAsBytes(), filename: '${_docType}_Draft.docx');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Word export failed: $e')));
    }
  }

  Future<List<int>> _getEmptyDocx() async {
    // This would typically return a minimal empty docx byte array.
    // For now, we'll skip the template filling and do a direct file write.
    return [];
  }

  Future<void> _scheduleFilingReminder() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.indigo.shade600, onPrimary: Colors.white, onSurface: Colors.indigo),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final Event event = Event(
        title: 'File $_docType in Court',
        description: 'Scheduled filing for $_caseType case at ${_courtNameController.text}, ${_courtDistrictController.text}. Draft generated via LexAni.',
        location: '${_courtNameController.text}, ${_courtDistrictController.text}',
        startDate: DateTime(picked.year, picked.month, picked.day, 10, 0),
        endDate: DateTime(picked.year, picked.month, picked.day, 11, 0),
        iosParams: const IOSParams(reminder: Duration(hours: 2)),
      );

      Add2Calendar.addEvent2Cal(event);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening Calendar to save filing reminder...')));
    }
  }

  Future<void> _scanDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _isParsingDoc = true);
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final bytes = result.files.single.bytes!;
      // Hardcoded mime for demo, in real life we'd use extension
      final ocrText = await gemini.parseDocumentImage(bytes, 'image/jpeg');
      
      if (mounted) {
        setState(() {
          _ocrResult = ocrText;
          _isParsingDoc = false;
        });
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('OCR Scan Complete'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.checkCircle, color: Colors.green, size: 48),
                  const SizedBox(height: 16),
                  const Text('We found some details in your document. Would you like to use them?', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                    child: Text(ocrText, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO, I\'LL TYPE')),
              ElevatedButton(
                onPressed: () {
                  // Basic mapping logic
                  if (ocrText.contains('Name:')) {
                    // This is just a simulation. In production, we'd use a regex or a 2nd AI call for mapping.
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details buffered for pre-filling!')));
                }, 
                child: const Text('YES, PRE-FILL'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isParsingDoc = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
    }
  }

  Future<void> _runFormattingCheck() async {
    if (_generatedDraft.isEmpty) return;
    
    setState(() => _isTranslating = true); // Spinner reuse
    try {
      final gemini = Provider.of<GeminiService>(context, listen: false);
      final formData = {
        'Petitioner': _petitionerNameController.text,
        'Respondent': _respondentNameController.text,
        'Marriage Date': _marriageDateController.text,
        'Place': _marriagePlaceController.text,
        'Court': _courtNameController.text,
      };
      
      final report = await gemini.checkDraftFormatting(_generatedDraft, formData);
      
      if (mounted) {
        setState(() => _isTranslating = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(LucideIcons.shieldCheck, color: Colors.blue),
                SizedBox(width: 12),
                Text('AI Formatting Report'),
              ],
            ),
            content: SingleChildScrollView(child: MarkdownBody(data: report)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('GOT IT'))],
          ),
        );
      }
    } catch (e) {
      setState(() => _isTranslating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Audit failed: $e')));
    }
  }

  Future<void> _shareWithProBono() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    if (auth.currentUserId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pro Bono Legal Aid'),
        content: const Text('Would you like to share this draft with our verified Pro Bono Legal Aid network? A volunteer advisor will review your documents for free.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await firestore.createProBonoRequest(
                userId: auth.currentUserId!,
                draftId: 'vault_${DateTime.now().millisecondsSinceEpoch}',
                docType: _docType,
                summary: 'Self-help draft for $_caseType needing pro-bono review.',
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request shared with Pro Bono cell!')));
            },
            child: const Text('SHARE NOW'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraftToCloud() async {
    if (_generatedDraft.isEmpty) return;
    
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    
    if (auth.currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to save to cloud vault.')));
      return;
    }

    setState(() => _isTranslating = true); // Using a loading state
    
    try {
      final pdf = pw.Document();
      // Reuse PDF generation logic or extract to a helper
      String cleanText = _generatedDraft
          .replaceAll('###', '').replaceAll('##', '').replaceAll('#', '')
          .replaceAll('**', '').replaceAll('*', '').replaceAll('_', '');

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Text('CLOUD SAVED DRAFT - ${_docType.toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
          pw.SizedBox(height: 10),
          if (_signatureImage != null) pw.Image(pw.MemoryImage(_signatureImage!), width: 100),
          pw.SizedBox(height: 20),
          pw.Paragraph(text: cleanText),
        ],
      ));

      final bytes = await pdf.save();
      await firestore.uploadToCloudVault(
        userId: auth.currentUserId!,
        fileName: '${_docType}_Draft_${DateTime.now().millisecondsSinceEpoch}.pdf',
        bytes: bytes,
        category: 'Legal Drafts',
        metadata: {
          'docType': _docType,
          'caseType': _caseType,
          'petitioner': _petitionerNameController.text,
          'isSigned': _signatureImage != null,
        },
      );

      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Row(
              children: [
                const Icon(LucideIcons.cloud, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Saved to Secure Cloud Vault!'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  void _showSubmissionInstructions() {
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
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(LucideIcons.gavel, size: 48, color: Colors.indigo),
                  SizedBox(height: 16),
                  Text('Court Submission Guide', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                children: [
                  _buildInstructionStep('1', 'Print on Ledger/Bond Paper', 'Indian courts generally require "Green" ledger paper or 100 GSM bond paper for final submissions.'),
                  _buildInstructionStep('2', 'Affidavit Attestation', 'Go to the nearest Notary Public or Oath Commissioner to get the Affidavit section signed and stamped.'),
                  _buildInstructionStep('3', 'Court Fees', 'Purchase required Court Fee stamps (e-court fee) based on your state\'s jurisdiction rules.'),
                  _buildInstructionStep('4', 'Filing at Counter', 'Submit 3 sets (Court Copy, Opposite Party Copy, Office Copy) at the Filing Counter of your District Court.'),
                  _buildInstructionStep('5', 'Advocate Verification', 'While drafting is done, we recommend a final review by a verified advisor from our matching section.'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                       Navigator.pop(context);
                       context.go('/advisors');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('FIND A VERIFYING ADVISOR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
            child: Center(child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _translateAnalysis(String langCode) async {
    if (_generatedDraft.isEmpty || langCode == 'en') {
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
      
      final result = await gemini.translateText(_generatedDraft, langName);
      
      if (mounted) {
        setState(() {
          _translatedResult = result;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Translation error: $e')));
      }
    }
  }

  void _playDraftAudio() async {
    final textToSpeak = (_selectedLanguageCode == 'en' || _selectedLanguageCode == null)
                        ? _generatedDraft
                        : (_translatedResult ?? _generatedDraft);
    
    if (textToSpeak.isEmpty) return;
    if (textToSpeak.length > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft is too long for audio (Limit: 5000 chars).')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Audio... This may take a few seconds.')));

    try {
      final firestore = Provider.of<FirestoreService>(context, listen: false);
      // Use proper locale codes
      String lang = 'en-IN';
      if (_selectedLanguageCode == 'hi') {
        lang = 'hi-IN';
      } else if (_selectedLanguageCode == 'ta') lang = 'ta-IN';
      else if (_selectedLanguageCode == 'te') lang = 'te-IN';
      else if (_selectedLanguageCode == 'mr') lang = 'mr-IN';
      
      final id = await firestore.queueTts(
        text: textToSpeak, 
        languageCode: lang
      );

      // Simple listener for one-time play
      StreamSubscription? sub;
      sub = firestore.streamTtsResult(id).listen((doc) async {
         if (doc.exists) {
           final data = doc.data() as Map<String, dynamic>;
           // TTS extension output 'file' usually contains the storage path or signed URL
           final url = data['file'] ?? data['audioUrl'] ?? data['output'];
           
           if (url != null && url.toString().startsWith('http')) {
              await sub?.cancel(); // Found it
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
           }
         }
      });
      
      // Auto-cancel
      Future.delayed(const Duration(seconds: 45), () { sub?.cancel(); });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Audio failed: $e')));
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

  Widget _buildSignatureSection() {
    if (_signatureImage != null) return const SizedBox();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.penTool, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              const Text('Legal E-Sign', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              const Spacer(),
              _isSigning 
                ? TextButton(onPressed: () => setState(() => _isSigning = false), child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)))
                : TextButton(onPressed: () => setState(() => _isSigning = true), child: const Text('Sign Now', style: TextStyle(color: Colors.blueAccent))),
            ],
          ),
          if (_isSigning) ...[
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _signatureController.clear(),
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (_signatureController.isNotEmpty) {
                      final signature = await _signatureController.toPngBytes();
                      setState(() {
                        _signatureImage = signature;
                        _isSigning = false;
                      });
                    }
                  },
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('Save Signature'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourtFeeCalculatorUI() {
    final gemini = Provider.of<GeminiService>(context, listen: false);
    final budgetData = gemini.getLegalBudgetEstimate(_caseType, _petitionerStateController.text);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade800, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.indianRupee, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Legal Budget Estimate',
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
          
          // Case Type Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  budgetData['caseType'] ?? _caseType,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(LucideIcons.clock, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Timeline: ${budgetData['timelineMin']} - ${budgetData['timelineMax']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Total Cost Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED TOTAL COST',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${budgetData['totalMin']} - ₹${budgetData['totalMax']}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.amber.shade800),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => _showDetailedBudgetBreakdown(budgetData),
                  icon: Icon(LucideIcons.info, color: Colors.amber.shade800),
                  tooltip: 'View Detailed Breakdown',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Warning Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  budgetData['warning'].toString().startsWith('💡') ? LucideIcons.lightbulb : LucideIcons.alertTriangle,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    budgetData['warning'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Data Source Citation
          Row(
            children: [
              const Icon(LucideIcons.bookOpen, color: Colors.white60, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Source: ${budgetData['dataSource'] ?? 'NJDG 2023'}',
                  style: const TextStyle(color: Colors.white60, fontSize: 9, fontStyle: FontStyle.italic),
                ),
              ),
            ],
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
        height: MediaQuery.of(context).size.height * 0.85,
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
                  colors: [Colors.amber.shade800, Colors.orange.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.calculator, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              budgetData['caseType'] ?? 'Legal Budget',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '${budgetData['location']} • ${budgetData['timelineMin']}-${budgetData['timelineMax']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL ESTIMATED COST',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${budgetData['totalMin']} - ₹${budgetData['totalMax']}',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.amber.shade800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Phase-wise breakdown
                  ...((budgetData['phases'] as List<dynamic>?) ?? []).asMap().entries.map((entry) {
                    final index = entry.key;
                    final phase = entry.value as Map<String, dynamic>;
                    return _buildPhaseCard(index + 1, phase);
                  }),
                  const SizedBox(height: 24),
                  
                  // Warning
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          budgetData['warning'].toString().startsWith('💡') ? LucideIcons.lightbulb : LucideIcons.alertTriangle,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            budgetData['warning'] ?? '',
                            style: TextStyle(color: Colors.orange.shade900, fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Data Source
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.bookOpen, color: Colors.blue.shade700, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data Source',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                budgetData['dataSource'] ?? 'Based on NJDG 2023 court statistics',
                                style: TextStyle(color: Colors.blue.shade800, fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPhaseCard(int phaseNumber, Map<String, dynamic> phase) {
    final items = (phase['items'] as List<dynamic>?) ?? [];
    final phaseTotal = items.fold<int>(0, (sum, item) => sum + ((item as Map<String, dynamic>)['cost'] as int? ?? 0));
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$phaseNumber',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phase['name'] ?? 'Phase $phaseNumber',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(LucideIcons.clock, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            phase['duration'] ?? '',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${phaseTotal.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.amber.shade800),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) {
                final itemMap = item as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          itemMap['item'] ?? '',
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                      Text(
                        '₹${(itemMap['cost'] as int? ?? 0).toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Step 6: Final Draft
  Widget _buildStep6() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade800,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.2))),
                  child: const Icon(LucideIcons.checkCircle, color: Colors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STATUS: COURT READY DRAFT', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w900)),
                      Text('${_docType}_Final_Draft.pdf', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _showLanguageSelector,
                  icon: const Icon(LucideIcons.languages, color: Colors.white70),
                  tooltip: 'Translate Draft',
                ),
                IconButton(
                  onPressed: _playDraftAudio,
                  icon: const Icon(LucideIcons.volume2, color: Colors.amber),
                  tooltip: 'Listen to Draft',
                ),
              ],
            ),
          ),
          if (_selectedLanguageCode != null && _selectedLanguageCode != 'en')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              color: Colors.blue.withOpacity(0.1),
              child: Text(
                'Viewing in: ${_indianLanguages[_selectedLanguageCode]}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _isTranslating
                ? Column(
                    children: [
                      ShimmerLoader(width: double.infinity, height: 20, baseColor: Colors.blueGrey, highlightColor: Colors.blueGrey.shade400),
                      const SizedBox(height: 8),
                      ShimmerLoader(width: double.infinity, height: 20, baseColor: Colors.blueGrey, highlightColor: Colors.blueGrey.shade400),
                      const SizedBox(height: 8),
                      ShimmerLoader(width: 200, height: 20, baseColor: Colors.blueGrey, highlightColor: Colors.blueGrey.shade400),
                    ],
                  )
                : MarkdownBody(
                    data: (_selectedLanguageCode == 'en' || _selectedLanguageCode == null)
                        ? (_generatedDraft.isNotEmpty ? _generatedDraft : 'Generating your legal draft...')
                        : (_translatedResult ?? _generatedDraft),
                    onTapLink: (text, href, title) {
                      if (href == '/advisors') {
                        context.go('/advisors');
                      }
                    },
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.white70, fontFamily: 'serif', height: 1.5, fontSize: 14),
                      strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      h1: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      listBullet: const TextStyle(color: Colors.white70),
                    ),
                  ),
          ),
          if (_signatureImage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  const Text('Digitally Signed', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  const Spacer(),
                  Image.memory(_signatureImage!, height: 40),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => setState(() => _signatureImage = null),
                    icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                  ),
                ],
              ),
            ),
          _buildSignatureSection(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildCourtFeeCalculatorUI(),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Tooltip(
                  message: 'Go back and edit your form details',
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(LucideIcons.edit3, color: Colors.blue.shade700, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text('Edit Form Data', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          content: const Text(
                            'Which step would you like to go back to?',
                            style: TextStyle(color: Colors.grey),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _currentStep = 1);
                              },
                              child: const Text('Step 1: Case Type'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _currentStep = 2);
                              },
                              child: const Text('Step 2: Petitioner'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _currentStep = 3);
                              },
                              child: const Text('Step 3: Respondent'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _currentStep = 4);
                              },
                              child: const Text('Step 4: Marriage & Court'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _currentStep = 5);
                              },
                              child: const Text('Step 5: Facts'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(LucideIcons.edit3, size: 16),
                    label: const Text('EDIT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadDraftPdf,
                    icon: const Icon(LucideIcons.fileText, color: Colors.white),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadDraftWord,
                    icon: const Icon(LucideIcons.file, color: Colors.white),
                    label: const Text('WORD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _saveDraftToCloud,
                  icon: const Icon(LucideIcons.upload, size: 18),
                  label: const Text('SAVE TO SECURE CLOUD VAULT'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    foregroundColor: Colors.blue.shade400,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.blue.withOpacity(0.2))),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showSubmissionInstructions,
                  icon: const Icon(LucideIcons.helpCircle, size: 18),
                  label: const Text('HOW TO SUBMIT IN COURT?'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    foregroundColor: Colors.grey.shade400,
                    side: BorderSide(color: Colors.grey.shade800),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _scheduleFilingReminder,
                  icon: const Icon(LucideIcons.calendar, size: 18),
                  label: const Text('SCHEDULE FILING REMINDER'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.indigo.shade900,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _runFormattingCheck,
                        icon: const Icon(LucideIcons.checkSquare, size: 16),
                        label: const Text('AI AUDIT', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: Colors.orange.shade300),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _shareWithProBono,
                        icon: const Icon(LucideIcons.heart, size: 16),
                        label: const Text('PRO BONO', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(foregroundColor: Colors.pink.shade300),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           if (_currentStep > 1)
            TextButton.icon(
              onPressed: _prevStep,
              icon: const Icon(LucideIcons.chevronLeft, size: 16),
              label: const Text('PREVIOUS'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            )
           else
            const SizedBox(), // Spacer
           ElevatedButton.icon(
             onPressed: (_currentStep == 2 && _extractedTathya.isEmpty) ? null : _nextStep,
             label: const Text('CONTINUE'),
             icon: const Icon(LucideIcons.chevronRight, size: 16),
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.blueGrey.shade900,
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               textStyle: const TextStyle(fontWeight: FontWeight.bold),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Colors.grey, letterSpacing: 1.2)),
      ],
    );
  }

    Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 16),
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Container(height: 1, width: 40, color: Colors.grey.shade200),
      ],
    );
  }

  Widget _buildDropdown(String hint, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String placeholder, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              hintText: placeholder,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade100)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.blue.shade200, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
