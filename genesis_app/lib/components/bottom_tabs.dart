import 'package:flutter/material.dart';

import '../icons/my_flutter_app_icons.dart';
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
          icon: MyFlutterApp.home,
        ),
        const GenesisBottomNavigationItem(
          label: 'Origin',
          icon: MyFlutterApp.origin,
        ),
        const GenesisBottomNavigationItem(
          label: 'Create',
          icon: MyFlutterApp.create,
          prominent: true,
        ),
        GenesisBottomNavigationItem(
          label: 'Messages',
          icon: MyFlutterApp.messages,
          badgeCount: messagesUnreadCount,
        ),
        const GenesisBottomNavigationItem(label: 'Me', icon: MyFlutterApp.me),
      ],
    );
  }
}
