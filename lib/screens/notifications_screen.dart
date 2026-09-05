import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Map<String, bool> _prefs = {'messages': true, 'groups': true, 'channels': true, 'sound': true};
  String? _userId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    _userId = user.$id;
    try {
      final doc = await AppwriteService.instance.getUserDoc(user.$id);
      setState(() {
        _prefs = AppwriteService.instance.parseNotificationPrefs(doc?.data['notifPrefs']);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _prefs[key] = value);
    if (_userId == null) return;
    try {
      await AppwriteService.instance.updateNotificationPrefs(_userId!, _prefs);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  Widget _switchTile(String key, String label) {
    return SwitchListTile(
      activeColor: AppTheme.cyan,
      title: Text(label, style: AppTheme.body(color: Colors.white)),
      value: _prefs[key] ?? true,
      onChanged: (v) => _set(key, v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _switchTile('messages', 'Message notifications'),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _switchTile('groups', 'Group notifications'),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _switchTile('channels', 'Channel notifications'),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _switchTile('sound', 'Sound'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'These preferences are saved to your account. Actual push delivery requires notification setup, which is not yet enabled for this app.',
                    style: AppTheme.body(size: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
    );
  }
}
