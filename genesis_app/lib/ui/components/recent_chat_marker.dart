import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../icons/custom_icon_assets.dart';
import '../tokens/genesis_colors.dart';

const Color kRecentChatMarkerColor = GenesisColors.brand;
const Color kRecentChatMarkerBackgroundColor = Color(0xFFFFF0F2);
const Color kRecentChatMapBadgeBackgroundColor = Color(0xD9FFFFFF);
const Color kWorldEventMarkerColor = GenesisColors.brand;
const Color kWorldEventMarkerBackgroundColor = Color(0xFFFFF0F2);
const double kRecentChatMapBadgeSize = 16;
const double kRecentChatMapIconSize = 10;
const double kWorldEventMapIconSize = 12;

class RecentChatMapBadge extends StatelessWidget {
  const RecentChatMapBadge({super.key, this.badgeKey});

  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: badgeKey,
      decoration: const BoxDecoration(
        color: kRecentChatMapBadgeBackgroundColor,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: const SizedBox.square(
        dimension: kRecentChatMapBadgeSize,
        child: Center(child: RecentChatIcon(size: kRecentChatMapIconSize)),
      ),
    );
  }
}

class WorldEventMapBadge extends StatelessWidget {
  const WorldEventMapBadge({super.key, this.badgeKey});

  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: badgeKey,
      decoration: const BoxDecoration(
        color: kWorldEventMarkerBackgroundColor,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: SizedBox.square(
        dimension: kRecentChatMapBadgeSize,
        child: Center(
          child: SvgPicture.asset(
            eventsIconAsset,
            width: kWorldEventMapIconSize,
            height: kWorldEventMapIconSize,
            colorFilter: const ColorFilter.mode(
              kWorldEventMarkerColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

class RecentChatTag extends StatelessWidget {
  const RecentChatTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Last Message',
      child: Container(
        key: const ValueKey<String>('recent-activity-tag-last-message'),
        height: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: const BoxDecoration(
          color: kRecentChatMarkerBackgroundColor,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RecentChatIcon(size: 10),
            SizedBox(width: 3),
            Text(
              'Recent',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: kRecentChatMarkerColor,
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
    this.color = kRecentChatMarkerColor,
    this.size = 13,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recent chat',
      child: SvgPicture.asset(
        connectStatIconAsset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
