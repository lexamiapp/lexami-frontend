import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class VerificationWaitingScreen extends StatefulWidget {
  const VerificationWaitingScreen({super.key});

  @override
  State<VerificationWaitingScreen> createState() => _VerificationWaitingScreenState();
}

class _VerificationWaitingScreenState extends State<VerificationWaitingScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkVerificationStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerificationStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.reloadUser();
    if (authService.isEmailVerified && mounted) {
      _timer?.cancel();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.mail, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              const Text(
                'Verify Your Email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'We have sent a verification link to:\n${authService.currentUser?.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 32),
              const Text(
                'Waiting for verification...',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey),
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 Tip: Check your Spam or Junk folder',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              TextButton(
                onPressed: () async {
                  await authService.sendEmailVerification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email resent!'))
                    );
                  }
                },
                child: const Text('Resend Verification Email'),
              ),
              TextButton(
                onPressed: () async {
                  await authService.signOut();
                  if (mounted) context.go('/login');
                },
                child: const Text('Cancel & Logout', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
