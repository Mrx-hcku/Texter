import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _appLockEnabled = false;
  String _cacheSize = 'Calculating...';
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _calculateCacheSize();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', value);
    setState(() => _appLockEnabled = value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value ? 'Secure App Lock Enabled' : 'App Lock Disabled'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.surfaceLight,
      ),
    );
  }

  Future<void> _calculateCacheSize() async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      int totalSize = _getDirectorySize(tempDir);
      
      setState(() {
        _cacheSize = '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
      });
    } catch (_) {
      setState(() => _cacheSize = '0.00 MB');
    }
  }

  int _getDirectorySize(Directory dir) {
    int size = 0;
    try {
      if (dir.existsSync()) {
        List<FileSystemEntity> children = dir.listSync(recursive: true);
        for (FileSystemEntity child in children) {
          if (child is File) {
            size += child.lengthSync();
          }
        }
      }
    } catch (_) {}
    return size;
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    try {
      Directory tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
        tempDir.createSync();
      }
      await _calculateCacheSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temporary cache cleared successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: AppTheme.cyan,
                  secondary: const Icon(Icons.lock_person_outlined, color: AppTheme.cyan),
                  title: Text('Quick App Lock', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('Lock app interface on background', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                  value: _appLockEnabled,
                  onChanged: _toggleAppLock,
                ),
                Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  leading: const Icon(Icons.visibility_outlined, color: AppTheme.cyan),
                  title: Text('Last Seen & Online', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('only your chat partner can see your status', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ),
                Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.cyan),
                  title: Text('Profile Photo Visibility', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('Visible to only you are chatting with', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_outlined, color: AppTheme.cyan),
              title: Text('Storage & Cache', style: AppTheme.body(color: Colors.white)),
              subtitle: Text('App cache size: $_cacheSize', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
              trailing: _isClearingCache
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan))
                  : TextButton(
                      onPressed: _clearCache,
                      child: const Text('Clear', style: TextStyle(color: AppTheme.pink, fontWeight: FontWeight.bold)),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Your application data is synchronized securely with Appwrite backend.',
              style: AppTheme.body(size: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
