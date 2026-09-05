import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'main_nav_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (!email.endsWith('@gmail.com')) {
      setState(() => _error = 'Only Gmail addresses are allowed (e.g. name@gmail.com)');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await AppwriteService.instance.signUp(email, _passCtrl.text.trim(), _nameCtrl.text.trim());
        await AppwriteService.instance.sendVerificationEmail();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
        return;
      } else {
        await AppwriteService.instance.login(email, _passCtrl.text.trim());
      }
      final user = await AppwriteService.instance.getCurrentUser();
      if (!mounted) return;
      if (user != null && !user.emailVerification) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: AppTheme.glowBorder(),
                child: const CircleAvatar(
                  radius: 34,
                  backgroundColor: AppTheme.surfaceLight,
                  child: Icon(Icons.bolt, color: AppTheme.cyan, size: 34),
                ),
              ),
              const SizedBox(height: 16),
              Text('TEXTER', style: AppTheme.heading(size: 36)),
              const SizedBox(height: 6),
              Text(
                _isSignUp ? 'Create your account' : 'Welcome back',
                style: AppTheme.body(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 32),
              if (_isSignUp) ...[
                TextField(
                  controller: _nameCtrl,
                  style: AppTheme.body(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: AppTheme.body(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Gmail Address'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style: AppTheme.body(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: AppTheme.pink, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.bg),
                      )
                    : Text(_isSignUp ? 'Sign Up' : 'Log In'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(
                    _isSignUp ? 'Already have an account? Log In' : "Don't have an account? Sign Up",
                    style: const TextStyle(color: AppTheme.cyan),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
