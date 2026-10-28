import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../config/theme.dart';
import '../config/app_config.dart';
import '../services/appwrite_service.dart';
import '../models/models.dart';
import '../widgets/sponsored_ad_card.dart';
import '../widgets/texter_ui.dart';
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
  String? _myId;
  String _query = '';
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
      final me = await AppwriteService.instance.getCurrentUser();
      final chDocs = await AppwriteService.instance.getChannels();
      final adDocs = await AppwriteService.instance.getAds(targetType: 'channel');
      if (!mounted) return;
      setState(() {
        _myId = me?.$id;
        _channels = chDocs.map((d) => ChannelModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _ads = adDocs.map((d) => AdModel.fromMap(d.data..addAll({'\$id': d.$id}))).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load channels: $e')));
    }
    _sub ??= AppwriteService.instance.subscribeToCollection(AppwriteConfig.channelsCollection, (doc, events) {
      _load();
    });
  }

  String _subs(Object n) => '$n' == '1' ? '1 follower' : '$n followers';

  Future<void> _open(ChannelModel c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelViewScreen(channelId: c.id)));
    _load();
  }

  Future<void> _create() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateChannelScreen()));
    _load();
  }

  bool _following(ChannelModel c) => _myId != null && c.subscriberIds.contains(_myId);

  DateTime? _lastTime(ChannelModel c) => DateTime.tryParse(c.lastMessageAt);

  Widget _search(UiPalette u) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextField(
        onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        style: AppTheme.body(color: u.text),
        decoration: InputDecoration(
          hintText: 'Search channels',
          prefixIcon: Icon(Icons.search, color: u.subtext),
          isDense: true,
        ),
      ),
    );
  }

  /// Small card in the "Popular" strip.
  Widget _popularCard(ChannelModel c, UiPalette u) {
    return GestureDetector(
      onTap: () => _open(c),
      child: Container(
        width: 146,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: u.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: u.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TexterAvatar(name: c.name, url: c.avatarUrl, size: 44),
            const Spacer(),
            Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 14, weight: FontWeight.w600, color: u.text)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.people_alt_outlined, size: 13, color: u.subtext),
                const SizedBox(width: 4),
                Text('${c.subscriberCount}', style: AppTheme.body(size: 12, color: u.subtext)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One channel row: photo, name, newest post preview + time.
  Widget _tile(ChannelModel c, UiPalette u) {
    final last = _lastTime(c);
    final preview = c.lastMessage.trim().isNotEmpty
        ? c.lastMessage.trim().replaceAll('\n', ' ')
        : (c.description.trim().isNotEmpty ? c.description.trim() : _subs(c.subscriberCount));
    final mine = c.isAdmin(_myId);
    return GestureDetector(
      onTap: () => _open(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: u.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: u.border)),
        child: Row(
          children: [
            TexterAvatar(name: c.name, url: c.avatarUrl, size: 52, ring: _following(c)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 15.5, weight: FontWeight.w700, color: u.text)),
                      ),
                      if (mine) ...[const SizedBox(width: 6), const TexterChip('Admin')],
                      const Spacer(),
                      if (last != null) Text(shortTime(last), style: AppTheme.body(size: 11.5, color: u.subtext)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(size: 13, color: u.subtext)),
                  const SizedBox(height: 3),
                  Text(_subs(c.subscriberCount), style: AppTheme.body(size: 11.5, color: u.subtext.withOpacity(0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _byActivity(ChannelModel a, ChannelModel b) {
    final ta = _lastTime(a);
    final tb = _lastTime(b);
    if (ta != null && tb != null) return tb.compareTo(ta);
    if (ta != null) return -1;
    if (tb != null) return 1;
    return b.subscriberCount.compareTo(a.subscriberCount);
  }

  void _addTiles(List<Widget> feed, List<ChannelModel> list, UiPalette u, int adOffset) {
    for (int i = 0; i < list.length; i++) {
      feed.add(_tile(list[i], u));
      if (_ads.isNotEmpty && (i + 1) % 4 == 0) {
        feed.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SponsoredAdCard(ad: _ads[((i + adOffset) ~/ 4) % _ads.length]),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    final all = [..._channels]..sort(_byActivity);
    final filtered = _query.isEmpty ? all : all.where((c) => c.name.toLowerCase().contains(_query)).toList();
    final following = filtered.where(_following).toList();
    final discover = filtered.where((c) => !_following(c)).toList();
    // "Popular" only makes sense once there are enough channels.
    final byFollowers = [..._channels]..sort((a, b) => b.subscriberCount.compareTo(a.subscriberCount));
    final popular = (_query.isEmpty && _channels.length >= 5) ? byFollowers.take(6).toList() : <ChannelModel>[];

    final feed = <Widget>[_search(u)];
    if (popular.isNotEmpty) {
      feed.add(const SectionLabel('Popular'));
      feed.add(SizedBox(
        height: 136,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: popular.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _popularCard(popular[i], u),
        ),
      ));
    }
    if (following.isNotEmpty) {
      feed.add(SectionLabel('Following · ${following.length}'));
      _addTiles(feed, following, u, 0);
    }
    if (discover.isNotEmpty) {
      feed.add(SectionLabel(following.isEmpty && _query.isEmpty ? 'All channels · ${discover.length}' : 'Discover · ${discover.length}'));
      _addTiles(feed, discover, u, following.length);
    }
    if (filtered.isEmpty) {
      feed.add(Padding(
        padding: const EdgeInsets.only(top: 70),
        child: Column(
          children: [
            Icon(Icons.campaign_outlined, size: 54, color: u.subtext),
            const SizedBox(height: 12),
            Text(_query.isEmpty ? 'No channels yet' : 'No channels found', style: AppTheme.body(size: 15, color: u.subtext)),
            if (_query.isEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Create a channel')),
            ],
          ],
        ),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _create)],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: u.accent))
          : RefreshIndicator(
              onRefresh: _load,
              backgroundColor: u.card,
              color: u.accent,
              child: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: feed),
            ),
    );
  }
}
