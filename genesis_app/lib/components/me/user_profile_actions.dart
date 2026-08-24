part of 'user_profile_library.dart';

class _FollowStats extends StatelessWidget {
  const _FollowStats({
    required this.followingCount,
    required this.followerCount,
    required this.onFollowingTap,
    required this.onFollowersTap,
    this.compact = false,
  });

  final int followingCount;
  final int followerCount;
  final VoidCallback onFollowingTap;
  final VoidCallback onFollowersTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final style = TextStyle(
      fontSize: compact ? 13 : 15,
      height: 1,
      color: colors.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final labelStyle = TextStyle(
      fontSize: compact ? 11 : 13,
      height: 1,
      color: colors.textMuted,
      fontWeight: FontWeight.w400,
    );

    final stats = Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _FollowStatButton(
          onTap: onFollowingTap,
          count: formatStatCount(followingCount),
          label: 'Following',
          countStyle: style,
          labelStyle: labelStyle,
        ),
        const SizedBox(width: 16),
        _FollowStatButton(
          onTap: onFollowersTap,
          count: formatStatCount(followerCount),
          label: 'Followers',
          countStyle: style,
          labelStyle: labelStyle,
        ),
      ],
    );
    if (!compact) return stats;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: stats,
    );
  }
}

class _FollowStatButton extends StatelessWidget {
  const _FollowStatButton({
    required this.onTap,
    required this.count,
    required this.label,
    required this.countStyle,
    required this.labelStyle,
  });

  final VoidCallback onTap;
  final String count;
  final String label;
  final TextStyle countStyle;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(count, style: countStyle),
            const SizedBox(width: 4),
            Text(label, style: labelStyle),
          ],
        ),
      ),
    );
  }
}

class _ProfileActionButtons extends StatelessWidget {
  const _ProfileActionButtons({
    required this.isFollowed,
    required this.followLoading,
    required this.onFollowToggle,
    required this.onMessage,
  });

