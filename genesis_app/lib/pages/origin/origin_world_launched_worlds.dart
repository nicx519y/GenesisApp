part of 'origin_world_page.dart';

@visibleForTesting
const double originLaunchedWorldAvatarSizeForTesting = 44;

class _OriginLaunchedWorldsSection extends StatelessWidget {
  const _OriginLaunchedWorldsSection({
    required this.roles,
    required this.onEnterWorld,
  });

  final List<OriginMyLaunchPresetCharacter> roles;
  final ValueChanged<OriginMyLaunchPresetCharacter> onEnterWorld;

  @override
  Widget build(BuildContext context) {
    final visibleRoles = roles
        .where((role) => role.worldId.trim().isNotEmpty)
        .toList(growable: false);
    if (visibleRoles.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey<String>('origin-launched-worlds-section'),
      padding: const EdgeInsets.fromLTRB(
        10,
        0,
        10,
        originDetailSectionGapForTesting,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Launched Before',
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
          const SizedBox(height: 10),
          Material(
            color: originWorldDetailSheetRaisedBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, role) in visibleRoles.indexed) ...[
                  if (index > 0)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 66,
                      endIndent: 12,
                      color: Color(0x1FFFFFFF),
                    ),
                  _OriginLaunchedWorldRow(
                    role: role,
                    onTap: () => onEnterWorld(role),
                  ),
                ],
              ],
            ),
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
    final currentTime = role.currentTime.trim();
    final progressText = currentTime.isEmpty
        ? 'Tick ${role.tickCount}'
        : 'Tick ${role.tickCount} · $currentTime';

    return InkWell(
      key: ValueKey<String>('origin-launched-world-row-$worldId'),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
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
                    Text(
                      '$worldId · $progressText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w400,
                        color: originWorldDetailSheetTertiaryTextColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: originWorldDetailSheetTertiaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
