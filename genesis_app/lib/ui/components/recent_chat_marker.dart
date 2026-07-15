import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';

class RecentChatTag extends StatelessWidget {
  const RecentChatTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recent chat',
      child: Container(
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5EF),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RecentChatIcon(size: 10, color: Color(0xFF008D68)),
            const SizedBox(width: 3),
            const Text(
              'Recent',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: Color(0xFF008D68),
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
