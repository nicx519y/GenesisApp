import 'package:flutter/material.dart';

import '../../ui/components/genesis_character_avatar.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../world_map_avatar_logic.dart';
import '../world_point.dart';

const double tilemapLocationAvatarSize = 42;
const double tilemapLocationAvatarSpacing = 4;
const int tilemapLocationAvatarColumnCount = 3;

class TilemapLocationAvatars extends StatelessWidget {
  const TilemapLocationAvatars({super.key, required this.avatars});

  final List<UserAvatar> avatars;

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) return const SizedBox.shrink();

    final width =
        tilemapLocationAvatarSize * tilemapLocationAvatarColumnCount +
        tilemapLocationAvatarSpacing * (tilemapLocationAvatarColumnCount - 1);
    return SizedBox(
      key: const ValueKey<String>('tilemap-location-avatars'),
      width: width,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: tilemapLocationAvatarSpacing,
        runSpacing: tilemapLocationAvatarSpacing,
        children: [
          for (final avatar in avatars)
            _TilemapLocationAvatar(
              key: ValueKey<String>(
                'tilemap-location-avatar-${worldMapAvatarStableId(avatar)}',
              ),
              avatar: avatar,
            ),
        ],
      ),
    );
  }
}

class _TilemapLocationAvatar extends StatelessWidget {
  const _TilemapLocationAvatar({super.key, required this.avatar});

  final UserAvatar avatar;

  @override
  Widget build(BuildContext context) {
    return GenesisCharacterAvatar(
      url: avatar.avatarUrl,
      name: (avatar.name ?? avatar.initials).trim(),
      size: tilemapLocationAvatarSize,
      borderRadius: GenesisAvatarRadii.character,
      showStar: avatar.showStar,
      showFallbackWhileLoading: false,
      showFallbackWhenUnavailable: true,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.26),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 3,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border.all(
        color: avatar.isPlayerControlledRole
            ? GenesisColors.brand
            : const Color(0xFFDDDDDD),
        width: 1,
      ),
    );
  }
}
