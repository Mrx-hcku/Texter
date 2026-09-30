import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../config/theme.dart';

const List<String> quickReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// Long-press menu for a message bubble: quick emoji reactions, a "more
/// emojis" button (opens the full picker), Select (multi-select mode) and
/// Delete (only shown when [canDelete] is true).
Future<void> showMessageActionSheet(
  BuildContext context, {
  required bool canDelete,
  required void Function(String emoji) onReact,
  required VoidCallback onMoreEmojis,
  required VoidCallback onSelect,
  VoidCallback? onDelete,
  VoidCallback? onPin,
  VoidCallback? onReply,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...quickReactionEmojis.map(
                  (e) => GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      onReact(e);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    onMoreEmojis();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.add, color: Colors.white70, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(color: AppTheme.surfaceLight, height: 1),
            if (onReply != null)
              ListTile(
                leading: const Icon(Icons.reply, color: AppTheme.cyan),
                title: Text('Reply', style: AppTheme.body(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onReply();
                },
              ),
            if (onPin != null)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined, color: AppTheme.cyan),
                title: Text('Pin this message', style: AppTheme.body(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  onPin();
                },
              ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: AppTheme.cyan),
              title: Text('Select', style: AppTheme.body(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                onSelect();
              },
            ),
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text('Delete', style: AppTheme.body(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete?.call();
                },
              ),
          ],
        ),
      ),
    ),
  );
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
