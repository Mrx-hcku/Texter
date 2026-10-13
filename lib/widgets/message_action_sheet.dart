import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../config/theme.dart';

const List<String> quickReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Telegram-style floating menu that appears right next to the tapped
/// message bubble (instead of a full-width bottom sheet): a quick emoji
/// reaction row on top, then Reply / Copy / Select / Pin / Delete below.
///
/// [tapPosition] is the global position of the long-press (grab it from
/// `onLongPressStart: (details) => details.globalPosition`), so the menu
/// opens anchored at that exact spot, like Telegram/WhatsApp.
Future<void> showMessageActionSheet(
  BuildContext context, {
  required Offset tapPosition,
  required bool canDelete,
  required String messageText,
  required void Function(String emoji) onReact,
  required VoidCallback onMoreEmojis,
  required VoidCallback onSelect,
  VoidCallback? onDelete,
  VoidCallback? onPin,
  VoidCallback? onReply,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final size = overlay.size;

  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      tapPosition.dx,
      tapPosition.dy,
      size.width - tapPosition.dx,
      size.height - tapPosition.dy,
    ),
    color: AppTheme.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
    items: [
      PopupMenuItem<String>(
        enabled: false,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ...quickReactionEmojis.map(
              (e) => GestureDetector(
                onTap: () => Navigator.pop(context, 'emoji:$e'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Text(e, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context, 'more_emojis'),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.add, color: Colors.white70, size: 16),
              ),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(height: 8),
      if (onReply != null)
        PopupMenuItem<String>(
          value: 'reply',
          height: 40,
          child: Row(children: [
            const Icon(Icons.reply, color: AppTheme.cyan, size: 20),
            const SizedBox(width: 12),
            Text('Reply', style: AppTheme.body(color: Colors.white, size: 14)),
          ]),
        ),
      PopupMenuItem<String>(
        value: 'copy',
        height: 40,
        child: Row(children: [
          const Icon(Icons.copy_outlined, color: AppTheme.cyan, size: 20),
          const SizedBox(width: 12),
          Text('Copy', style: AppTheme.body(color: Colors.white, size: 14)),
        ]),
      ),
      PopupMenuItem<String>(
        value: 'select',
        height: 40,
        child: Row(children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.cyan, size: 20),
          const SizedBox(width: 12),
          Text('Select', style: AppTheme.body(color: Colors.white, size: 14)),
        ]),
      ),
      if (onPin != null)
        PopupMenuItem<String>(
          value: 'pin',
          height: 40,
          child: Row(children: [
            const Icon(Icons.push_pin_outlined, color: AppTheme.cyan, size: 20),
            const SizedBox(width: 12),
            Text('Pin', style: AppTheme.body(color: Colors.white, size: 14)),
          ]),
        ),
      if (canDelete)
        PopupMenuItem<String>(
          value: 'delete',
          height: 40,
          child: Row(children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            const SizedBox(width: 12),
            Text('Delete', style: AppTheme.body(color: Colors.redAccent, size: 14)),
          ]),
        ),
    ],
  );

  if (selected == null) return;

  if (selected.startsWith('emoji:')) {
    onReact(selected.substring(6));
  } else if (selected == 'more_emojis') {
    onMoreEmojis();
  } else if (selected == 'reply') {
    onReply?.call();
  } else if (selected == 'copy') {
    await Clipboard.setData(ClipboardData(text: messageText));
  } else if (selected == 'select') {
    onSelect();
  } else if (selected == 'pin') {
    onPin?.call();
  } else if (selected == 'delete') {
    onDelete?.call();
  }
}

/// Opens the full emoji picker in a bottom sheet and returns the emoji the
/// person tapped (or null if they closed it without picking one).
Future<String?> showFullEmojiPicker(BuildContext context) async {
  String? selected;
  await showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    builder: (ctx) => SizedBox(
      height: 300,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          selected = emoji.emoji;
          Navigator.pop(ctx);
        },
        config: const Config(height: 300),
      ),
    ),
  );
  return selected;
}

/// Confirmation dialog before permanently deleting message(s) from the
/// database. [count] > 1 pluralizes the wording for multi-select delete.
Future<bool> confirmDeleteMessages(BuildContext context, int count) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text(count > 1 ? 'Delete $count messages?' : 'Delete message?', style: AppTheme.heading(size: 16, color: Colors.white)),
      content: Text(
        'This cannot be undone — it will be removed for everyone.',
        style: AppTheme.body(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    ),
  );
  return result ?? false;
}
