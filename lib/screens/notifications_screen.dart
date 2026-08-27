import 'package:flutter/material.dart';
import '../config/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _messageNotifs = true;
  bool _groupNotifs = true;
  bool _channelNotifs = true;
  bool _sound = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          SwitchListTile(
            activeColor: AppTheme.primary,
            title: const Text('Message notifications'),
            value: _messageNotifs,
            onChanged: (v) => setState(() => _messageNotifs = v),
          ),
          SwitchListTile(
            activeColor: AppTheme.primary,
            title: const Text('Group notifications'),
            value: _groupNotifs,
            onChanged: (v) => setState(() => _groupNotifs = v),
          ),
          SwitchListTile(
            activeColor: AppTheme.primary,
            title: const Text('Channel notifications'),
            value: _channelNotifs,
            onChanged: (v) => setState(() => _channelNotifs = v),
          ),
          SwitchListTile(
            activeColor: AppTheme.primary,
            title: const Text('Sound'),
            value: _sound,
            onChanged: (v) => setState(() => _sound = v),
          ),
        ],
      ),
    );
  }
}
