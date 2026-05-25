import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
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
                        Expanded(
                          child: Text(
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
                        Expanded(
                          child: Text(
                            'UID: ${data.uid}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6F6F6F),
                            ),
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
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _FollowStats(
            followingCount: data.followingCount,
            followerCount: data.followerCount,
          ),
        ),
        const SizedBox(height: 16),
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
}

class UserProfileData {
  const UserProfileData({
    required this.avatarUrl,
    required this.displayName,
    required this.uid,
    required this.followingCount,
    required this.followerCount,
    required this.origins,
    required this.worlds,
  });

  final String avatarUrl;
  final String displayName;
  final String uid;
  final int followingCount;
  final int followerCount;
  final List<UserProfileOriginItem> origins;
  final List<UserProfileWorldItem> worlds;

  UserProfileData copyWith({
    String? avatarUrl,
    String? displayName,
    int? followingCount,
    int? followerCount,
  }) {
    return UserProfileData(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      uid: uid,
      followingCount: followingCount ?? this.followingCount,
      followerCount: followerCount ?? this.followerCount,
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
  });

  final int followingCount;
  final int followerCount;

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
        Text(formatStatCount(followingCount), style: style),
        const SizedBox(width: 4),
        const Text('Following', style: labelStyle),
        const SizedBox(width: 16),
        Text(formatStatCount(followerCount), style: style),
        const SizedBox(width: 4),
        const Text('Followers', style: labelStyle),
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
