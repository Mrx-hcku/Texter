import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Small chips row showing who reacted with what, under a message bubble.
/// Tapping a chip toggles that same emoji for the current user.
class ReactionBar extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final String? currentUserId;
  final void Function(String emoji) onTapReaction;

  const ReactionBar({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onTapReaction,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final mine = currentUserId != null && users.contains(currentUserId);
          return GestureDetector(
            onTap: () => onTapReaction(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: mine ? AppTheme.cyan.withOpacity(0.22) : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: mine ? Border.all(color: AppTheme.cyan, width: 1) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  if (users.length > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '${users.length}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade300, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
