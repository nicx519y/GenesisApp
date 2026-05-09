import 'package:flutter/material.dart';

import '../icons/my_flutter_app_icons.dart';

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
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding, top: 6),
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomTabItem(
                label: 'Home',
                icon: MyFlutterApp.home,
                selected: currentIndex == 0,
                enabled: false,
                onTap: () => onTap(0),
              ),
              _BottomTabItem(
                label: 'Origin',
                icon: MyFlutterApp.origin,
                selected: currentIndex == 1,
                enabled: true,
                onTap: () => onTap(1),
              ),
              _BottomCreateItem(enabled: false, onTap: () => onTap(2)),
              _BottomTabItem(
                label: 'Messages',
                icon: MyFlutterApp.messages,
                selected: currentIndex == 3,
                enabled: false,
                onTap: () => onTap(3),
              ),
              _BottomTabItem(
                label: 'Me',
                icon: MyFlutterApp.me,
                selected: currentIndex == 4,
                enabled: false,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTabItem extends StatelessWidget {
  const _BottomTabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.black : const Color(0xFF9E9E9E);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                height: 1.4,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomCreateItem extends StatelessWidget {
  const _BottomCreateItem({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MyFlutterApp.create, color: const Color(0xFF338960), size: 36),
            const SizedBox(height: 2),
            const Text(
              'Create',
              style: TextStyle(color: Color(0xFF338960), fontSize: 10, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
