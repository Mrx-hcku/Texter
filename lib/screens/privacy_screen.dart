import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.chat_bubble_outline),
            title: Text('Last Seen & Online'),
            subtitle: Text('Everyone can see when you were last online'),
          ),
          ListTile(
            leading: Icon(Icons.photo_outlined),
            title: Text('Profile Photo'),
            subtitle: Text('Everyone can see your profile photo'),
          ),
          ListTile(
            leading: Icon(Icons.groups_outlined),
            title: Text('Groups'),
            subtitle: Text('Anyone can add you to groups'),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Your account data is stored securely with Appwrite. '
              'Messages are only visible to chat participants.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
