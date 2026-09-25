import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Kisi bhi network image (Appwrite storage se) ko safely dikhane ke liye.
/// URL null ho, khaali ho, ya 404/network-error aaye — kabhi bhi app crash
/// nahi karegi, sirf ek placeholder icon dikha degi.
class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData placeholderIcon;
  final BorderRadius? borderRadius;

  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.broken_image_outlined,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final child = (url == null || url!.trim().isEmpty)
        ? _placeholder()
        : CachedNetworkImage(
            imageUrl: url!,
            width: width,
            height: height,
            fit: fit,
            placeholder: (context, _) => Container(
              width: width,
              height: height,
              color: Colors.grey.shade800,
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            // Ye hi asli fix hai: error yahin local level pe pakड़a jata hai,
            // poori app tak kabhi pahunchta hi nahi.
            errorWidget: (context, _, error) => _placeholder(),
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade800,
      child: Icon(placeholderIcon, color: Colors.grey.shade500, size: (height ?? 40) * 0.5),
    );
  }
}
