import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';
import '../widgets/sponsored_ad_card.dart';
import 'create_channel_screen.dart';
import 'channel_view_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<ChannelModel> _channels = [];
  List<AdModel> _ads = [];
  bool _loading = true;
  RealtimeSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chDocs = await AppwriteService.instance.getChannels();
      final adDocs = await AppwriteService.instance.getAds(targetType: 'channel');
      setState(() {
        _channels = chDocs.map((d) => ChannelModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _ads = adDocs.map((d) => AdModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load channels: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToCollection('channels', (doc, events) {
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final feed = <Widget>[];
    for (int i = 0; i < _channels.length; i++) {
      final c = _channels[i];
      feed.add(Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: AppTheme.glowBorder(color: AppTheme.pink),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.surfaceLight,
                child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: AppTheme.heading(size: 15, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${c.subscriberCount} subscribers', style: AppTheme.body(size: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelViewScreen(channelId: c.id)));
                _load();
              },
              child: const Text('View', style: TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ));
      if (_ads.isNotEmpty && (i + 1) % 3 == 0) {
        feed.add(SponsoredAdCard(ad: _ads[(i ~/ 3) % _ads.length]));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateChannelScreen()));
          _load();
        })],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.cyan))
          : RefreshIndicator(
              onRefresh: _load,
              backgroundColor: AppTheme.surface,
              color: AppTheme.cyan,
              child: feed.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(child: Text('No channels yet', style: AppTheme.body(color: AppTheme.textSecondary))),
                      ),
                    ])
                  : ListView(padding: const EdgeInsets.all(12), children: feed),
            ),
    );
  }
}
