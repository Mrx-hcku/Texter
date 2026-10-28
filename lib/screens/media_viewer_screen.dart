import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:texter_video/texter_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// One photo / video in the viewer.
class MediaViewerItem {
  const MediaViewerItem({
    required this.url,
    required this.isVideo,
    this.caption = '',
    this.title = '',
    this.time,
  });
  final String url;
  final bool isVideo;
  final String caption;
  final String title; // who sent it
  final DateTime? time;
}

/// Telegram-style full-screen viewer:
///  - swipe left / right to go through ALL photos and videos of the chat
///  - pinch + double-tap zoom, drag down to close, tap to hide the bars
///  - videos with play/pause, seek bar, mute and speed
///  - Save to gallery, Share link, Copy link, Open in browser
/// Old call `MediaViewerScreen(url:, isVideo:, caption:)` still works.
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({
    super.key,
    this.url,
    this.isVideo = false,
    this.caption = '',
    this.items,
    this.initialIndex = 0,
  });

  final String? url;
  final bool isVideo;
  final String caption;
  final List<MediaViewerItem>? items;
  final int initialIndex;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final List<MediaViewerItem> _items;
  late final PageController _pageController;
  int _index = 0;
  bool _uiVisible = true;
  bool _zoomed = false;
  double _dragY = 0;
  double? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _items = widget.items ??
        [MediaViewerItem(url: widget.url ?? '', isVideo: widget.isVideo, caption: widget.caption)];
    _index = widget.initialIndex.clamp(0, _items.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUi() {
    setState(() => _uiVisible = !_uiVisible);
    SystemChrome.setEnabledSystemUIMode(_uiVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg, style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF263238)));
  }

  String _guessMime(File f, bool isVideo) {
    if (isVideo) return 'video/mp4';
    try {
      final raf = f.openSync();
      final head = raf.readSync(12);
      raf.closeSync();
      if (head.length >= 4 && head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47) return 'image/png';
      if (head.length >= 12 && head[0] == 0x52 && head[1] == 0x49 && head[8] == 0x57 && head[9] == 0x45) return 'image/webp';
    } catch (_) {}
    return 'image/jpeg';
  }

  Future<void> _save() async {
    if (_downloadProgress != null) return;
    final it = _items[_index];
    setState(() => _downloadProgress = 0);
    File? file;
    try {
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/texter_dl_${DateTime.now().millisecondsSinceEpoch}');
      final client = http.Client();
      final res = await client.send(http.Request('GET', Uri.parse(it.url)));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final total = res.contentLength ?? 0;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        got += chunk.length;
        sink.add(chunk);
        if (total > 0 && mounted) setState(() => _downloadProgress = got / total);
      }
      await sink.flush();
      await sink.close();
      client.close();
      final mime = _guessMime(file, it.isVideo);
      final ext = mime == 'image/png' ? 'png' : mime == 'image/webp' ? 'webp' : it.isVideo ? 'mp4' : 'jpg';
      final ok = await TexterVideo.saveToGallery(file.path, 'Texter_${DateTime.now().millisecondsSinceEpoch}.$ext', mime);
      if (ok) {
        _snack('Saved to Gallery');
      } else {
        _snack('Opening in browser to download…');
        await launchUrl(Uri.parse(it.url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _snack('Download failed. Check your internet and try again.');
    } finally {
      try {
        file?.deleteSync();
      } catch (_) {}
      if (mounted) setState(() => _downloadProgress = null);
    }
  }

  Future<void> _onMenu(String v) async {
    final it = _items[_index];
    switch (v) {
      case 'save':
        await _save();
        break;
      case 'share':
        await TexterVideo.shareText(it.url);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: it.url));
        _snack('Link copied');
        break;
      case 'open':
        await launchUrl(Uri.parse(it.url), mode: LaunchMode.externalApplication);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = _items[_index];
    final dim = (1 - (_dragY.abs() / 500)).clamp(0.4, 1.0);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragUpdate: _zoomed ? null : (d) => setState(() => _dragY += d.delta.dy),
            onVerticalDragEnd: _zoomed
                ? null
                : (d) {
                    if (_dragY.abs() > 110 || d.velocity.pixelsPerSecond.dy.abs() > 900) {
                      Navigator.pop(context);
                    } else {
                      setState(() => _dragY = 0);
                    }
                  },
            child: Opacity(
              opacity: dim,
              child: Transform.translate(
                offset: Offset(0, _dragY),
                child: PageView.builder(
                  controller: _pageController,
                  physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                  itemCount: _items.length,
                  onPageChanged: (i) => setState(() {
                    _index = i;
                    _zoomed = false;
                  }),
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    if (item.isVideo) {
                      return _VideoPage(
                        key: ValueKey('video_$i'),
                        url: item.url,
                        active: i == _index,
                        controlsVisible: _uiVisible,
                        onToggleUi: _toggleUi,
                      );
                    }
                    return _ImagePage(
                      key: ValueKey('image_$i'),
                      url: item.url,
                      onToggleUi: _toggleUi,
                      onZoomChanged: (z) {
                        if (z != _zoomed) setState(() => _zoomed = z);
                      },
                    );
                  },
                ),
              ),
            ),
          ),

          // ---- top bar ----
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_uiVisible,
              child: AnimatedOpacity(
                opacity: _uiVisible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.title.isNotEmpty ? it.title : (it.isVideo ? 'Video' : 'Photo'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  [
                                    if (_items.length > 1) '${_index + 1} of ${_items.length}',
                                    if (it.time != null) DateFormat('d MMM, h:mm a').format(it.time!),
                                  ].join('  ·  '),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            color: const Color(0xFF1E2329),
                            onSelected: _onMenu,
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'save', child: _MenuRow(Icons.download_rounded, 'Save to gallery')),
                              PopupMenuItem(value: 'share', child: _MenuRow(Icons.share_outlined, 'Share link')),
                              PopupMenuItem(value: 'copy', child: _MenuRow(Icons.link_rounded, 'Copy link')),
                              PopupMenuItem(value: 'open', child: _MenuRow(Icons.open_in_browser_rounded, 'Open in browser')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ---- caption ----
          if (it.caption.trim().isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_uiVisible,
                child: AnimatedOpacity(
                  opacity: _uiVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Text(it.caption, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ),

          // ---- download progress ----
          if (_downloadProgress != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: LinearProgressIndicator(
                  value: (_downloadProgress ?? 0) > 0 ? _downloadProgress : null,
                  minHeight: 3,
                  color: const Color(0xFF00E5D4),
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

// ======================= photo page =======================
class _ImagePage extends StatefulWidget {
  const _ImagePage({super.key, required this.url, required this.onToggleUi, required this.onZoomChanged});
  final String url;
  final VoidCallback onToggleUi;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
  final TransformationController _controller = TransformationController();
  Offset _tapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => widget.onZoomChanged(_controller.value.getMaxScaleOnAxis() > 1.02));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _doubleTap() {
    final zoomedIn = _controller.value.getMaxScaleOnAxis() > 1.05;
    if (zoomedIn) {
      _controller.value = Matrix4.identity();
    } else {
      const s = 2.5;
      final m = Matrix4.identity();
      m.setEntry(0, 0, s);
      m.setEntry(1, 1, s);
      m.setTranslationRaw(-_tapPos.dx * (s - 1), -_tapPos.dy * (s - 1), 0);
      _controller.value = m;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToggleUi,
      onDoubleTapDown: (d) => _tapPos = d.localPosition,
      onDoubleTap: _doubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 5,
        child: SizedBox.expand(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            progressIndicatorBuilder: (_, __, p) => Center(
              child: CircularProgressIndicator(value: p.progress, color: const Color(0xFF00E5D4)),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text('Could not load photo', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= video page =======================
class _VideoPage extends StatefulWidget {
  const _VideoPage({super.key, required this.url, required this.active, required this.controlsVisible, required this.onToggleUi});
  final String url;
  final bool active;
  final bool controlsVisible;
  final VoidCallback onToggleUi;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _error = false;
  bool _muted = false;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _c = c;
      await c.initialize();
      c.addListener(_tick);
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.active) c.play();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _VideoPage old) {
    super.didUpdateWidget(old);
    final c = _c;
    if (c != null && _ready && old.active != widget.active) {
      widget.active ? c.play() : c.pause();
    }
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:${m.padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_error) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 48),
            SizedBox(height: 8),
            Text('Could not play this video', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    if (!_ready || c == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5D4)));
    }
    final v = c.value;
    final dur = v.duration.inMilliseconds;
    final pos = v.position.inMilliseconds.clamp(0, dur == 0 ? 1 : dur);
    final ended = dur > 0 && pos >= dur - 200;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggleUi,
          child: Center(child: AspectRatio(aspectRatio: v.aspectRatio == 0 ? 16 / 9 : v.aspectRatio, child: VideoPlayer(c))),
        ),
        if (widget.controlsVisible) ...[
          Center(
            child: GestureDetector(
              onTap: () {
                if (ended) {
                  c.seekTo(Duration.zero);
                  c.play();
                } else {
                  v.isPlaying ? c.pause() : c.play();
                }
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: Icon(
                  ended ? Icons.replay_rounded : (v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 90,
            child: Row(
              children: [
                Text(_fmt(Duration(milliseconds: pos)), style: const TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: const Color(0xFF00E5D4),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: const Color(0xFF00E5D4),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: pos.toDouble(),
                      min: 0,
                      max: (dur == 0 ? 1 : dur).toDouble(),
                      onChanged: (x) => c.seekTo(Duration(milliseconds: x.toInt())),
                    ),
                  ),
                ),
                Text(_fmt(v.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 22),
                  onPressed: () {
                    setState(() => _muted = !_muted);
                    c.setVolume(_muted ? 0 : 1);
                  },
                ),
                PopupMenuButton<double>(
                  tooltip: 'Speed',
                  color: const Color(0xFF1E2329),
                  initialValue: _speed,
                  onSelected: (s) {
                    setState(() => _speed = s);
                    c.setPlaybackSpeed(s);
                  },
                  itemBuilder: (_) => [0.5, 1.0, 1.5, 2.0]
                      .map((s) => PopupMenuItem<double>(value: s, child: Text('${s}x', style: const TextStyle(color: Colors.white))))
                      .toList(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('${_speed}x', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
