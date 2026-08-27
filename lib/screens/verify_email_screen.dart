import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'main_nav_screen.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with WidgetsBindingObserver {
  bool _resending = false;
  String _email = '';
  Timer? _pollTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEmail();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerified();
    }
  }

  Future<void> _loadEmail() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user != null && mounted) setState(() => _email = user.email);
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await AppwriteService.instance.sendVerificationEmail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _checkVerified() async {
    if (_navigated) return;
    final user = await AppwriteService.instance.getCurrentUser();
    if (!mounted || _navigated) return;
    if (user != null && user.emailVerification) {
      _navigated = true;
      _pollTimer?.cancel();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 80, color: AppTheme.primary),
              const SizedBox(height: 20),
              const Text('Verify your Gmail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                "We sent a verification link to $_email. Open Gmail, tap the link — this screen will continue automatically once verified.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(_resending ? 'Sending...' : 'Resend email'),
              ),
              TextButton(
                onPressed: () async {
                  await AppwriteService.instance.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Use a different account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
