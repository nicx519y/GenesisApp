import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../routers/app_router.dart';
import '../../ui/genesis_ui.dart';
import '../../utils/stat_count_formatter.dart';
import 'profile_collection_list.dart';

class UserProfileContent extends StatefulWidget {
  const UserProfileContent({
    super.key,
    required this.data,
    this.isUpdatingProfile = false,
    this.onEditAvatar,
    this.onEditDisplayName,
    this.onCopyUid,
  });

  final UserProfileData data;
  final bool isUpdatingProfile;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onEditDisplayName;
  final ValueChanged<String>? onCopyUid;

  @override
  State<UserProfileContent> createState() => _UserProfileContentState();
}

class _UserProfileContentState extends State<UserProfileContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool? _isFollowedOverride;
  int? _followerCountOverride;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didUpdateWidget(covariant UserProfileContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.uid != widget.data.uid) {
      _isFollowedOverride = null;
      _followerCountOverride = null;
      _followLoading = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isFollowed = _isFollowedOverride ?? data.isFollowed;
    final followerCount = _followerCountOverride ?? data.followerCount;
    return Column(
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                url: data.avatarUrl,
                onEdit: widget.isUpdatingProfile ? null : widget.onEditAvatar,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          data.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        if (widget.onEditDisplayName != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.isUpdatingProfile
                                ? null
                                : widget.onEditDisplayName,
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(Icons.edit, size: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'UID: ${data.uid}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6F6F6F),
                          ),
                        ),
                        if (widget.onCopyUid != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onCopyUid!(data.uid),
                            child: const Padding(
                              padding: EdgeInsets.all(5),
                              child: Icon(Icons.copy, size: 14),
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
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _FollowStats(
            followingCount: data.followingCount,
            followerCount: followerCount,
            onFollowingTap: () => _openFollows(0),
            onFollowersTap: () => _openFollows(1),
          ),
        ),
        if (!data.isSelf) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ProfileActionButtons(
              isFollowed: isFollowed,
              followLoading: _followLoading,
              onFollowToggle: () => _toggleFollow(isFollowed),
              onMessage: _openMessages,
            ),
          ),
        ],
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerLeft,
          child: SecendTabs(
            controller: _tabController,
            labels: const ['Origin', 'World'],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBarView(
              controller: _tabController,
              children: [
                ProfileCollectionList(
                  items: data.origins
                      .map(
                        (item) => GenesisProfileCollectionItemData(
                          imageUrl: item.imageUrl,
                          title: item.title,
                          subtitle: item.subtitle,
                          stats: [
                            GenesisProfileCollectionStat(
                              icon: MyFlutterApp.save,
                              value: item.copyCount,
                            ),
                            GenesisProfileCollectionStat(
                              icon: MyFlutterApp.copy,
                              value: item.interactCount,
                            ),
                            GenesisProfileCollectionStat(
                              icon: MyFlutterApp.userStar,
                              value: item.characterCount,
                            ),
                          ],
                          onTap: () => Navigator.of(context).pushNamed(
                            RouteNames.originWorld,
                            arguments: {
                              'originId': item.originId,
                              'oid': item.oid,
                            },
                          ),
                        ),
                      )
                      .toList(growable: false),
                  emptyText: 'No Origins you created yet.',
                ),
                ProfileCollectionList(
                  items: data.worlds
                      .map(
                        (item) => GenesisProfileCollectionItemData(
                          imageUrl: item.imageUrl,
                          title: item.title,
                          subtitle: item.subtitle,
                          stats: [
                            GenesisProfileCollectionStat(
                              icon: MyFlutterApp.pregress,
                              value: item.progressCount,
                            ),
                            GenesisProfileCollectionStat(
                              icon: MyFlutterApp.copy,
                              value: item.interactCount,
                            ),
                            GenesisProfileCollectionStat(
                              icon: MyFlutterApp.userStar,
                              value: item.characterCount,
                            ),
                            GenesisProfileCollectionStat(
                              icon: MyFlutterApp.user,
                              value: item.playerCount,
                            ),
                          ],
                          onTap: () => Navigator.of(context).pushNamed(
                            RouteNames.world,
                            arguments: {'wid': item.wid},
                          ),
                        ),
                      )
                      .toList(growable: false),
                  emptyText: 'No Worlds you created yet.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFollow(bool isFollowed) async {
    if (_followLoading) return;
    final uid = widget.data.uid.trim();
    if (uid.isEmpty) return;

    setState(() => _followLoading = true);
    try {
      if (isFollowed) {
        await AppServicesScope.read(context).api.v1.follow.unfollow(uid: uid);
      } else {
        await AppServicesScope.read(context).api.v1.follow.follow(uid: uid);
      }
      if (!mounted) return;
      final nextFollowed = !isFollowed;
      final currentFollowerCount =
          _followerCountOverride ?? widget.data.followerCount;
      setState(() {
        _isFollowedOverride = nextFollowed;
        _followerCountOverride = nextFollowed
            ? currentFollowerCount + 1
            : _decrementCount(currentFollowerCount);
        _followLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _followLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Follow update failed')));
    }
  }

  void _openMessages() {
    Navigator.of(context).pushNamed(RouteNames.messages);
  }

  void _openFollows(int initialIndex) {
    Navigator.of(context).pushNamed(
      RouteNames.follows,
      arguments: {
        'uid': widget.data.uid,
        'title': widget.data.displayName,
        'initialIndex': initialIndex,
      },
    );
  }

  int _decrementCount(int value) {
    return value > 0 ? value - 1 : 0;
  }
}

class UserProfileData {
  const UserProfileData({
    required this.avatarUrl,
    required this.displayName,
    required this.uid,
    required this.followingCount,
    required this.followerCount,
    this.isSelf = true,
    this.isFollowed = false,
    required this.origins,
    required this.worlds,
  });

  final String avatarUrl;
  final String displayName;
  final String uid;
  final int followingCount;
  final int followerCount;
  final bool isSelf;
  final bool isFollowed;
  final List<UserProfileOriginItem> origins;
  final List<UserProfileWorldItem> worlds;

  UserProfileData copyWith({
    String? avatarUrl,
    String? displayName,
    int? followingCount,
    int? followerCount,
    bool? isSelf,
    bool? isFollowed,
  }) {
    return UserProfileData(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      uid: uid,
      followingCount: followingCount ?? this.followingCount,
      followerCount: followerCount ?? this.followerCount,
      isSelf: isSelf ?? this.isSelf,
      isFollowed: isFollowed ?? this.isFollowed,
      origins: origins,
      worlds: worlds,
    );
  }
}

class UserProfileOriginItem {
  const UserProfileOriginItem({
    required this.originId,
    required this.oid,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.copyCount,
    required this.interactCount,
    required this.characterCount,
  });

  final int originId;
  final String oid;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int copyCount;
  final int interactCount;
  final int characterCount;
}

class UserProfileWorldItem {
  const UserProfileWorldItem({
    required this.wid,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.progressCount,
    required this.interactCount,
    required this.characterCount,
    required this.playerCount,
    required this.ownerName,
  });

  final String wid;
  final String title;
  final String subtitle;
  final String imageUrl;
  final int progressCount;
  final int interactCount;
  final int characterCount;
  final int playerCount;
  final String ownerName;
}

class _FollowStats extends StatelessWidget {
  const _FollowStats({
    required this.followingCount,
    required this.followerCount,
    required this.onFollowingTap,
    required this.onFollowersTap,
  });

  final int followingCount;
  final int followerCount;
  final VoidCallback onFollowingTap;
  final VoidCallback onFollowersTap;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 13,
      height: 1,
      color: Colors.black,
      fontWeight: FontWeight.w600,
    );
    const labelStyle = TextStyle(
      fontSize: 13,
      height: 1,
      color: Color(0xFF6F6F6F),
      fontWeight: FontWeight.w400,
    );

    return Row(
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
    final backgroundColor = isFollowed
        ? const Color(0xFFE5E5E5)
        : const Color(0xFFE85050);
    final foregroundColor = isFollowed ? Colors.black : Colors.white;
    final disabledBackgroundColor = isFollowed
        ? const Color(0xFFE5E5E5)
        : const Color(0xFFE85050).withValues(alpha: 0.55);
    final disabledForegroundColor = isFollowed ? Colors.black54 : Colors.white;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
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
                  : Text(isFollowed ? 'Unfollow' : 'Follow'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 38,
            child: FilledButton(
              key: const ValueKey('user-profile-message-button'),
              onPressed: onMessage,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE5E5E5),
                disabledBackgroundColor: const Color(0xFFE5E5E5),
                foregroundColor: Colors.black,
                disabledForegroundColor: Colors.black54,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Message'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.onEdit});

  static const double _size = 80;
  static const double _radius = 8;

  final String url;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: _AvatarImage(url: url, size: _size),
          ),
          if (onEdit != null)
            Positioned(
              right: 2,
              bottom: 2,
              child: Material(
                color: Colors.black.withValues(alpha: 0.4),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onEdit,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.edit_document,
                      size: 12,
                      color: Colors.white,
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

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFE6E6E6),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: size * 0.45,
        color: const Color(0xFF9C9C9C),
      ),
    );
  }
}
