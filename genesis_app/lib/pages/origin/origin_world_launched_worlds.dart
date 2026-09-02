part of 'origin_world_page.dart';

@visibleForTesting
const double originLaunchedWorldAvatarSizeForTesting = 44;

@visibleForTesting
const double originLaunchedWorldSectionTopPaddingForTesting = 6;

@visibleForTesting
const double originLaunchedWorldTitleListGapForTesting = 16;

@visibleForTesting
const double originLaunchedWorldRowGapForTesting = 16;

class _OriginLaunchedWorldsSection extends StatelessWidget {
  const _OriginLaunchedWorldsSection({
    required this.roles,
    required this.onEnterWorld,
  });

  final List<OriginMyLaunchPresetCharacter> roles;
  final ValueChanged<OriginMyLaunchPresetCharacter> onEnterWorld;

  @override
  Widget build(BuildContext context) {
    final visibleRoles = roles.indexed
        .where((entry) => entry.$2.worldId.trim().isNotEmpty)
        .toList(growable: false);
    visibleRoles.sort((a, b) {
      final aLastActiveAt =
          parseFlexibleTimestamp(a.$2.lastActiveAt)?.millisecondsSinceEpoch ??
          0;
      final bLastActiveAt =
          parseFlexibleTimestamp(b.$2.lastActiveAt)?.millisecondsSinceEpoch ??
          0;
      final timeComparison = bLastActiveAt.compareTo(aLastActiveAt);
      return timeComparison != 0 ? timeComparison : a.$1.compareTo(b.$1);
    });
    if (visibleRoles.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey<String>('origin-launched-worlds-section'),
      padding: const EdgeInsets.fromLTRB(
        10,
        originLaunchedWorldSectionTopPaddingForTesting,
        10,
        originDetailSectionGapForTesting -
            originLaunchedWorldSectionTopPaddingForTesting,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Playing World',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: originWorldDetailSheetPrimaryTextColor,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: originLaunchedWorldTitleListGapForTesting),
          Column(
            key: const ValueKey<String>('origin-playing-world-list'),
            children: [
              for (final (index, entry) in visibleRoles.indexed) ...[
                if (index > 0)
                  const SizedBox(height: originLaunchedWorldRowGapForTesting),
                _OriginLaunchedWorldRow(
                  role: entry.$2,
                  onTap: () => onEnterWorld(entry.$2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _OriginLaunchedWorldRow extends StatelessWidget {
  const _OriginLaunchedWorldRow({required this.role, required this.onTap});

  final OriginMyLaunchPresetCharacter role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final worldId = role.worldId.trim();
    final roleName = role.name.trim().isNotEmpty
        ? role.name.trim()
        : role.charId.trim();
    final subTickLabel = role.subTickNo > 0 ? '-${role.subTickNo}' : '';
    final statsLabel =
        'Tick ${role.tickCount}$subTickLabel · '
        '${formatMessageCountLabel(role.messageCount)}';
    final lastActiveLabel = formatGenesisTimestamp(role.lastActiveAt);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey<String>('origin-launched-world-row-$worldId'),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GenesisCharacterAvatar(
              key: ValueKey<String>('origin-launched-world-avatar-$worldId'),
              url: role.avatar,
              name: roleName,
              size: originLaunchedWorldAvatarSizeForTesting,
              borderRadius: GenesisAvatarRadii.character,
              showFallbackWhileLoading: false,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: originWorldDetailSheetPrimaryTextColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          statsLabel,
                          key: ValueKey<String>(
                            'origin-playing-world-stats-$worldId',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                            color: originWorldDetailSheetSecondaryTextColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      if (lastActiveLabel.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          lastActiveLabel,
                          key: ValueKey<String>(
                            'origin-playing-world-last-active-$worldId',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.1,
                            fontWeight: FontWeight.w400,
                            color: originWorldDetailSheetTertiaryTextColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
