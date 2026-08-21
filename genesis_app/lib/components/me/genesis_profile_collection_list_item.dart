import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';

import '../origin/stat_item.dart';
import '../../utils/stat_count_formatter.dart';

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
    this.useRedesignedLayout = false,
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
  final bool useRedesignedLayout;
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
    final redesigned = item.useRedesignedLayout;
    return Material(
      color: context.genesisColors.surface,
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
                  width: redesigned ? 60 : 52,
                  height: redesigned ? 78 : 52,
                  borderRadius: redesigned
                      ? BorderRadius.circular(12)
                      : GenesisImageRadii.content,
                ),
                SizedBox(width: redesigned ? 12 : 10),
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
                              style: TextStyle(
                                fontSize: redesigned ? 15 : 14,
                                height: redesigned ? 1.15 : 1.1,
                                fontWeight: redesigned
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: redesigned
                                    ? context.genesisColors.foregroundStrong
                                    : context.genesisColors.accentText,
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
                      _Subtitle(text: item.subtitle, redesigned: redesigned),
                      if (item.stats.isNotEmpty) ...[
                        SizedBox(height: redesigned ? 7 : 8),
                        _StatsRow(stats: item.stats, redesigned: redesigned),
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

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text, required this.redesigned});

  final String text;
  final bool redesigned;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: redesigned ? 10 : 12,
      color: redesigned
          ? context.genesisColors.textFaint
          : context.genesisColors.textSecondary,
      height: redesigned ? 1.4 : 1.3,
    );
    if (!redesigned || !text.contains('\n')) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lines.first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        const SizedBox(height: 3),
        Text(
          lines.skip(1).join(' '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.redesigned});

  final List<GenesisProfileCollectionStat> stats;
  final bool redesigned;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: redesigned ? 12 : 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: stats
          .map(
            (stat) => _Stat(
              icon: stat.icon,
              iconAsset: stat.iconAsset,
              preserveIconAssetColor: stat.preserveIconAssetColor,
              value: stat.value,
              redesigned: redesigned,
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
    required this.redesigned,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
  final int value;
  final bool redesigned;

  @override
  Widget build(BuildContext context) {
    final usesAccent = redesigned && preserveIconAssetColor;
    final color = usesAccent
        ? context.genesisColors.accentText
        : redesigned
        ? context.genesisColors.textFaint
        : context.genesisColors.navigationSelected;
    return StatItem(
      icon: icon,
      iconAsset: iconAsset,
      preserveIconAssetColor: preserveIconAssetColor,
      iconSize: 11,
      iconColor: color,
      iconVerticalOffset: redesigned ? 0 : -0.8,
      gap: 4,
      text: formatStatCount(value),
      textStyle: TextStyle(
        color: color,
        fontSize: redesigned ? 10 : 12,
        height: 1,
        fontWeight: redesigned ? FontWeight.w500 : FontWeight.w400,
      ),
    );
  }
}
