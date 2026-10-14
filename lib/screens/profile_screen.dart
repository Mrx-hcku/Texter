import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Professional Feedback SnackBar
  void _copyUsername() {
    Clipboard.setData(ClipboardData(text: '@$_name'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Username copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surfaceLight,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Lightweight Professional ID Card Dialog (No external QR library needed)
  void _showProfileCard() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.surfaceLight,
                backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
                child: _avatarUrl.isEmpty ? Text(_name.isNotEmpty ? _name[0].toUpperCase() : '?', style: AppTheme.heading(size: 24)) : null,
              ),
              const SizedBox(height: 16),
              Text('@$_name', style: AppTheme.heading(size: 18, color: Colors.white)),
              const SizedBox(height: 4),
              Text(_email, style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_user, color: AppTheme.cyan, size: 28),
                    const SizedBox(height: 8),
                    Text('Secure Verified Account', style: AppTheme.body(size: 12, color: AppTheme.cyan, weight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyan,
                    foregroundColor: AppTheme.bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_outlined, color: AppTheme.cyan),
            onPressed: _showProfileCard,
            tooltip: 'View ID Card',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppTheme.surfaceLight,
                            backgroundImage: _avatarUrl.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl) : null,
                            onBackgroundImageError: _avatarUrl.isNotEmpty ? (_, __) {} : null,
                            child: _avatarUrl.isEmpty
                                ? Text(
                                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                                    style: AppTheme.heading(size: 32, color: Colors.white70),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: AppTheme.cyan, shape: BoxShape.circle),
                              child: const Icon(Icons.verified, size: 14, color: AppTheme.bg),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _copyUsername,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('@$_name', style: AppTheme.heading(size: 18)),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded, size: 14, color: AppTheme.cyan),
                            ],
                          ),
                        ),
                      ),
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
                      _tile(Icons.lock_outline, 'Privacy & Security', onTap: () {
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
