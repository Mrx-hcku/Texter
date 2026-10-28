import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../chat_bubble.dart';
import '../config/theme.dart';
import '../services/appwrite_service.dart';

/// Texter's own look: soft rounded cards, a cyan -> pink signature gradient,
/// gradient-ring avatars and tinted icon badges. Used by Channels and Groups.
const List<Color> kTexterGradient = [AppTheme.cyan, AppTheme.pink];

/// Round avatar: the person's / channel's photo, or a coloured circle with the
/// first letter. [ring] adds the cyan -> pink Texter ring.
class TexterAvatar extends StatelessWidget {
  const TexterAvatar({super.key, required this.name, this.url = '', this.size = 48, this.ring = false});
  final String name;
  final String url;
  final double size;
  final bool ring;

  Widget _letter(double s) {
    final hue = HSLColor.fromColor(NameTint.accent(name, true)).hue;
    final a = HSLColor.fromAHSL(1, hue, 0.55, 0.46).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 28) % 360, 0.60, 0.34).toColor();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
      ),
      child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: s * 0.42)),
    );
  }

  Widget _core(double s) {
    if (url.isEmpty) return _letter(s);
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: s,
        height: s,
        fit: BoxFit.cover,
        memCacheWidth: (s * 3).toInt(),
        placeholder: (_, __) => _letter(s),
        errorWidget: (_, __, ___) => _letter(s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ring) return _core(size);
    final pad = size * 0.07;
    final gap = size * 0.04;
    final inner = size - 2 * pad - 2 * gap;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(pad),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kTexterGradient),
      ),
      child: Container(
        padding: EdgeInsets.all(gap),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).scaffoldBackgroundColor),
        child: _core(inner),
      ),
    );
  }
}

/// Picks a photo from the gallery (small + compressed) and uploads it.
/// Returns the URL, or null if cancelled / failed.
Future<String?> pickAndUploadAvatar(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final x = await ChatBubble.guard(
      () => picker.pickImage(source: ImageSource.gallery, maxWidth: 640, maxHeight: 640, imageQuality: 80),
    );
    if (x == null) return null;
    return await AppwriteService.instance.uploadFile(x.path, 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload the photo. Try again.')));
    }
    return null;
  }
}

/// "Today 14:05" style time for lists.
String shortTime(DateTime t) {
  final now = DateTime.now();
  final l = t.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(l.year, l.month, l.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return DateFormat('h:mm a').format(l);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return DateFormat('EEE').format(l);
  return DateFormat('d MMM').format(l);
}

/// Message for the developer when a database attribute is missing.
String friendlyError(Object e) {
  final miss = AppwriteService.missingAttribute(e);
  if (miss != null) return 'Appwrite me "$miss" attribute add karo, phir dobara try karo.';
  return e.toString().replaceFirst('Exception: ', '');
}

/// Small section title with a Texter gradient tick.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: kTexterGradient),
            ),
          ),
          const SizedBox(width: 8),
          Text(text.toUpperCase(), style: AppTheme.body(size: 12, weight: FontWeight.w800, color: u.subtext)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Rounded-square icon with a tinted background (used in settings rows).
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? UiPalette.of(context).accent;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: c.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 20, color: c),
    );
  }
}

/// A rounded card that groups settings rows.
class TexterCard extends StatelessWidget {
  const TexterCard({super.key, required this.children, this.padding = EdgeInsets.zero});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: u.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: u.border),
      ),
      child: Column(children: children),
    );
  }
}

/// One row inside a [TexterCard]: icon badge + title / subtitle + trailing.
class TexterRow extends StatelessWidget {
  const TexterRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
    this.titleColor,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            IconBadge(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.body(size: 15, weight: FontWeight.w600, color: titleColor ?? u.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppTheme.body(size: 12.5, color: u.subtext)),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// On / off row for admin controls.
class TexterSwitchRow extends StatelessWidget {
  const TexterSwitchRow({super.key, required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final u = UiPalette.of(context);
    return TexterRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, activeColor: u.accent, onChanged: onChanged),
    );
  }
}

Widget texterDivider(BuildContext context) => Divider(height: 1, indent: 64, color: UiPalette.of(context).border);

/// Cyan -> pink pill button.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onTap, this.icon, this.busy = false, this.height = 46});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: const LinearGradient(colors: kTexterGradient),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              else ...[
                if (icon != null) ...[Icon(icon, color: Colors.white, size: 19), const SizedBox(width: 8)],
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small pill label, e.g. "Admin".
class TexterChip extends StatelessWidget {
  const TexterChip(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? UiPalette.of(context).accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
