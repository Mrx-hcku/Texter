import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import 'login_screen.dart';
import 'account_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  String _avatarUrl = '';
  String _status = '';
  int _groupCount = 0;
  int _channelCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await AppwriteService.instance.getCurrentUser();
    if (user == null) return;
    setState(() {
      _name = user.name;
      _email = user.email;
    });
    try {
      final doc = await AppwriteService.instance.getUserDoc(user.$id);
      final groups = await AppwriteService.instance.getGroups();
      final channels = await AppwriteService.instance.getChannels();
      if (!mounted) return;
      setState(() {
        _avatarUrl = doc?.data['avatarUrl'] ?? '';
        _status = doc?.data['status'] ?? '';
        _groupCount = groups.where((g) => List<String>.from(g.data['memberIds'] ?? []).contains(user.$id)).length;
        _channelCount = channels.where((c) => List<String>.from(c.data['subscriberIds'] ?? []).contains(user.$id)).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AppwriteService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _statCard(String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Column(
          children: [
            Text(value, style: AppTheme.heading(size: 20, color: AppTheme.cyan)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.body(size: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _tile(IconData icon, String label, {VoidCallback? onTap, Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.cyan),
      title: Text(label, style: AppTheme.body(color: color ?? Colors.white, weight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: AppTheme.glowBorder(),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: AppTheme.surfaceLight,
                          backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
                          child: _avatarUrl.isEmpty
                              ? Text(
                                  _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                                  style: AppTheme.heading(size: 32, color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('@$_name', style: AppTheme.heading(size: 18)),
                      const SizedBox(height: 4),
                      Text(
                        _status.isNotEmpty ? _status : _email,
                        style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _statCard('$_groupCount', 'Groups'),
                    _statCard('$_channelCount', 'Channels'),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _tile(Icons.account_circle_outlined, 'Account', onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
                        _load();
                      }),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _tile(Icons.notifications_outlined, 'Notifications', onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      }),
                      Divider(height: 1, color: AppTheme.surfaceLight),
                      _tile(Icons.lock_outline, 'Privacy', onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
                  child: _tile(Icons.logout, 'Logout', color: AppTheme.pink, onTap: _logout),
                ),
              ],
            ),
    );
  }
}
