import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'channels_screen.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _creating = false;

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _creating) return;
    setState(() => _creating = true);
    final me = await AppwriteService.instance.getCurrentUser();
    if (me == null) return;
    await AppwriteService.instance.createChannel(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      creatorId: me.$id,
    );
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChannelsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Channel'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: const Text('Create', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              style: AppTheme.body(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Channel Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              style: AppTheme.body(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
          ],
        ),
      ),
    );
  }
}
