import 'package:flutter/material.dart';

import '../tokens/genesis_spacing.dart';
import '../theme/genesis_ui_theme.dart';

class GenesisBottomNavigationItem {
  const GenesisBottomNavigationItem({
    required this.label,
    this.icon,
    this.iconAsset,
    this.selectedIconAsset,
    this.enabled = true,
    this.prominent = false,
    this.badgeCount = 0,
  }) : assert(icon != null || iconAsset != null);

  final String label;
  final IconData? icon;
  final String? iconAsset;
  final String? selectedIconAsset;
  final bool enabled;
  final bool prominent;
  final int badgeCount;
}

class GenesisBottomNavigation extends StatelessWidget {
  const GenesisBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.height = 49,
  });

  final List<GenesisBottomNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
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
    final uiTheme = GenesisUiTheme.of(context);
    final color = item.prominent
        ? uiTheme.bottomNavigationProminentColor
        : selected
        ? uiTheme.bottomNavigationSelectedColor
        : uiTheme.bottomNavigationUnselectedColor;
    final iconSize = item.prominent
        ? 28.0
        : item.iconAsset == null
        ? 20.0
        : 24.0;
    final iconAsset = selected
        ? item.selectedIconAsset ?? item.iconAsset
        : item.iconAsset;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.enabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BadgedIcon(
              icon: item.icon,
              assetName: iconAsset,
              color: color,
              size: iconSize,
              badgeCount: item.badgeCount,
              badgeKey: ValueKey('bottom-nav-${item.label}-unread-badge'),
            ),
            SizedBox(height: item.prominent ? 1 : GenesisSpacing.xxs),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiTheme.tabLabelStyle.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            Image.asset(
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
              top: 1,
              right: -11,
              child: _UnreadBadge(key: badgeKey, count: badgeCount),
            ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF42C47),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
