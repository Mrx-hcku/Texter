import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../chat_bubble.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../widgets/texter_ui.dart';
import 'channel_view_screen.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String? _photoPath;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await ChatBubble.guard(
      () => picker.pickImage(source: ImageSource.gallery, maxWidth: 640, maxHeight: 640, imageQuality: 80),
    );
    if (x != null && mounted) setState(() => _photoPath = x.path);
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give your channel a name')));
      return;
    }
    setState(() => _creating = true);
    try {
      final me = await AppwriteService.instance.getCurrentUser();
      if (me == null) throw Exception('Please log in again');
      var photoUrl = '';
      if (_photoPath != null) {
        photoUrl = await AppwriteService.instance.uploadFile(_photoPath!, 'channel_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }
      final doc = await AppwriteService.instance.createChannel(
        name: name,
        description: _descController.text.trim(),
        creatorId: me.$id,
        avatarUrl: photoUrl,
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ChannelViewScreen(channelId: doc.$id)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${friendlyError(e)}')));
      setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New channel')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: u.cardAlt,
                      border: Border.all(color: u.border),
                      image: _photoPath == null ? null : DecorationImage(image: FileImage(File(_photoPath!)), fit: BoxFit.cover),
                    ),
                    child: _photoPath == null ? Icon(Icons.campaign_rounded, size: 46, color: u.subtext) : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: kTexterGradient)),
                      child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 19),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: AppTheme.body(color: u.text),
            decoration: const InputDecoration(labelText: 'Channel name'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descController,
            minLines: 2,
            maxLines: 4,
            style: AppTheme.body(color: u.text),
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: u.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: u.accent.withOpacity(0.35))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.campaign_rounded, color: u.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You will be the admin. Only admins can post here — followers can read and react. You can add more admins later from Channel info.',
                    style: AppTheme.body(size: 13, color: u.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Center(child: GradientButton(label: 'Create channel', icon: Icons.rocket_launch_rounded, busy: _creating, onTap: _create, height: 52)),
        ],
      ),
    );
  }
}
