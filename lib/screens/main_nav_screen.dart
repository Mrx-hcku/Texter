import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'chat_list_screen.dart';
import 'groups_screen.dart';
import 'channels_screen.dart';
import 'profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _index = 0;

  final _screens = const [
    ChatListScreen(),
    GroupsScreen(),
    ChannelsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070B),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E131F),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFF00F0FF).withOpacity(0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            indicatorColor: const Color(0xFF00F0FF).withOpacity(0.2),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline, color: Colors.grey),
                selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF00F0FF)),
                label: 'Chats',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.groups, color: Color(0xFF00F0FF)),
                label: 'Groups',
              ),
              NavigationDestination(
                icon: Icon(Icons.campaign_outlined, color: Colors.grey),
                selectedIcon: Icon(Icons.campaign, color: Color(0xFF00F0FF)),
                label: 'Channels',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, color: Colors.grey),
                selectedIcon: Icon(Icons.person, color: Color(0xFF00F0FF)),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
