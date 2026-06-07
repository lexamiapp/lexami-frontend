import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _hidePassword = true;

  String _getFriendlyError(String error) {
    final e = error.toLowerCase();
    if (e.contains('invalid-credential') || e.contains('wrong-password') || e.contains('invalid-password')) {
      return 'Incorrect email or password. Please check your credentials and try again.';
    } else if (e.contains('user-not-found') || e.contains('no user record')) {
      return 'No account found with this email address. Please sign up first.';
    } else if (e.contains('invalid-email') || e.contains('badly formatted')) {
      return 'Please enter a valid email address.';
    } else if (e.contains('user-disabled')) {
      return 'This account has been suspended. Please contact support.';
    } else if (e.contains('too-many-requests') || e.contains('too many')) {
      return 'Too many failed attempts. Please wait a moment or reset your password.';
    } else if (e.contains('network') || e.contains('network-request-failed')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (e.contains('email-already-in-use')) {
      return 'An account with this email already exists. Try signing in instead.';
    }
    return e;
  }

  void _showErrorDialog(String message, {bool showSignUp = false}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(LucideIcons.shieldAlert, color: Colors.red.shade600, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sign In Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              if (showSignUp) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/signup');
                  },
                  child: const Text(
                    'Create a new account',
                    style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3B82F6)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog('Please enter both your email address and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await context.read<AuthService>().signIn(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        final msg = _getFriendlyError(e.toString());
        final isNotFound = e.toString().toLowerCase().contains('user-not-found') ||
            e.toString().toLowerCase().contains('no user record');
        _showErrorDialog(msg, showSignUp: isNotFound);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController = TextEditingController();
    
    final outerContext = context;
    return showDialog(
      context: outerContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email address and we\'ll send you a link to reset your password.'),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'your@email.com',
                prefixIcon: const Icon(LucideIcons.mail),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (resetEmailController.text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your email address'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              try {
                await outerContext.read<AuthService>().sendPasswordResetEmail(
                  resetEmailController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(outerContext).showSnackBar(
                    const SnackBar(
                      content: Text('Password reset link sent to your email. Please check your inbox.'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red.shade800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildLoginHeader(),
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
                  const Text('Please sign in to continue your legal journey', style: TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 48),
                  
                  _buildTextField(LucideIcons.mail, 'EMAIL ADDRESS', _emailController),
                  const SizedBox(height: 24),
                  _buildTextField(LucideIcons.lock, 'PASSWORD', _passwordController,  obscure: _hidePassword,),
                  
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3B82F6), fontSize: 12)),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                      TextButton(
                        onPressed: () => context.go('/signup'),
                        child: const Text('SIGN UP', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3B82F6))),
                      ),
                    ],
                  ),
                  
                  if (kIsWeb) ...[
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
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
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginHeader() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(60)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), shape: BoxShape.circle)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                  child: Image.asset('assets/images/logo.png', width: 120, height: 120),
                ),
                const SizedBox(height: 24),
                const Text('LexAni', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4)),
                Text('YOUR LEGAL COMPANION', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(IconData icon, String label, TextEditingController controller, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
            suffixIcon: label == 'PASSWORD'
            ? IconButton(
             icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _hidePassword = !_hidePassword;
            });
          },
        )
      : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
