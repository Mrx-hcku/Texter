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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Icon(Icons.campaign, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Sponsored', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
                  errorWidget: (_, __, ___) => Container(height: 150, color: Colors.grey.shade200),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (ad.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(ad.description, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
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
