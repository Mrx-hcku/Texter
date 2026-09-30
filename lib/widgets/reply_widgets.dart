import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/models.dart';

/// One-line preview text for a message (used in reply previews / quotes).
String messageSnippet(MessageModel m) {
  if (m.attachmentType == 'image') return '📷 Photo';
  if (m.attachmentType == 'voice') return '🎤 Voice message';
  if (m.attachmentType == 'file') return m.text.isNotEmpty ? '📎 ${m.text}' : '📎 File';
  return m.text;
}

/// Bar shown right above the message input while the user is composing a
/// reply (WhatsApp / Telegram style). [onCancel] clears the reply.
class ReplyComposerBar extends StatelessWidget {
  final String senderName;
  final String snippet;
  final VoidCallback onCancel;

  const ReplyComposerBar({
    super.key,
    required this.senderName,
    required this.snippet,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Container(width: 3, height: 34, decoration: BoxDecoration(color: AppTheme.cyan, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to $senderName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.cyan, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Quoted original message shown at the top of a reply bubble.
/// If the original isn't loaded/was deleted, [original] is null and a
/// "Message unavailable" placeholder is shown instead.
class ReplyQuote extends StatelessWidget {
  final String senderName;
  final MessageModel? original;
  final VoidCallback? onTap;

  const ReplyQuote({
    super.key,
    required this.senderName,
    required this.original,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unavailable = original == null;
    return GestureDetector(
      onTap: unavailable ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: AppTheme.cyan, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              unavailable ? 'Message' : senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              unavailable ? 'Message unavailable' : messageSnippet(original!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 12.5,
                fontStyle: unavailable ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
