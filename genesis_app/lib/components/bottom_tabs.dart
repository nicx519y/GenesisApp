import '../app/qa/qa_ids.dart';
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
      items: [
        const GenesisBottomNavigationItem(
          label: 'Home',
          qaId: QaIds.homeTab,
          iconAsset: bottomNavHomeIconAsset,
          selectedIconAsset: bottomNavHomePressIconAsset,
        ),
        const GenesisBottomNavigationItem(
          label: 'Worldo',
          qaId: QaIds.worldoTab,
          iconAsset: bottomNavOriginIconAsset,
          selectedIconAsset: bottomNavOriginPressIconAsset,
        ),
        const GenesisBottomNavigationItem(
          label: 'Create',
          qaId: QaIds.createTab,
          icon: Icons.add_rounded,
          prominent: true,
          showLabel: false,
          iconSize: 26,
          iconShadows: [
            Shadow(
              color: GenesisColors.darkTextPrimary,
              offset: Offset(0.5, 0),
            ),
            Shadow(
              color: GenesisColors.darkTextPrimary,
              offset: Offset(-0.5, 0),
            ),
            Shadow(
              color: GenesisColors.darkTextPrimary,
              offset: Offset(0, 0.5),
            ),
            Shadow(
              color: GenesisColors.darkTextPrimary,
              offset: Offset(0, -0.5),
            ),
          ],
        ),
        GenesisBottomNavigationItem(
          label: 'Inbox',
          qaId: QaIds.inboxTab,
          iconAsset: bottomNavInboxIconAsset,
          selectedIconAsset: bottomNavInboxPressIconAsset,
          badgeCount: messagesUnreadCount,
        ),
        const GenesisBottomNavigationItem(
          label: 'Me',
          qaId: QaIds.meTab,
          iconAsset: bottomNavMeIconAsset,
          selectedIconAsset: bottomNavMePressIconAsset,
        ),
      ],
    );
  }
}
