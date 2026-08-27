import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
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
  String _avatarUrl = '';
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

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
      _avatarUrl = doc?.data['avatarUrl'] ?? '';
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    if (_userId == null || _uploadingPhoto) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await AppwriteService.instance.uploadFile(file.path, file.name);
      await AppwriteService.instance.updateUserProfile(userId: _userId!, avatarUrl: url);
      setState(() => _avatarUrl = url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload photo: $e')));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
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
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppTheme.primary,
                            backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
                            child: _avatarUrl.isEmpty
                                ? Text(
                                    _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                              child: _uploadingPhoto
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
