import 'package:flutter/material.dart';

import '../tokens/genesis_spacing.dart';
import '../theme/genesis_ui_theme.dart';

class GenesisBottomNavigationItem {
  const GenesisBottomNavigationItem({
    required this.label,
    required this.icon,
    this.enabled = true,
    this.prominent = false,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
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
    this.height = 58,
  });

  final List<GenesisBottomNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(color: uiTheme.bottomNavigationBackgroundColor),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding, top: GenesisSpacing.sm),
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
    final iconSize = item.prominent ? 36.0 : 20.0;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.enabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BadgedIcon(
              icon: item.icon,
              color: color,
              size: iconSize,
              badgeCount: item.badgeCount,
              badgeKey: ValueKey('bottom-nav-${item.label}-unread-badge'),
            ),
            SizedBox(
              height: item.prominent ? GenesisSpacing.xxs : GenesisSpacing.xs,
            ),
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
    required this.color,
    required this.size,
    required this.badgeCount,
    required this.badgeKey,
  });

  final IconData icon;
  final Color color;
  final double size;
  final int badgeCount;
  final Key badgeKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 18,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, color: color, size: size),
          if (badgeCount > 0)
            Positioned(
              top: 0,
              right: 0,
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
