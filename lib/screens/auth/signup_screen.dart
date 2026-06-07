import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/user_profile.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  
  String _gender = 'Male';
  final String _maritalStatus = 'Married';
  String _disputeNature = 'Divorce';
  bool _obscurePassword = true;
  String? _passwordError;

  String? _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (password.length > 12) return 'Password must be at most 12 characters.';
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Must contain at least one number (0–9).';
    if (!RegExp(r'[@$^&*!#%?]').hasMatch(password)) return 'Must contain at least one special character (@\$^&*!#%?).';
    return null;
  }

  bool _validateStep0() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !RegExp(r'^[\w.+-]+@[\w-]+\.[a-z]{2,}$', caseSensitive: false).hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid email address.'),
        backgroundColor: Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ));
      return false;
    }

    final pwError = _validatePassword(password);
    if (pwError != null) {
      setState(() => _passwordError = pwError);
      return false;
    }

    setState(() => _passwordError = null);
    return true;
  }

  Future<void> _signUp() async {
    if (!_validateStep0()) return;
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    try {
      final user = await authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // Create User Profile in Firestore
        final profile = UserProfile(
          uid: user.uid,
          fullName: _nameController.text,
          email: _emailController.text.trim(),
          mobile: _mobileController.text,
          gender: _gender,
          fatherName: _fatherNameController.text,
          motherName: _motherNameController.text,
          maritalStatus: _maritalStatus,
          roleInFamily: 'Head of Family',
          currentAddress: _addressController.text,
          city: _cityController.text,
          state: _stateController.text,
          country: 'India',
          disputeNature: _disputeNature,
          relationshipWithOtherParty: '',
          consentTrue: true,
          isProfileComplete: true,
        );

        // Await profile creation as it's critical, but don't wait for email trigger to finish
        // to avoid perceived lag from Firebase's email servers.
        await firestoreService.createUserProfile(profile);
        authService.sendEmailVerification(); // Fire and forget
        
        if (mounted) context.go('/verify-email');
      }
    } catch (e) {
      final raw = e.toString();
      final lower = raw.toLowerCase();
      final msg = lower.contains('email-already-in-use')
          ? 'An account with this email already exists. Please sign in instead.'
          : lower.contains('weak-password')
              ? 'Password is too weak. Use at least 6 characters.'
              : lower.contains('invalid-email')
                  ? 'Invalid email address.'
                  : lower.contains('network')
                      ? 'Network error. Please check your connection and try again.'
                      : raw;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Account', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: _isLoading 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Color(0xFF1E293B)),
                const SizedBox(height: 24),
                const Text('Securing your profile...', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                Text('Connecting to LexAni servers', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          )
        : SingleChildScrollView(
            child: Column(
              children: [
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: Color(0xFF1E293B)),
                  ),
                  child: Stepper(
                    type: StepperType.vertical,
                    currentStep: _currentStep,
                    onStepContinue: () {
                      if (_currentStep == 0) {
                        if (_validateStep0()) setState(() => _currentStep = 1);
                      } else if (_currentStep < 2) {
                        setState(() => _currentStep += 1);
                      } else {
                        _signUp();
                      }
                    },
                    onStepCancel: () {
                      if (_currentStep > 0) {
                        setState(() => _currentStep -= 1);
                      }
                    },
                    controlsBuilder: (context, details) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Row(
                          children: [
                            ElevatedButton(
                              onPressed: details.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(_currentStep == 2 ? 'COMPLETE SIGNUP' : 'CONTINUE', style: const TextStyle(fontWeight: FontWeight.w900)),
                            ),
                            if (_currentStep > 0)
                              TextButton(
                                onPressed: details.onStepCancel,
                                child: const Text('BACK', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey)),
                              ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      Step(
                        title: const Text('ACCOUNT ACCESS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                        subtitle: const Text('Email and secure password'),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            _buildSignUpField(LucideIcons.mail, 'EMAIL', _emailController),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              onChanged: (_) {
                                if (_passwordError != null) {
                                  setState(() => _passwordError = _validatePassword(_passwordController.text));
                                }
                              },
                              decoration: _inputDecoration(LucideIcons.lock, 'PASSWORD').copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.blueGrey,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                errorText: _passwordError,
                                errorMaxLines: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPasswordRules(),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('PERSONAL PROFILE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                        subtitle: const Text('Your identity and contact info'),
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                        content: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildSignUpField(LucideIcons.user, 'FULL NAME', _nameController),
                            const SizedBox(height: 16),
                            _buildSignUpField(LucideIcons.phone, 'MOBILE NUMBER', _mobileController),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              decoration: _inputDecoration(LucideIcons.userCheck, 'GENDER'),
                              items: ['Male', 'Female', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                              onChanged: (val) => setState(() => _gender = val!),
                            ),
                          ],
                        ),
                      ),
                      Step(
                        title: const Text('LEGAL CONTEXT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                        subtitle: const Text('Help us understand your situation'),
                        isActive: _currentStep >= 2,
                        content: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildSignUpField(LucideIcons.users, 'FATHER\'S NAME', _fatherNameController),
                            const SizedBox(height: 16),
                            _buildSignUpField(LucideIcons.mapPin, 'CURRENT ADDRESS', _addressController),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _disputeNature,
                              decoration: _inputDecoration(LucideIcons.scale, 'NATURE OF DISPUTE'),
                              items: ['Divorce', 'Property', 'Custody', 'Alimony', 'Maintenance'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                              onChanged: (val) => setState(() => _disputeNature = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (kIsWeb) ...[
                  const SizedBox(height: 48),
                  const Text('Better experience on Android?', style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('https://lexani-5df0d.web.app/app-release.apk')),
                    icon: const Icon(Icons.android, color: Colors.green),
                    label: const Text('Download LexAni APK', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
    );
  }

  Widget _buildSignUpField(IconData icon, String label, TextEditingController controller, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontWeight: FontWeight.bold),
      decoration: _inputDecoration(icon, label),
    );
  }

  InputDecoration _inputDecoration(IconData icon, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    );
  }

  Widget _buildPasswordRules() {
    final password = _passwordController.text;
    final hasLength = password.length >= 8 && password.length <= 12;
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[@$^&*!#%?]').hasMatch(password);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PASSWORD REQUIREMENTS',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          _buildRule(hasLength, '8–12 characters'),
          _buildRule(hasNumber, 'At least one number (0–9)'),
          _buildRule(hasSpecial, r'At least one special character (@$^&*!#%?)'),
        ],
      ),
    );
  }

  Widget _buildRule(bool met, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? Colors.green.shade600 : const Color(0xFFCBD5E1),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: met ? Colors.green.shade700 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
