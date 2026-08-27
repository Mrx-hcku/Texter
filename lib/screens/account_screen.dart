import 'package:flutter/material.dart';
import '../services/appwrite_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();
  String _email = '';
  String? _userId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _userId = user.$id;
    _email = user.email;
    _nameCtrl.text = user.name;
    try {
      final doc = await AppwriteService.instance.getUserDoc(user.$id);
      _statusCtrl.text = doc?.data['status'] ?? '';
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_userId == null || _saving) return;
    setState(() => _saving = true);
    try {
      await AppwriteService.instance.account.updateName(name: _nameCtrl.text.trim());
      await AppwriteService.instance.updateUserProfile(
        userId: _userId!,
        name: _nameCtrl.text.trim(),
        status: _statusCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                  const SizedBox(height: 12),
                  TextField(controller: _statusCtrl, decoration: const InputDecoration(labelText: 'Status / About')),
                  const SizedBox(height: 12),
                  Text('Email: $_email', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ),
    );
  }
}
