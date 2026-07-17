import 'package:flutter/material.dart';

import '../../components/origin/stat_item.dart';
import '../../utils/stat_count_formatter.dart';
import '../tokens/genesis_image_radii.dart';
import 'genesis_list_image.dart';
import 'recent_chat_marker.dart';

class GenesisProfileCollectionItemData {
  const GenesisProfileCollectionItemData({
    this.animationKey,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.stats = const <GenesisProfileCollectionStat>[],
    this.showRecentChatTag = false,
    this.isCollapsing = false,
    this.showPressedBackground = true,
    this.enableFeedback = true,
    this.onTap,
    this.onLongPress,
    this.onCollapsed,
  });

  final Object? animationKey;
  final String imageUrl;
  final String title;
  final String subtitle;
  final List<GenesisProfileCollectionStat> stats;
  final bool showRecentChatTag;
  final bool isCollapsing;
  final bool showPressedBackground;
  final bool enableFeedback;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCollapsed;
}

class GenesisProfileCollectionStat {
  const GenesisProfileCollectionStat({
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
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
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GenesisListImage(
                  imageUrl: item.imageUrl,
                  width: 52,
                  height: 52,
                  borderRadius: GenesisImageRadii.content,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B6192),
                              ),
                            ),
                          ),
                          if (item.showRecentChatTag) ...[
                            const SizedBox(width: 6),
                            const RecentChatTag(),
                          ],
                        ],
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
              ],
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  overlayColor: item.showPressedBackground
                      ? null
                      : const WidgetStatePropertyAll<Color>(Colors.transparent),
                  enableFeedback: item.enableFeedback,
                  onTap: item.onTap,
                  onLongPress: item.onLongPress,
                ),
              ),
            ),
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
          .map(
            (stat) => _Stat(
              icon: stat.icon,
              iconAsset: stat.iconAsset,
              preserveIconAssetColor: stat.preserveIconAssetColor,
              value: stat.value,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    return StatItem(
      icon: icon,
      iconAsset: iconAsset,
      preserveIconAssetColor: preserveIconAssetColor,
      iconSize: 11,
      iconColor: Colors.black,
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        color: Colors.black,
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
