import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../config/theme.dart';

const List<String> quickReactionEmojis = ['👍', '❤️', '😊', '😢', '😂'];

/// Telegram-style professional floating action sheet with a vertical emoji
/// reaction column on the left/side and action menu options on the right,
/// styled cleanly with a dark/black theme matching background.
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
  VoidCallback? onEdit,
  VoidCallback? onForward,
}) async {
  final screenSize = MediaQuery.of(context).size;
  
  // Intelligent positioning so the popup stays inside the screen boundaries
  final isRightSide = tapPosition.dx > screenSize.width * 0.5;
  final isBottomArea = tapPosition.dy > screenSize.height * 0.65;

  await showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) {
      final p = ChatPalette.of(context);
      return Stack(
        children: [
          // Background dismiss detector
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.pop(context),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: isRightSide ? null : 20,
            right: isRightSide ? 20 : null,
            top: isBottomArea ? tapPosition.dy - 300 : tapPosition.dy + 10,
            child: Material(
              color: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Left Side: Vertical Reaction Emojis Card (Dark Theme)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: p.sheet,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: p.sheetBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ...quickReactionEmojis.map(
                          (emoji) => InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              onReact(emoji);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(emoji, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                        ),
                        // Plus button for full emoji picker
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            onMoreEmojis();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.sheetChip,
                            ),
                            child: Icon(Icons.add, color: p.sheetIcon, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right Side: Action Menu Card (Reply, Forward, Copy, Info, Select, Pin, Delete)
                  Container(
                    width: 210,
                    decoration: BoxDecoration(
                      color: p.sheet,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.sheetBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onReply != null)
                          _buildActionItem(
                            icon: Icons.reply,
                            label: 'Reply',
                            onTap: () {
                              Navigator.pop(context);
                              onReply();
                            },
                          ),
                        if (onForward != null)
                          _buildActionItem(
                            icon: Icons.near_me_outlined,
                            label: 'Forward',
                            onTap: () {
                              Navigator.pop(context);
                              onForward();
                            },
                          ),
                        _buildActionItem(
                          icon: Icons.copy_rounded,
                          label: 'Copy',
                          onTap: () async {
                            await Clipboard.setData(ClipboardData(text: messageText));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Text copied to clipboard')),
                            );
                          },
                        ),
                        _buildActionItem(
                          icon: Icons.check_circle_outline,
                          label: 'Select',
                          onTap: () {
                            Navigator.pop(context);
                            onSelect();
                          },
                        ),
                        if (onEdit != null)
                          _buildActionItem(
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            onTap: () {
                              Navigator.pop(context);
                              onEdit();
                            },
                          ),
                        if (onPin != null)
                          _buildActionItem(
                            icon: Icons.push_pin_outlined,
                            label: 'Pin',
                            onTap: () {
                              Navigator.pop(context);
                              onPin();
                            },
                          ),
                        if (canDelete && onDelete != null)
                          _buildActionItem(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete',
                            textColor: Colors.redAccent,
                            iconColor: Colors.redAccent,
                            onTap: () {
                              Navigator.pop(context);
                              onDelete();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildActionItem({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  Color? textColor,
  Color? iconColor,
}) {
  return Builder(builder: (context) {
  final p = ChatPalette.of(context);
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor ?? p.sheetText,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Icon(icon, color: iconColor ?? p.sheetIcon, size: 20),
        ],
      ),
    ),
  );
  });
}

/// Opens the full emoji picker in a bottom sheet with a dark theme matching background
Future<String?> showFullEmojiPicker(BuildContext context) async {
  String? selected;
  await showModalBottomSheet(
    context: context,
    backgroundColor: ChatPalette.of(context).sheet,
    builder: (ctx) => SizedBox(
      height: 300,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          selected = emoji.emoji;
          Navigator.pop(ctx);
        },
        config: const Config(),
      ),
    ),
  );
  return selected;
}

/// Confirmation dialog before permanently deleting message(s) from the database.
Future<bool> confirmDeleteMessages(BuildContext context, int count) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ChatPalette.of(ctx).sheet,
      title: Text(count > 1 ? 'Delete $count messages?' : 'Delete message?', style: AppTheme.heading(size: 16, color: ChatPalette.of(ctx).sheetText)),
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
