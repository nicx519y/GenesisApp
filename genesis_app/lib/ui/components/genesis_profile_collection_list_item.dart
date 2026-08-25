import 'package:flutter/material.dart';

import '../../components/origin/stat_item.dart';
import '../../utils/stat_count_formatter.dart';
import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_image_radii.dart';
import 'genesis_list_image.dart';

class GenesisProfileCollectionItemData {
  const GenesisProfileCollectionItemData({
    this.animationKey,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.stats = const <GenesisProfileCollectionStat>[],
    this.isCollapsing = false,
    this.showPressedBackground = true,
    this.enableFeedback = true,
    this.onTap,
    this.onLongPress,
    this.onCollapsed,
    this.useRedesignedLayout = false,
    this.titleTrailing,
    this.onTitleTrailingTap,
    this.titleTrailingSemanticsLabel,
  });

  final Object? animationKey;
  final String imageUrl;
  final String title;
  final String subtitle;
  final List<GenesisProfileCollectionStat> stats;
  final bool isCollapsing;
  final bool showPressedBackground;
  final bool enableFeedback;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onCollapsed;
  final bool useRedesignedLayout;

  /// Optional adornment pinned to the far right of the title line. It is laid
  /// out inside the line, so it aligns to the title's bottom edge exactly and
  /// costs no row height while it is shorter than the line box.
  final Widget? titleTrailing;

  /// Makes [titleTrailing] tappable. The handler is wired to a transparent
  /// [titleTrailingWidth] square stacked over the corner rather than to the
  /// adornment itself, so the touch target is a full 44 without the adornment
  /// having to be 44 in layout.
  final VoidCallback? onTitleTrailingTap;
  final String? titleTrailingSemanticsLabel;
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

  /// Touch target for [onTitleTrailingTap]. The square is stacked over the
  /// column's top-right corner, so the rows below it give up
  /// [titleTrailingWidth] of width rather than the row giving up height.
  static const double titleTrailingWidth = 44;
  static const double titleTrailingGap = 8;

  final GenesisProfileCollectionItemData item;

  @override
  Widget build(BuildContext context) {
    final redesigned = item.useRedesignedLayout;
    final coveredWidth = item.onTitleTrailingTap == null
        ? 0.0
        : titleTrailingWidth;
    return Material(
      color: context.genesisColors.surface,
      shape: _shape,
      // The row tap lives on an InkWell that *wraps* the content rather than a
      // Positioned.fill sibling above it: an overlay sibling is hit-tested
      // first and swallows taps meant for controls inside the row, such as
      // [titleSuffix].
      child: InkWell(
        overlayColor: item.showPressedBackground
            ? null
            : const WidgetStatePropertyAll<Color>(Colors.transparent),
        enableFeedback: item.enableFeedback,
        onTap: item.onTap,
        onLongPress: item.onLongPress,
        child: SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GenesisListImage(
                imageUrl: item.imageUrl,
                width: redesigned ? 60 : 52,
                height: redesigned ? 78 : 52,
                // 9k: the 60x78 cover is radius 8.
                borderRadius: redesigned
                    ? BorderRadius.circular(8)
                    : GenesisImageRadii.content,
              ),
              SizedBox(width: redesigned ? 12 : 10),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          // The adornment rides the title's bottom edge; being
                          // in the line means the text engine's own metrics
                          // decide that edge, not a duplicated constant.
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: redesigned ? 14 : 13,
                                  height: 1.1,
                                  fontWeight: FontWeight.w600,
                                  color: redesigned
                                      ? context.genesisColors.textPrimary
                                      : context.genesisColors.accentText,
                                ),
                              ),
                            ),
                            if (item.titleTrailing case final trailing?) ...[
                              const SizedBox(width: titleTrailingGap),
                              trailing,
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        // Only the rows under the touch square give up width;
                        // the title line already reserved room for the
                        // adornment itself.
                        Padding(
                          padding: EdgeInsets.only(right: coveredWidth),
                          child: _Subtitle(
                            text: item.subtitle,
                            redesigned: redesigned,
                          ),
                        ),
                        if (item.stats.isNotEmpty) ...[
                          SizedBox(height: redesigned ? 7 : 8),
                          Padding(
                            padding: EdgeInsets.only(right: coveredWidth),
                            child: _StatsRow(
                              stats: item.stats,
                              redesigned: redesigned,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // A Stack only hit-tests inside its own box, so this stays
                    // tappable while the column is at least as tall as the
                    // square - which the cover height already guarantees.
                    if (item.onTitleTrailingTap case final onTap?)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Semantics(
                          button: true,
                          label: item.titleTrailingSemanticsLabel,
                          child: GestureDetector(
                            key: const ValueKey<String>(
                              'profile-collection-title-trailing-tap',
                            ),
                            behavior: HitTestBehavior.opaque,
                            onTap: onTap,
                            child: const SizedBox.square(
                              dimension: titleTrailingWidth,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
      fontSize: redesigned ? 12 : 11,
      color: context.genesisColors.textSecondary,
      height: 1.3,
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
        ? context.genesisColors.textMetadata
        : context.genesisColors.navigationSelected;
    return StatItem(
      icon: icon,
      iconAsset: iconAsset,
      preserveIconAssetColor: preserveIconAssetColor,
      iconSize: 12,
      iconColor: color,
      iconVerticalOffset: redesigned ? 0 : -0.8,
      gap: 4,
      text: formatStatCount(value),
      textStyle: TextStyle(
        color: color,
        fontSize: redesigned ? 12 : 11,
        height: 1,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
