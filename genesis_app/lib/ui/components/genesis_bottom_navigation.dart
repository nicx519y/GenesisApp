import 'package:flutter/material.dart';

import '../tokens/genesis_spacing.dart';
import '../theme/genesis_ui_theme.dart';

class GenesisBottomNavigationItem {
  const GenesisBottomNavigationItem({
    required this.label,
    required this.icon,
    this.enabled = true,
    this.prominent = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool prominent;
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
            Icon(item.icon, color: color, size: iconSize),
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
