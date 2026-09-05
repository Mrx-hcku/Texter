import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../models/models.dart';

class SponsoredAdCard extends StatelessWidget {
  final AdModel ad;
  const SponsoredAdCard({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.pink.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.campaign, size: 14, color: AppTheme.pink),
                const SizedBox(width: 4),
                Text('SPONSORED', style: AppTheme.body(size: 11, weight: FontWeight.w700, color: AppTheme.pink)),
              ],
            ),
          ),
          if (ad.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CachedNetworkImage(
                  imageUrl: ad.imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(height: 150, color: AppTheme.surfaceLight),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.title, style: AppTheme.body(size: 15, weight: FontWeight.w700, color: Colors.white)),
                if (ad.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(ad.description, style: AppTheme.body(size: 12.5, color: AppTheme.textSecondary)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.pink, minimumSize: const Size.fromHeight(42)),
                    child: Text(ad.actionText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
