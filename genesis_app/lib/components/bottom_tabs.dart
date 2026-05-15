import 'package:flutter/material.dart';

import '../icons/my_flutter_app_icons.dart';
import '../ui/genesis_ui.dart';

class BottomTabs extends StatelessWidget {
  const BottomTabs({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return GenesisBottomNavigation(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        GenesisBottomNavigationItem(label: 'Home', icon: MyFlutterApp.home),
        GenesisBottomNavigationItem(label: 'Origin', icon: MyFlutterApp.origin),
        GenesisBottomNavigationItem(
          label: 'Create',
          icon: MyFlutterApp.create,
          prominent: true,
        ),
        GenesisBottomNavigationItem(
          label: 'Messages',
          icon: MyFlutterApp.messages,
        ),
        GenesisBottomNavigationItem(label: 'Me', icon: MyFlutterApp.me),
      ],
    );
  }
}
