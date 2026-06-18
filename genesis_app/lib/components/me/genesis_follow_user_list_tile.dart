import 'package:flutter/material.dart';

import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';

class GenesisFollowUserListTile extends StatelessWidget {
  const GenesisFollowUserListTile({
    super.key,
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    this.deleted = false,
    required this.isFollowed,
    required this.isLoading,
    required this.onToggleFollow,
    this.onTap,
    this.keyPrefix = 'follows',
  });

  static const double itemExtent = 66;
  static const double _avatarSize = 48;
  static const double _actionWidth = 86;
  static const double _actionHeight = 28;

  final String uid;
  final String displayName;
  final String avatarUrl;
  final bool deleted;
  final bool isFollowed;
  final bool isLoading;
  final VoidCallback onToggleFollow;
  final VoidCallback? onTap;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final cleanUid = uid.trim();
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: deleted
          ? null
          : onTap ??
                () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.userInfo, arguments: {'uid': cleanUid}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              key: ValueKey('$keyPrefix-avatar-$cleanUid'),
              width: _avatarSize,
              height: _avatarSize,
              child: GenesisAvatar(
                url: avatarUrl,
                name: displayName,
                size: _avatarSize,
                borderRadius: GenesisAvatarRadii.user,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(
                    key: ValueKey('$keyPrefix-name-uid-gap-$cleanUid'),
                    height: 4,
                  ),
                  Text(
                    'UID: ${deletedAwareIdLabel(formatUidForDisplay(cleanUid), deleted: deleted)}',
                    style: _uidTextStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _actionWidth,
              height: _avatarSize,
              child: Center(
                child: SizedBox(
                  width: _actionWidth,
                  height: _actionHeight,
                  child: FilledButton(
                    key: ValueKey('$keyPrefix-action-$cleanUid'),
                    onPressed: deleted || isLoading ? null : onToggleFollow,
                    style: FilledButton.styleFrom(
                      fixedSize: const Size(_actionWidth, _actionHeight),
                      minimumSize: const Size(_actionWidth, _actionHeight),
                      backgroundColor: isFollowed
                          ? const Color(0xFFE5E5E5)
                          : const Color(0xFFF42C47),
                      disabledBackgroundColor: isFollowed
                          ? const Color(0xFFE5E5E5)
                          : const Color(0xFFF42C47).withValues(alpha: 0.55),
                      foregroundColor: isFollowed ? Colors.black : Colors.white,
                      disabledForegroundColor: isFollowed
                          ? Colors.black54
                          : Colors.white,
                      alignment: Alignment.center,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isFollowed ? Colors.black54 : Colors.white,
                            ),
                          )
                        : Text(
                            isFollowed ? 'Following' : 'Follow',
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _uidTextStyle = TextStyle(
  fontSize: 12,
  height: 1.1,
  fontWeight: FontWeight.w400,
  color: Color(0xFF8A8A8A),
);
