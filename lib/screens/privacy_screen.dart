import 'package:flutter/material.dart';
import '../config/theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline, color: AppTheme.cyan),
                  title: Text('Last Seen & Online', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('Everyone can see when you were last online', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ),
                Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: AppTheme.cyan),
                  title: Text('Profile Photo', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('Everyone can see your profile photo', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ),
                Divider(height: 1, color: AppTheme.surfaceLight),
                ListTile(
                  leading: const Icon(Icons.groups_outlined, color: AppTheme.cyan),
                  title: Text('Groups', style: AppTheme.body(color: Colors.white)),
                  subtitle: Text('Anyone can add you to public groups', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Your account data is stored securely with Appwrite. Messages are only visible to chat participants.',
              style: AppTheme.body(size: 12, color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
