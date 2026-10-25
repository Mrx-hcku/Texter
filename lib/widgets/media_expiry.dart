import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Videos and files are deleted automatically this many days after sending
/// (the server job in /server removes them from storage; the app also hides
/// them as soon as the time is up). Photos / voice notes are only removed
/// if they are bigger than 10 MB — that part is decided by the server.
const int kMediaExpiryDays = 3;

bool isMediaExpired({required String type, required String url, required DateTime createdAt}) {
  if (type == 'expired') return true;
  if (url.isEmpty) return false;
  if (type == 'video' || type == 'file') {
    return DateTime.now().isAfter(createdAt.add(const Duration(days: kMediaExpiryDays)));
  }
  return false;
}

String _timeLeft(DateTime createdAt) {
  final left = createdAt.add(const Duration(days: kMediaExpiryDays)).difference(DateTime.now());
  if (left.inHours >= 24) return '${left.inDays}d ${left.inHours % 24}h';
  if (left.inHours >= 1) return '${left.inHours}h';
  final m = left.inMinutes < 1 ? 1 : left.inMinutes;
  return '${m}m';
}

/// Shown in place of a video / file that has been auto-deleted.
Widget expiredMediaView(ChatPalette p, bool mine) {
  final c = (mine ? p.mineText : p.otherText).withOpacity(0.65);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.timer_off_outlined, size: 18, color: c),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          'Expired — deleted after $kMediaExpiryDays days',
          style: TextStyle(color: c, fontStyle: FontStyle.italic, fontSize: 13),
        ),
      ),
    ],
  );
}

/// Adds a small "Deletes in 2d 5h" line under a video / file.
Widget withExpiryNote(Widget content, ChatPalette p, bool mine, DateTime createdAt) {
  final c = (mine ? p.mineText : p.otherText).withOpacity(0.55);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      content,
      const SizedBox(height: 4),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 11, color: c),
          const SizedBox(width: 3),
          Text('Deletes in ${_timeLeft(createdAt)}', style: TextStyle(color: c, fontSize: 10.5)),
        ],
      ),
    ],
  );
}
