import 'package:flutter/material.dart';

import '../../models/origin_item.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../utils/display_name_formatter.dart';

class OriginCard extends StatelessWidget {
  const OriginCard({super.key, required this.item});

  final OriginItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: item.coverHeight,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GenesisListImage(imageUrl: item.coverImageUrl),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          originDisplayName(item.title),
          style: const TextStyle(
            color: Color(0xFF4B6192),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          item.subtitle,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w400,
            fontSize: 10,
            height: 1.6,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in item.tags)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Color(0xFF4B6192),
                    fontSize: 10,
                    height: 1.7,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
