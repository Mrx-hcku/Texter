import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../config/theme.dart';

const int kMaxMediaFiles = 5;
const int kMaxMediaBytes = 30 * 1024 * 1024; // 30 MB

class PickedMedia {
  final File file;
  final bool isVideo;
  PickedMedia(this.file, this.isVideo);
}

class MediaComposeResult {
  final List<PickedMedia> files;
  final String caption;
  MediaComposeResult(this.files, this.caption);
}

/// Filters [picked] down to the WhatsApp/Telegram-style limits this app
/// enforces: at most [kMaxMediaFiles] files, none larger than 30 MB. Returns
/// the accepted files and a human-readable message about anything dropped
/// (empty string if nothing was dropped).
Future<(List<PickedMedia>, String)> _applyLimits(List<PickedMedia> picked) async {
  final accepted = <PickedMedia>[];
  var droppedForSize = 0;
  var droppedForCount = 0;
  for (final p in picked) {
    if (accepted.length >= kMaxMediaFiles) {
      droppedForCount++;
      continue;
    }
    final size = await p.file.length();
    if (size > kMaxMediaBytes) {
      droppedForSize++;
      continue;
    }
    accepted.add(p);
  }
  final parts = <String>[];
  if (droppedForCount > 0) parts.add('max $kMaxMediaFiles files at a time');
  if (droppedForSize > 0) parts.add('$droppedForSize file${droppedForSize > 1 ? 's were' : ' was'} over 30MB');
  return (accepted, parts.join(' — '));
}

/// Opens the WhatsApp/Telegram style media preview sheet for [initialFiles].
/// Returns null if the person cancelled, otherwise the final file list +
/// caption to send.
Future<MediaComposeResult?> showMediaComposeSheet(BuildContext context, List<PickedMedia> initialFiles) async {
  final (accepted, warning) = await _applyLimits(initialFiles);
  if (accepted.isEmpty) {
    if (context.mounted && warning.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(warning)));
    }
    return null;
  }
  if (!context.mounted) return null;
  if (warning.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(warning)));
  }
  return showModalBottomSheet<MediaComposeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ChatPalette.of(context).panel,
    builder: (ctx) => _MediaComposeBody(initialFiles: accepted),
  );
}

class _MediaComposeBody extends StatefulWidget {
  final List<PickedMedia> initialFiles;
  const _MediaComposeBody({required this.initialFiles});

  @override
  State<_MediaComposeBody> createState() => _MediaComposeBodyState();
}

class _MediaComposeBodyState extends State<_MediaComposeBody> {
  late List<PickedMedia> _files;
  int _selectedIndex = 0;
  final _captionController = TextEditingController();
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _files = List.of(widget.initialFiles);
    _loadPreviewVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  void _loadPreviewVideo() {
    _videoController?.dispose();
    _videoController = null;
    if (_files.isEmpty) return;
    final current = _files[_selectedIndex];
    if (current.isVideo) {
      final controller = VideoPlayerController.file(current.file);
      _videoController = controller;
      controller.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _removeAt(int i) {
    setState(() {
      _files.removeAt(i);
      if (_selectedIndex >= _files.length) _selectedIndex = _files.length - 1;
      if (_selectedIndex < 0) _selectedIndex = 0;
    });
    _loadPreviewVideo();
    if (_files.isEmpty) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatPalette.of(context);
    if (_files.isEmpty) return const SizedBox.shrink();
    final current = _files[_selectedIndex];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.close, color: p.inputText), onPressed: () => Navigator.pop(context)),
                  Text('${_files.length}/$kMaxMediaFiles', style: AppTheme.body(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            // Big preview
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: Colors.black,
                child: current.isVideo
                    ? (_videoController != null && _videoController!.value.isInitialized
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!)),
                              IconButton(
                                iconSize: 56,
                                icon: Icon(
                                  _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                  color: Colors.white70,
                                ),
                                onPressed: () => setState(() {
                                  _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                                }),
                              ),
                            ],
                          )
                        : const Center(child: CircularProgressIndicator(color: AppTheme.cyan)))
                    : Image.file(current.file, fit: BoxFit.contain),
              ),
            ),
            // Thumbnail strip
            if (_files.length > 1 || _files.length < kMaxMediaFiles)
              SizedBox(
                height: 64,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: _files.length,
                  itemBuilder: (context, i) {
                    final f = _files[i];
                    final selected = i == _selectedIndex;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedIndex = i);
                        _loadPreviewVideo();
                      },
                      child: Container(
                        width: 52,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: selected ? AppTheme.cyan : Colors.transparent, width: 2),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: f.isVideo
                                  ? Container(
                                      width: 52,
                                      height: 52,
                                      color: p.panel,
                                      child: const Icon(Icons.videocam, color: Colors.white54, size: 20),
                                    )
                                  : Image.file(f.file, width: 52, height: 52, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => _removeAt(i),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            // Caption + send
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(24)),
                      child: TextField(
                        controller: _captionController,
                        style: TextStyle(color: p.inputText),
                        decoration: InputDecoration(hintText: 'Add a caption...', hintStyle: TextStyle(color: p.inputHint), border: InputBorder.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppTheme.cyan,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black),
                      onPressed: () => Navigator.pop(context, MediaComposeResult(_files, _captionController.text.trim())),
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
}
