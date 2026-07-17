import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';

class RecentChatTag extends StatelessWidget {
  const RecentChatTag({super.key, this.label = 'Last Message'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = _RecentActivityTagStyle.forLabel(label);
    return Semantics(
      label: label,
      child: Container(
        key: ValueKey<String>('recent-activity-tag-${style.key}'),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            style.icon,
            const SizedBox(width: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: style.foregroundColor,
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityTagStyle {
  const _RecentActivityTagStyle({
    required this.key,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.icon,
  });

  final String key;
  final Color foregroundColor;
  final Color backgroundColor;
  final Widget icon;

  static _RecentActivityTagStyle forLabel(String label) {
    switch (label.trim()) {
      case 'Last Tick':
        return const _RecentActivityTagStyle(
          key: 'last-tick',
          foregroundColor: Color(0xFF2563EB),
          backgroundColor: Color(0xFFEAF2FF),
          icon: Icon(
            Icons.schedule_rounded,
            size: 10,
            color: Color(0xFF2563EB),
          ),
        );
      case 'Last Launch':
        return const _RecentActivityTagStyle(
          key: 'last-launch',
          foregroundColor: Color(0xFFE56A00),
          backgroundColor: Color(0xFFFFF0E3),
          icon: Icon(
            Icons.rocket_launch_rounded,
            size: 10,
            color: Color(0xFFE56A00),
          ),
        );
      default:
        return const _RecentActivityTagStyle(
          key: 'last-message',
          foregroundColor: Color(0xFF008D68),
          backgroundColor: Color(0xFFE8F5EF),
          icon: RecentChatIcon(size: 10, color: Color(0xFF008D68)),
        );
    }
  }
}

class RecentChatIcon extends StatelessWidget {
  const RecentChatIcon({
    super.key,
    this.color = const Color(0xFF008D68),
    this.size = 13,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recent chat',
      child: SvgPicture.asset(
        bottomNavMessagesIconAsset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
