import 'package:flutter/material.dart';

import '../icons/custom_icon_assets.dart';
import '../ui/genesis_ui.dart';

class BottomTabs extends StatelessWidget {
  const BottomTabs({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.messagesUnreadCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final int messagesUnreadCount;

  @override
  Widget build(BuildContext context) {
    return GenesisBottomNavigation(
      currentIndex: currentIndex,
      onTap: onTap,
      height: 54,
      items: [
        const GenesisBottomNavigationItem(
          label: 'Home',
          iconAsset: bottomNavHomeIconAsset,
          selectedIconAsset: bottomNavHomePressIconAsset,
          iconSize: 22,
        ),
        const GenesisBottomNavigationItem(
          label: 'Worlds',
          iconAsset: bottomNavOriginIconAsset,
          selectedIconAsset: bottomNavOriginPressIconAsset,
          iconSize: 22,
        ),
        const GenesisBottomNavigationItem(
          label: 'Create',
          iconAsset: bottomNavCreateIconAsset,
          prominent: true,
          showLabel: false,
          iconSize: 16,
        ),
        GenesisBottomNavigationItem(
          label: 'Messages',
          iconAsset: bottomNavMessagesIconAsset,
          selectedIconAsset: bottomNavMessagesPressIconAsset,
          iconSize: 22,
          badgeCount: messagesUnreadCount,
        ),
        const GenesisBottomNavigationItem(
          label: 'Me',
          iconAsset: bottomNavMeIconAsset,
          selectedIconAsset: bottomNavMePressIconAsset,
          iconSize: 22,
        ),
      ],
    );
  }
}
