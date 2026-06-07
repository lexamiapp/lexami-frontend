import 'dart:io' as io;
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/advisor_service.dart';
import '../../models/advisor.dart';

class AdvisorRegistrationScreen extends StatefulWidget {
  const AdvisorRegistrationScreen({super.key});

  @override
  State<AdvisorRegistrationScreen> createState() => _AdvisorRegistrationScreenState();
}

class _AdvisorRegistrationScreenState extends State<AdvisorRegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  late BuildContext _dialogContext; // Track dialog context for proper closing

  // ===== STEP 1: Personal Details =====
  final _fullNameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;
  String? _nationality = 'Indian';

  // ===== STEP 2: Professional Details =====
  final _enrollmentNumberController = TextEditingController();
  DateTime? _dateOfEnrollment;
  String? _stateBarCouncil;
  final _barAssociationNameController = TextEditingController();
  final _yearsOfPracticeController = TextEditingController();
  String? _areaOfPractice;

  // ===== STEP 3: Office Details =====
  final _chamberAddressController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();

  // ===== STEP 4: Identification Details =====
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _otherIdController = TextEditingController();

  // ===== STEP 5: Verification Documents =====
  Uint8List? _barCertificateBytes;
  Uint8List? _identityProofBytes;
  Uint8List? _photographBytes;
  Uint8List? _chamberProofBytes;

  String? _barCertificateName;
  String? _identityProofName;
  String? _photographName;
  String? _chamberProofName;

  // ===== STEP 6: Declaration =====
  bool _declarationAgreed = false;
  DateTime? _declarationDate;
  final _declarationPlaceController = TextEditingController();

  // ===== STEP 7: Verification by Authority =====
  final _authorityNameController = TextEditingController();
  final _designationController = TextEditingController();
  DateTime? _authorityDate;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _stateBarCouncils = [
    'Maharashtra', 'Delhi', 'Karnataka', 'Tamil Nadu', 'Uttar Pradesh',
    'West Bengal', 'Gujarat', 'Punjab', 'Rajasthan', 'Haryana', 'Madhya Pradesh'
  ];
  final List<String> _practiceAreas = [
    'Divorce', 'Child Custody', 'Alimony', 'Domestic Violence',
    'Property Dispute', 'Maintenance', 'Criminal Law', 'Corporate Law', 'Family Law'
  ];

  Future<void> _pickDocument(String docType) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        switch (docType) {
          case 'bar_certificate':
            _barCertificateBytes = result.files.first.bytes;
            _barCertificateName = result.files.first.name;
            break;
          case 'identity_proof':
            _identityProofBytes = result.files.first.bytes;
            _identityProofName = result.files.first.name;
            break;
          case 'photograph':
            _photographBytes = result.files.first.bytes;
            _photographName = result.files.first.name;
            break;
          case 'chamber_proof':
            _chamberProofBytes = result.files.first.bytes;
            _chamberProofName = result.files.first.name;
            break;
        }
      });
    }
  }

  void _submitRegistration() async {
    // Validate all fields
    if (_fullNameController.text.isEmpty || _dateOfBirth == null || _gender == null) {
      _showError('Please fill all personal details');
      return;
    }
    if (_enrollmentNumberController.text.isEmpty || _dateOfEnrollment == null || _stateBarCouncil == null) {
      _showError('Please fill all professional details');
      return;
    }
    if (_chamberAddressController.text.isEmpty || _contactNumberController.text.isEmpty || _emailController.text.isEmpty) {
      _showError('Please fill all office details');
      return;
    }
    if (_aadhaarController.text.isEmpty && _panController.text.isEmpty) {
      _showError('Please provide at least Aadhaar or PAN');
      return;
    }
    if (_declarationAgreed == false) {
      _showError('Please agree to the declaration');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final uid = auth.currentUserId!;
      final userEmail = auth.currentUser?.email ?? _emailController.text;

      // Show progress dialog with timeout
      _showProgressDialog('Processing documents...');

      // Convert documents to Base64 (no upload needed)
      String? barCertificate;
      String? identityProof;
      String? photograph;
      String? chamberProof;

      try {
        if (_barCertificateBytes != null) {
          print('Converting bar certificate to base64 (${_barCertificateBytes!.length} bytes)...');
          barCertificate = base64Encode(_barCertificateBytes!);
          print('✓ Bar certificate ready: ${barCertificate.length} chars');
        }
        if (_identityProofBytes != null) {
          print('Converting identity proof to base64 (${_identityProofBytes!.length} bytes)...');
          identityProof = base64Encode(_identityProofBytes!);
          print('✓ Identity proof ready: ${identityProof.length} chars');
        }
        if (_photographBytes != null) {
          print('Converting photograph to base64 (${_photographBytes!.length} bytes)...');
          photograph = base64Encode(_photographBytes!);
          print('✓ Photograph ready: ${photograph.length} chars');
        }
        if (_chamberProofBytes != null) {
          print('Converting chamber proof to base64 (${_chamberProofBytes!.length} bytes)...');
          chamberProof = base64Encode(_chamberProofBytes!);
          print('✓ Chamber proof ready: ${chamberProof.length} chars');
        }
      } catch (uploadError) {
        print('❌ Document conversion error: $uploadError');
        throw Exception('Document conversion failed: $uploadError');
      }

      // Update progress dialog
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        _showProgressDialog('Submitting to server...');
      }

      // Create advisor registration data
      final advisorData = {
        'uid': uid,
        'email': userEmail,

        // Step 1: Personal Details
        'fullName': _fullNameController.text,
        'fatherName': _fatherNameController.text,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'gender': _gender,
        'nationality': _nationality,

        // Step 2: Professional Details
        'enrollmentNumber': _enrollmentNumberController.text,
        'dateOfEnrollment': _dateOfEnrollment?.toIso8601String(),
        'stateBarCouncil': _stateBarCouncil,
        'barAssociationName': _barAssociationNameController.text,
        'yearsOfPractice': int.tryParse(_yearsOfPracticeController.text) ?? 0,
        'areaOfPractice': _areaOfPractice,

        // Step 3: Office Details
        'chamberAddress': _chamberAddressController.text,
        'contactNumber': _contactNumberController.text,
        'emailId': _emailController.text,

        // Step 4: Identification Details
        'aadhaarNumber': _aadhaarController.text,
        'panNumber': _panController.text,
        'otherIdNumber': _otherIdController.text,

        // Step 5: Verification Documents (Base64 encoded)
        'barCertificate': barCertificate,
        'identityProof': identityProof,
        'photograph': photograph,
        'chamberProof': chamberProof,

        // Step 6: Declaration
        'declarationAgreed': _declarationAgreed,
        'declarationDate': _declarationDate?.toIso8601String(),
        'declarationPlace': _declarationPlaceController.text,

        // Step 7: Verification by Authority (Optional)
        'authorityName': _authorityNameController.text,
        'designation': _designationController.text,
        'authorityDate': _authorityDate?.toIso8601String(),

        // Admin fields
        'verificationStatus': 'pending',
        'appliedAt': DateTime.now().toIso8601String(),
        'isVerified': false,
      };

      print('Sending registration data to MongoDB backend...');
      await AdvisorService.submitAdvisorOnboarding(advisorData)
          .timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('Backend submission timeout - server not responding');
      });
      print('✓ Registration submitted successfully to MongoDB');

      if (mounted) {
        // Close progress dialog using its own context
        Navigator.pop(_dialogContext);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Registration submitted successfully! Awaiting verification.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Navigate back to home after short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context); // Pop registration screen
          }
        });
      }
    } catch (e) {
      print('ERROR during registration: $e');
      if (mounted) {
        Navigator.pop(_dialogContext); // Close progress dialog using its context
      }
      String errorMessage = 'Registration failed';
      if (e.toString().contains('TimeoutException')) {
        errorMessage = '⏱️ Request timed out. Check your internet connection and try again.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = '🔌 Internet connection error. Check your connection.';
      } else if (e.toString().contains('Certificate')) {
        errorMessage = '🔒 SSL Certificate error. Try again in a moment.';
      } else {
        errorMessage = '❌ Error: ${e.toString()}';
      }
      _showError(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showProgressDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        _dialogContext = dialogContext; // Store dialog context for closing
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Please keep the app open and maintain internet connection',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Advisor Onboarding', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Theme(
              data: Theme.of(context).copyWith(
                useMaterial3: false,
                canvasColor: Colors.white,
              ),
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 6) {
                    setState(() => _currentStep++);
                  } else {
                    _submitRegistration();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) setState(() => _currentStep--);
                },
                steps: [
                  _buildStep1PersonalDetails(),
                  _buildStep2ProfessionalDetails(),
                  _buildStep3OfficeDetails(),
                  _buildStep4IdentificationDetails(),
                  _buildStep5VerificationDocuments(),
                  _buildStep6Declaration(),
                  _buildStep7AuthorityVerification(),
                ],
              ),
            ),
    );
  }

  Step _buildStep1PersonalDetails() {
    return Step(
      title: const Text('Personal Details', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Full Name, DOB, Gender, Nationality'),
      isActive: _currentStep >= 0,
      content: Column(
        children: [
          TextField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: 'Full Name of Advocate *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.user),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fatherNameController,
            decoration: InputDecoration(
              labelText: "Father's / Husband's Name *",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.user),
            ),
          ),
          const SizedBox(height: 12),
          // Date of Birth
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime(1980),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _dateOfBirth = date);
            },
            icon: const Icon(LucideIcons.calendar),
            label: Text(_dateOfBirth == null ? 'Select Date of Birth *' : DateFormat('dd-MM-yyyy').format(_dateOfBirth!)),
          ),
          const SizedBox(height: 12),
          // Gender
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: InputDecoration(
              labelText: 'Gender *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.users),
            ),
            items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (val) => setState(() => _gender = val),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: _nationality),
            decoration: InputDecoration(
              labelText: 'Nationality *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.globe),
            ),
            onChanged: (val) => _nationality = val,
          ),
        ],
      ),
    );
  }

  Step _buildStep2ProfessionalDetails() {
    return Step(
      title: const Text('Professional Details', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Enrollment, Bar Council, Practice Area'),
      isActive: _currentStep >= 1,
      content: Column(
        children: [
          TextField(
            controller: _enrollmentNumberController,
            decoration: InputDecoration(
              labelText: 'Enrollment Number (Bar Council) *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.hash),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dateOfEnrollment ?? DateTime.now(),
                firstDate: DateTime(1980),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _dateOfEnrollment = date);
            },
            icon: const Icon(LucideIcons.calendar),
            label: Text(_dateOfEnrollment == null ? 'Select Date of Enrollment *' : DateFormat('dd-MM-yyyy').format(_dateOfEnrollment!)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _stateBarCouncil,
            decoration: InputDecoration(
              labelText: 'State Bar Council *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _stateBarCouncils.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) => setState(() => _stateBarCouncil = val),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barAssociationNameController,
            decoration: InputDecoration(
              labelText: 'Bar Association Name *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _yearsOfPracticeController,
            decoration: InputDecoration(
              labelText: 'Years of Practice *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.briefcase),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _areaOfPractice,
            decoration: InputDecoration(
              labelText: 'Area of Practice *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _practiceAreas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
            onChanged: (val) => setState(() => _areaOfPractice = val),
          ),
        ],
      ),
    );
  }

  Step _buildStep3OfficeDetails() {
    return Step(
      title: const Text('Office Details', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Address, Contact, Email'),
      isActive: _currentStep >= 2,
      content: Column(
        children: [
          TextField(
            controller: _chamberAddressController,
            decoration: InputDecoration(
              labelText: 'Chamber/Office Address *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.mapPin),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contactNumberController,
            decoration: InputDecoration(
              labelText: 'Contact Number *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email ID *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.mail),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
    );
  }

  Step _buildStep4IdentificationDetails() {
    return Step(
      title: const Text('Identification Details', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Aadhaar, PAN, Voter ID'),
      isActive: _currentStep >= 3,
      content: Column(
        children: [
          TextField(
            controller: _aadhaarController,
            decoration: InputDecoration(
              labelText: 'Aadhaar Number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.shield),
              helperText: 'Enter last 4 digits visibly, mask earlier digits',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _panController,
            decoration: InputDecoration(
              labelText: 'PAN Number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.creditCard),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _otherIdController,
            decoration: InputDecoration(
              labelText: 'Voter ID / Other ID',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.creditCard),
            ),
          ),
        ],
      ),
    );
  }

  Step _buildStep5VerificationDocuments() {
    return Step(
      title: const Text('Verification Documents', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Upload certificates and proofs'),
      isActive: _currentStep >= 4,
      content: Column(
        children: [
          _buildDocumentUploadTile('Bar Council Enrollment Certificate', _barCertificateName, 'bar_certificate'),
          const SizedBox(height: 12),
          _buildDocumentUploadTile('Identity Proof (Aadhaar/PAN/Voter ID)', _identityProofName, 'identity_proof'),
          const SizedBox(height: 12),
          _buildDocumentUploadTile('Passport Size Photograph', _photographName, 'photograph'),
          const SizedBox(height: 12),
          _buildDocumentUploadTile('Chamber Address Proof', _chamberProofName, 'chamber_proof'),
        ],
      ),
    );
  }

  Step _buildStep6Declaration() {
    return Step(
      title: const Text('Declaration by Advocate', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Legal declaration and signature'),
      isActive: _currentStep >= 5,
      content: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Text(
              'I hereby declare that the information provided above is true and correct to the best of my knowledge and belief.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _declarationDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _declarationDate = date);
            },
            icon: const Icon(LucideIcons.calendar),
            label: Text(_declarationDate == null ? 'Select Date of Declaration *' : DateFormat('dd-MM-yyyy').format(_declarationDate!)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _declarationPlaceController,
            decoration: InputDecoration(
              labelText: 'Place of Declaration *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.mapPin),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('I agree to the declaration above *'),
            value: _declarationAgreed,
            onChanged: (val) => setState(() => _declarationAgreed = val!),
            activeColor: Colors.blue.shade700,
          ),
        ],
      ),
    );
  }

  Step _buildStep7AuthorityVerification() {
    return Step(
      title: const Text('Authority Verification (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: const Text('Verified by authority stamp/seal'),
      isActive: _currentStep >= 6,
      content: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'This section is optional and will be filled by the verifying authority.',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
          TextField(
            controller: _authorityNameController,
            decoration: InputDecoration(
              labelText: 'Name of Verifying Authority',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.user),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _designationController,
            decoration: InputDecoration(
              labelText: 'Designation',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(LucideIcons.briefcase),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _authorityDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _authorityDate = date);
            },
            icon: const Icon(LucideIcons.calendar),
            label: Text(_authorityDate == null ? 'Select Authority Date' : DateFormat('dd-MM-yyyy').format(_authorityDate!)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(LucideIcons.send),
              label: const Text('Submit Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadTile(String title, String? fileName, String docType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (fileName != null)
                  Text(fileName, style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w500))
                else
                  Text('No file attached', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(fileName != null ? LucideIcons.checkCircle : LucideIcons.upload, color: fileName != null ? Colors.green : Colors.grey),
            onPressed: () => _pickDocument(docType),
          ),
        ],
      ),
    );
  }
}
