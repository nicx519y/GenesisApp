import 'package:flutter/material.dart';

import '../../utils/stat_count_formatter.dart';

class GenesisProfileCollectionItemData {
  const GenesisProfileCollectionItemData({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.stats = const <GenesisProfileCollectionStat>[],
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final List<GenesisProfileCollectionStat> stats;
  final VoidCallback onTap;
}

class GenesisProfileCollectionStat {
  const GenesisProfileCollectionStat({required this.icon, required this.value});

  final IconData icon;
  final int value;
}

class GenesisProfileCollectionListItem extends StatelessWidget {
  const GenesisProfileCollectionListItem({super.key, required this.item});

  static const BorderRadius _borderRadius = BorderRadius.all(
    Radius.circular(14),
  );
  static const ShapeBorder _shape = RoundedRectangleBorder(
    borderRadius: _borderRadius,
  );

  final GenesisProfileCollectionItemData item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: _shape,
      // clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        // borderRadius: _borderRadius,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: _ItemImage(url: item.imageUrl),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4B6192),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6F6F6F),
                      height: 1.3,
                    ),
                  ),
                  if (item.stats.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _StatsRow(stats: item.stats),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Color(0xFFB5B5B5)),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<GenesisProfileCollectionStat> stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: stats
          .map((stat) => _Stat(icon: stat.icon, value: stat.value))
          .toList(growable: false),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.black),
        const SizedBox(width: 4),
        Text(
          formatStatCount(value),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            height: 1,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isNotEmpty) {
      return Image.network(
        url,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF9C9C9C)),
    );
  }
}
