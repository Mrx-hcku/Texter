import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/models.dart';
import 'media_expiry.dart';

/// One row in the chat: either a single message, or an "album" — several
/// photos/videos sent together, shown as ONE bubble with a photo grid
/// (like Telegram / WhatsApp).
class AlbumEntry {
  AlbumEntry(this.main, this.items);
  final MessageModel main; // first message of the album (carries the caption)
  final List<MessageModel> items;
  bool get isAlbum => items.length > 1;
}

bool _albumable(MessageModel m) {
  if (m.attachmentUrl.isEmpty) return false;
  if (m.attachmentType != 'image' && m.attachmentType != 'video') return false;
  return !isMediaExpired(type: m.attachmentType, url: m.attachmentUrl, createdAt: m.createdAt);
}

/// Groups consecutive photos/videos from the same sender (sent within 40 s of
/// each other, max 10) into albums. Only the first one may have a caption.
List<AlbumEntry> buildAlbumEntries(List<MessageModel> msgs) {
  final out = <AlbumEntry>[];
  for (final m in msgs) {
    if (out.isNotEmpty && _albumable(m)) {
      final last = out.last;
      final prev = last.items.last;
      if (_albumable(prev) &&
          last.items.length < 10 &&
          prev.senderId == m.senderId &&
          m.text.trim().isEmpty &&
          m.replyToId.isEmpty &&
          m.createdAt.difference(prev.createdAt).inSeconds.abs() <= 40) {
        last.items.add(m);
        continue;
      }
    }
    out.add(AlbumEntry(m, [m]));
  }
  return out;
}

/// Caption under a photo / video / album.
Widget withCaption(Widget content, String caption, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      content,
      const SizedBox(height: 6),
      Text(caption, style: TextStyle(color: color)),
    ],
  );
}

List<int> _rowPlan(int n) {
  if (n <= 1) return [1];
  if (n == 2) return [2];
  if (n == 3) return [1, 2];
  final rows = (n / 3).ceil();
  final base = n ~/ rows;
  final extra = n % rows;
  return [for (var i = 0; i < rows; i++) base + (i < extra ? 1 : 0)];
}

Widget buildAlbumView({
  required List<MessageModel> items,
  required ChatPalette p,
  required void Function(MessageModel m) onOpen,
  required void Function(MessageModel m) onPendingTap,
  double width = 240,
}) {
  const gap = 3.0;
  final rows = _rowPlan(items.length);
  var idx = 0;
  final rowWidgets = <Widget>[];
  for (final k in rows) {
    final tileW = (width - gap * (k - 1)) / k;
    final tileH = k == 1 ? width * 0.62 : tileW;
    final tiles = <Widget>[];
    for (var c = 0; c < k; c++) {
      final m = items[idx++];
      tiles.add(SizedBox(width: tileW, height: tileH, child: _albumTile(m, p, onOpen, onPendingTap)));
      if (c < k - 1) tiles.add(const SizedBox(width: gap));
    }
    rowWidgets.add(Row(mainAxisSize: MainAxisSize.min, children: tiles));
    if (idx < items.length) rowWidgets.add(const SizedBox(height: gap));
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(width: width, child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets)),
  );
}

Widget _albumTile(
  MessageModel m,
  ChatPalette p,
  void Function(MessageModel m) onOpen,
  void Function(MessageModel m) onPendingTap,
) {
  final pending = m.id.startsWith('local_media_');
  final isVideo = m.attachmentType == 'video';
  Widget base;
  if (isVideo) {
    base = Container(color: const Color(0xFF263238));
  } else if (pending) {
    base = Image.file(
      File(m.attachmentUrl),
      fit: BoxFit.cover,
      cacheWidth: 400,
      errorBuilder: (_, __, ___) => Container(color: p.panel),
    );
  } else {
    base = CachedNetworkImage(
      imageUrl: m.attachmentUrl,
      memCacheWidth: 400,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: p.panel),
      errorWidget: (_, __, ___) => Container(color: p.panel, child: const Icon(Icons.broken_image, color: AppTheme.textSecondary)),
    );
  }
  return GestureDetector(
    onTap: () => pending ? onPendingTap(m) : onOpen(m),
    child: Stack(
      fit: StackFit.expand,
      children: [
        base,
        if (isVideo && !pending)
          const Center(
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.black54,
              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
            ),
          ),
        if (pending)
          Container(
            color: Colors.black38,
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
