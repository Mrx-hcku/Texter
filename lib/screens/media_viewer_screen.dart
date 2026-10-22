import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

/// Full-screen photo/video viewer (WhatsApp/Telegram "tap to open big"
/// style). Images support pinch-to-zoom; videos get play/pause + a seek bar.
class MediaViewerScreen extends StatefulWidget {
  final String url;
  final bool isVideo;
  final String? caption;

  const MediaViewerScreen({super.key, required this.url, required this.isVideo, this.caption});

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _controller;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _controller = controller;
      controller.initialize().then((_) {
        if (mounted) setState(() {});
        controller.play();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Center(
              child: widget.isVideo ? _buildVideo() : _buildPhoto(),
            ),
            if (_showControls)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showControls && widget.caption != null && widget.caption!.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.black54,
                    child: Text(widget.caption!, style: const TextStyle(color: Colors.white)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    return PhotoView(
      imageProvider: CachedNetworkImageProvider(widget.url),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
      ),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
    );
  }

  Widget _buildVideo() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator(color: AppTheme.cyan);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
        if (_showControls) ...[
          VideoProgressIndicator(controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: AppTheme.cyan)),
          IconButton(
            iconSize: 48,
            icon: Icon(controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white),
            onPressed: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()),
          ),
        ],
      ],
    );
  }
}