  final bool isFollowed;
  final bool followLoading;
  final VoidCallback onFollowToggle;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    final backgroundColor = isFollowed ? colors.surfaceDisabled : colors.danger;
    final foregroundColor = isFollowed
        ? colors.foregroundStrong
        : colors.onDanger;
    final disabledBackgroundColor = isFollowed
        ? colors.surfaceDisabled
        : colors.danger.withValues(alpha: 0.55);
    final disabledForegroundColor = isFollowed
        ? colors.foregroundStrong.withValues(alpha: 0.54)
        : colors.onDanger;
    const actionTextStyle = TextStyle(fontWeight: FontWeight.w600);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: FilledButton(
              key: const ValueKey('user-profile-follow-button'),
              onPressed: followLoading ? null : onFollowToggle,
              style: FilledButton.styleFrom(
                backgroundColor: backgroundColor,
                disabledBackgroundColor: disabledBackgroundColor,
                foregroundColor: foregroundColor,
                disabledForegroundColor: disabledForegroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: followLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: disabledForegroundColor,
                      ),
                    )
                  : Text(
                      isFollowed ? 'Following' : 'Follow',
                      style: actionTextStyle,
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 36,
            child: FilledButton(
              key: const ValueKey('user-profile-message-button'),
              onPressed: onMessage,
              style: FilledButton.styleFrom(
                backgroundColor: colors.surfaceDisabled,
                disabledBackgroundColor: colors.surfaceDisabled,
                foregroundColor: colors.foregroundStrong,
                disabledForegroundColor: colors.foregroundStrong.withValues(
                  alpha: 0.54,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Message', style: actionTextStyle),
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.name,
    required this.urlListenable,
    required this.nameListenable,
    required this.isUpdating,
    required this.updatingListenable,
    required this.onEdit,
    this.size = 80,
    this.radius = GenesisAvatarRadii.user,
    this.redesigned = false,
  });

  final String url;
  final String name;
  final ValueListenable<String>? urlListenable;
  final ValueListenable<String>? nameListenable;
  final bool isUpdating;
  final ValueListenable<bool>? updatingListenable;
  final VoidCallback? onEdit;
  final double size;
  final double radius;
  final bool redesigned;

  @override
  Widget build(BuildContext context) {
    final listenableName = nameListenable;
    if (listenableName != null) {
      return ValueListenableBuilder<String>(
        valueListenable: listenableName,
        builder: (context, displayName, _) => _buildUrlLayer(
          context,
          displayName.trim().isEmpty ? name : displayName,
        ),
      );
    }
    return _buildUrlLayer(context, name);
  }

  Widget _buildUrlLayer(BuildContext context, String displayName) {
    final avatarListenable = urlListenable;
    if (avatarListenable == null) {
      return _buildAvatar(context, url, displayName, isUpdating);
    }
    return ValueListenableBuilder<String>(
      valueListenable: avatarListenable,
      builder: (context, avatarUrl, _) {
        final loadingListenable = updatingListenable;
        if (loadingListenable == null) {
          return _buildAvatar(context, avatarUrl, displayName, isUpdating);
        }
        return ValueListenableBuilder<bool>(
          valueListenable: loadingListenable,
          builder: (context, updating, _) =>
              _buildAvatar(context, avatarUrl, displayName, updating),
        );
      },
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    String avatarUrl,
    String displayName,
    bool updating,
  ) {
    final colors = context.genesisColors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GenesisAvatar(
            url: avatarUrl,
            name: displayName,
            size: size,
            borderRadius: radius,
            imageKey: const ValueKey('user-profile-avatar-image'),
            fallbackBackgroundColor: redesigned ? colors.danger : null,
            textStyle: redesigned
                ? TextStyle(
                    color: colors.onDanger,
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        color: colors.accentText,
                        offset: const Offset(2.5, 2.5),
                      ),
                    ],
                  )
                : null,
          ),
          if (onEdit != null)
            Positioned(
              right: redesigned ? -4 : 2,
              bottom: redesigned ? -4 : 2,
              child: Material(
                key: const ValueKey<String>('profile-avatar-edit-button'),
                color: redesigned
                    ? colors.surfaceRaised
                    : colors.scrim.withValues(alpha: 0.4),
                shape: CircleBorder(
                  side: redesigned
                      ? BorderSide(color: colors.borderStrong)
                      : BorderSide.none,
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: updating ? null : onEdit,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    // Same pencil as the inline text edit affordance, so the
                    // two edit entry points read as one glyph.
                    child: SvgPicture.asset(
                      editPencilLineIconAsset,
                      width: 12,
                      height: 12,
                      colorFilter: ColorFilter.mode(
                        redesigned ? colors.textPrimary : colors.textInverse,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DisplayNameText extends StatelessWidget {
  const _DisplayNameText({
    required this.displayName,
    required this.displayNameListenable,
    this.redesigned = false,
  });

  final String displayName;
  final ValueListenable<String>? displayNameListenable;
  final bool redesigned;

  @override
  Widget build(BuildContext context) {
    final listenable = displayNameListenable;
    if (listenable == null) {
      return _buildName(context, displayName);
    }
    return ValueListenableBuilder<String>(
      valueListenable: listenable,
      builder: (context, name, _) {
        final resolvedName = name.trim().isEmpty ? displayName : name;
        return _buildName(context, resolvedName);
      },
    );
  }

  Widget _buildName(BuildContext context, String name) {
    if (redesigned) {
      return GenesisDisplayTitle(
        text: name,
        style: TextStyle(color: context.genesisColors.foregroundStrong),
      );
    }
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 17,
        height: 1,
        fontWeight: FontWeight.w800,
        color: context.genesisColors.foregroundStrong,
      ),
    );
  }
}

class _ProfileEditButton extends StatelessWidget {
  const _ProfileEditButton({
    required this.isUpdating,
    required this.updatingListenable,
    required this.onTap,
    this.compact = false,
  });

  final bool isUpdating;
  final ValueListenable<bool>? updatingListenable;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final listenable = updatingListenable;
    if (listenable == null) {
      return _buildButton(context, isUpdating);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, updating, _) => _buildButton(context, updating),
    );
  }

  Widget _buildButton(BuildContext context, bool updating) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: updating ? null : onTap,
      child: SizedBox(
        width: compact ? 24 : 28,
        height: compact ? 20 : 24,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SvgPicture.asset(
            editPencilLineIconAsset,
            width: compact ? 15 : 18,
            height: compact ? 15 : 18,
            colorFilter: ColorFilter.mode(
              context.genesisColors.foregroundStrong,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
