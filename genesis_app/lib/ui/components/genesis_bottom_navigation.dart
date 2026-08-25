import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'genesis_safe_area.dart';
import 'genesis_unread_badge.dart';
import 'genesis_ui_interaction.dart';
import '../theme/genesis_semantic_colors.dart';
import '../tokens/genesis_spacing.dart';
import '../tokens/genesis_typography.dart';

/// 普通 item 的图标边长与标签行高 —— create 按钮按这两个值对齐高度,
/// 三者同源,改一处不会漂。
const double _navIconSize = 22;
const double _navLabelHeight = 9.5;

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
      // navigationBackground is the page colour, and there is no rule or lift
      // above the bar - it reads as part of the background.
      decoration: BoxDecoration(color: colors.navigationBackground),
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
                GenesisUiInteractionScope.notify(
                  context,
                  GenesisUiInteraction(
                    actionId: 'bottom_tab.${_actionSlug(item.label)}',
                    component: 'GenesisBottomNavigationTile',
                    enabled: true,
                    data: <String, Object?>{
                      'label': item.label,
                      'selected': selected,
                    },
                  ),
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
                  // Bottom bar labels: 9.5px, 600 when active and 500 when
                  // idle. Active sits on soft white, idle on the 32% tier.
                  style: GenesisTypography.tabLabel.copyWith(
                    color: color,
                    fontSize: 9.5,
                    height: 1,
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
    // 形状取自设计稿 9l 底栏的 create 按钮:
    //   width:50px; height:38px; border-radius:12px; background:#F82B3C
    // 但高度改为与同排 item 的「图标 + 间距 + 标签」布局盒等高,否则红块会比
    // 旁边的图标文字高出一截。宽度与圆角按设计稿的 50:38:12 等比缩。
    //
    // 设计稿那条 margin-bottom:3 不带:我们的 item 内容带只有 50,加上去会让
    // Column 溢出 3px(真机上只显示成黄黑警告条,很容易漏掉)。
    //
    // 原先是 42x33 配 ContinuousRectangleBorder(20) —— 连续曲率在 33 高的盒子上
    // 会把圆角铺满整体,渲染成异形 blob。这里改用标准 RoundedRectangleBorder。
    const stackHeight = _navIconSize + GenesisSpacing.xxs + _navLabelHeight;
    const scale = stackHeight / 38;
    return Container(
      width: 50 * scale,
      height: stackHeight,
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12 * scale)),
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
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  )
                : Image.asset(
                    assetName!,
                    width: size,
                    height: size,
                    fit: BoxFit.contain,
                    color: color,
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
