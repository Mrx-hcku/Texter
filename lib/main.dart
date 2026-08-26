import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';

void main() {
  runApp(const MessgramApp());
}

class MessgramApp extends StatelessWidget {
  const MessgramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Messgram',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF00897B),
        scaffoldBackgroundColor: const Color(0xFFF7F9F9),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Messgram", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF00897B))),
                const SizedBox(height: 5),
                const Text("Welcome to Messgram", style: TextStyle(fontSize: 15, color: Colors.grey)),
                const SizedBox(height: 30),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Phone Number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: const Icon(Icons.visibility_off),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigationScreen()));
                    },
                    child: const Text('Log In', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 15),
                const Text("Or", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF00897B))),
                    onPressed: () {},
                    child: const Text('Sign Up', style: TextStyle(color: Color(0xFF00897B), fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ChatListScreen(),
    const GroupsScreen(),
    const ChannelsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF00897B),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Groups'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Channels'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00897B),
        actions: [IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () {})],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          ListTile(
            leading: Stack(
              children: [
                const CircleAvatar(backgroundColor: Color(0xFF00897B), child: Icon(Icons.person, color: Colors.white)),
                Positioned(bottom: 0, right: 0, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))),
              ],
            ),
            title: const Text('Amit Sharma', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Last Message - Amit Sharma'),
            trailing: const Text('1:15 AM', style: TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OneToOneChatScreen())),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.group, color: Colors.white)),
            title: const Text('Design Group', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Last Message - Design Group'),
            trailing: const Text('1:45 AM', style: TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GroupChatWithAdsScreen())),
          ),
        ],
      ),
    );
  }
}

class OneToOneChatScreen extends StatelessWidget {
  const OneToOneChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        title: Row(
          children: [
            const CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF00897B))),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Amit Sharma', style: TextStyle(fontSize: 16, color: Colors.white)),
                Text('Online • Typing...', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF00897B), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Hello! Are you there?', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: const Text('White message received', style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.image, color: Colors.grey),
                const SizedBox(width: 8),
                const Icon(Icons.camera_alt, color: Colors.grey),
                const SizedBox(width: 8),
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(hintText: 'Message here File', border: InputBorder.none),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF00897B)), onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GroupChatWithAdsScreen extends StatelessWidget {
  const GroupChatWithAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Design Team', style: TextStyle(fontSize: 16, color: Colors.white)),
            Text('28 subscribers', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: 4,
        itemBuilder: (context, index) {
          if (index == 1) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TechCorp Laptop", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Sponsored", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 110,
                    width: double.infinity,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.laptop, size: 50, color: Colors.teal)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B)),
                      onPressed: () {},
                      child: const Text('Shop Now', style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            );
          }
          return const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('Team Member'),
            subtitle: Text('Message inside group stream...'),
          );
        },
      ),
    );
  }
}

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("Groups Screen")));
}

class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text("Channels Screen")));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF00897B),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              children: [
                const CircleAvatar(radius: 40, backgroundColor: Color(0xFF00897B), child: Icon(Icons.person, size: 45, color: Colors.white)),
                Positioned(bottom: 0, right: 0, child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('Rahul Verma', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: const [
                ListTile(leading: Icon(Icons.person_outline, color: Color(0xFF00897B)), title: Text('Account')),
                ListTile(leading: Icon(Icons.notifications_outlined, color: Color(0xFF00897B)), title: Text('Notifications')),
                ListTile(leading: Icon(Icons.lock_outline, color: Color(0xFF00897B)), title: Text('Privacy')),
                ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Logout', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
