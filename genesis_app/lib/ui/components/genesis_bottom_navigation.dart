import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import 'genesis_safe_area.dart';
import 'genesis_unread_badge.dart';
import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';

class GenesisBottomNavigationItem {
  const GenesisBottomNavigationItem({
    required this.label,
    this.icon,
    this.iconAsset,
    this.selectedIconAsset,
    this.enabled = true,
    this.prominent = false,
    this.showLabel = true,
    this.iconSize,
    this.iconShadows,
    this.badgeCount = 0,
  }) : assert(icon != null || iconAsset != null);

  final String label;
  final IconData? icon;
  final String? iconAsset;
  final String? selectedIconAsset;
  final bool enabled;
  final bool prominent;
  final bool showLabel;
  final double? iconSize;
  final List<Shadow>? iconShadows;
  final int badgeCount;
}

class GenesisBottomNavigation extends StatelessWidget {
  const GenesisBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = defaultHeight,
  });

  static const double defaultHeight = 49;
  static const double minBottomPadding = 4;

  final List<GenesisBottomNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.navigationBackground,
        boxShadow: [
          BoxShadow(color: colors.shadow, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: GenesisBottomSafePadding(
        minimum: minBottomPadding,
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var index = 0; index < items.length; index += 1)
                GenesisBottomNavigationTile(
                  item: items[index],
                  selected: currentIndex == index,
                  onTap: () => onTap(index),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GenesisBottomNavigationTile extends StatelessWidget {
  const GenesisBottomNavigationTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GenesisBottomNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final color = item.prominent
        ? colors.danger
        : selected
        ? colors.navigationSelected
        : colors.navigationUnselected;
    final iconSize =
        item.iconSize ??
        (item.prominent
            ? 22.0
            : item.iconAsset == null
            ? 20.0
            : 24.0);
    final iconAsset = selected
        ? item.selectedIconAsset ?? item.iconAsset
        : item.iconAsset;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.enabled
            ? () {
                GenesisTelemetry.click(
                  actionId: 'bottom_tab.${_actionSlug(item.label)}',
                  component: 'GenesisBottomNavigationTile',
                  enabled: true,
                  data: <String, Object?>{
                    'label': item.label,
                    'selected': selected,
                  },
                );
                onTap();
              }
            : null,
        child: Semantics(
          key: ValueKey<String>('bottom-nav-${item.label}'),
          button: true,
          enabled: item.enabled,
          selected: selected,
          label: item.label,
          excludeSemantics: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.prominent)
                _ProminentNavigationIcon(
                  icon: item.icon,
                  assetName: iconAsset,
                  size: iconSize,
                  shadows: item.iconShadows,
                  backgroundColor: color,
                  foregroundColor: colors.onDanger,
                )
              else
                _BadgedIcon(
                  icon: item.icon,
                  assetName: iconAsset,
                  color: color,
                  size: iconSize,
                  badgeCount: item.badgeCount,
                  badgeKey: ValueKey('bottom-nav-${item.label}-unread-badge'),
                ),
              if (item.showLabel) ...[
                SizedBox(height: item.prominent ? 1 : GenesisSpacing.xxs),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GenesisTypography.tabLabel.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProminentNavigationIcon extends StatelessWidget {
  const _ProminentNavigationIcon({
    required this.icon,
    required this.assetName,
    required this.size,
    required this.shadows,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData? icon;
  final String? assetName;
  final double size;
  final List<Shadow>? shadows;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 33,
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: const ContinuousRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      alignment: Alignment.center,
      child: assetName != null
          ? assetName!.endsWith('.svg')
                ? SvgPicture.asset(
                    assetName!,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(
                      foregroundColor,
                      BlendMode.srcIn,
                    ),
                  )
                : Image.asset(
                    assetName!,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    color: foregroundColor,
                  )
          : Icon(icon, color: foregroundColor, size: size, shadows: shadows),
    );
  }
}

String _actionSlug(String label) {
  final normalized = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'unknown' : normalized;
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.assetName,
    required this.color,
    required this.size,
    required this.badgeCount,
    required this.badgeKey,
  });

  final IconData? icon;
  final String? assetName;
  final Color color;
  final double size;
  final int badgeCount;
  final Key badgeKey;

  @override
  Widget build(BuildContext context) {
    final boxSize = size + 12;
    return SizedBox(
      width: boxSize,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (assetName != null)
            assetName!.endsWith('.svg')
                ? SvgPicture.asset(
                    assetName!,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  )
                : Image.asset(
                    assetName!,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                  )
          else if (icon != null)
            Icon(icon, color: color, size: size)
          else
            SizedBox.square(dimension: size),
          if (badgeCount > 0)
            Positioned(
              left: boxSize / 2 + size / 2 - 11,
              top: -1,
              child: GenesisUnreadBadge(key: badgeKey, count: badgeCount),
            ),
        ],
      ),
    );
  }
}
