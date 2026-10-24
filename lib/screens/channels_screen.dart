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

  String _subs(Object n) => '$n' == '1' ? '1 subscriber' : '$n subscribers';

  Future<void> _open(ChannelModel c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelViewScreen(channelId: c.id)));
    _load();
  }

  /// The most-subscribed channel gets one big "Trending" card on top.
  Widget _trendingCard(ChannelModel c, UiPalette u, bool dark) {
    final colors = NameTint.gradient(c.name, dark);
    final ink = dark ? Colors.white : const Color(0xFF1C262B);
    final btnText = dark ? Colors.black : Colors.white;
    final initial = c.name.isNotEmpty ? c.name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: () => _open(c),
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 8, 4, 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: dark ? Colors.white10 : Colors.black12),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              bottom: -34,
              child: Text(initial, style: TextStyle(fontSize: 170, fontWeight: FontWeight.w900, color: ink.withOpacity(0.07))),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: ink.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded, size: 15, color: ink),
                        const SizedBox(width: 4),
                        Text('TRENDING', style: AppTheme.body(size: 11, weight: FontWeight.w800, color: ink)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.heading(size: 24, color: ink),
                  ),
                  const SizedBox(height: 6),
                  Text(_subs(c.subscriberCount), style: AppTheme.body(size: 13, color: ink.withOpacity(0.75))),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: () => _open(c),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        backgroundColor: ink,
                        foregroundColor: btnText,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Open channel'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Channels hang off a vertical "feed line", each with its own colour dot.
  Widget _timelineRow(ChannelModel c, UiPalette u, bool dark, {required bool isLast}) {
    final accent = NameTint.accent(c.name, dark);
    final colors = NameTint.gradient(c.name, dark);
    final ink = dark ? Colors.white : const Color(0xFF1C262B);
    final initial = c.name.isNotEmpty ? c.name[0].toUpperCase() : '?';
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                const SizedBox(height: 26),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent, border: Border.all(color: bg, width: 3)),
                ),
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : u.border)),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _open(c),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: u.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: u.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Text(initial, style: AppTheme.heading(size: 18, color: ink)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(size: 15, weight: FontWeight.w600, color: u.text),
                          ),
                          const SizedBox(height: 2),
                          Text(_subs(c.subscriberCount), style: AppTheme.body(size: 12, color: u.subtext)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: u.subtext),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sorted = [..._channels]
      ..sort((a, b) => (b.subscriberCount as num).compareTo(a.subscriberCount as num));
    final feed = <Widget>[];
    if (sorted.isNotEmpty) {
      feed.add(_trendingCard(sorted.first, u, dark));
      final rest = sorted.sublist(1);
      if (rest.isNotEmpty) {
        feed.add(Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 4, 10),
          child: Text('ALL CHANNELS', style: AppTheme.body(size: 12, weight: FontWeight.w700, color: u.accent)),
        ));
      }
      for (int i = 0; i < rest.length; i++) {
        feed.add(_timelineRow(rest[i], u, dark, isLast: i == rest.length - 1));
        if (_ads.isNotEmpty && (i + 1) % 3 == 0) {
          feed.add(Padding(
            padding: const EdgeInsets.only(left: 26),
            child: SponsoredAdCard(ad: _ads[(i ~/ 3) % _ads.length]),
          ));
        }
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
          ? Center(child: CircularProgressIndicator(color: u.accent))
          : RefreshIndicator(
              onRefresh: _load,
              backgroundColor: u.card,
              color: u.accent,
              child: feed.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 80),
                        child: Center(child: Text('No channels yet', style: AppTheme.body(color: u.subtext))),
                      ),
                    ])
                  : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: feed),
            ),
    );
  }
}
