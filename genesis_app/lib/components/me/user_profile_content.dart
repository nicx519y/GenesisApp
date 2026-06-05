import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/copyable_id_label.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../routers/app_router.dart';
import '../../ui/genesis_ui.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/stat_count_formatter.dart';
import 'profile_collection_list.dart';

const String _connectIconAsset = 'assets/custom-icons/png/connect.png';

class UserProfileContent extends StatefulWidget {
  const UserProfileContent({
    super.key,
    required this.data,
    this.originsListenable,
    this.worldsListenable,
    this.originsLoading = false,
    this.worldsLoading = false,
    this.isUpdatingProfile = false,
    this.avatarUrlListenable,
    this.displayNameListenable,
    this.isUpdatingProfileListenable,
    this.onEditAvatar,
    this.onEditDisplayName,
    this.nameUidGap = 4,
    this.tabLabelFontSize = 16,
  });

  final UserProfileData data;
  final ValueListenable<UserProfileCollectionState<UserProfileOriginItem>>?
  originsListenable;
  final ValueListenable<UserProfileCollectionState<UserProfileWorldItem>>?
  worldsListenable;
  final bool originsLoading;
  final bool worldsLoading;
  final bool isUpdatingProfile;
  final ValueListenable<String>? avatarUrlListenable;
  final ValueListenable<String>? displayNameListenable;
  final ValueListenable<bool>? isUpdatingProfileListenable;
  final VoidCallback? onEditAvatar;
  final VoidCallback? onEditDisplayName;
  final double nameUidGap;
  final double? tabLabelFontSize;

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
                name: data.displayName,
                urlListenable: widget.avatarUrlListenable,
                nameListenable: widget.displayNameListenable,
                isUpdating: widget.isUpdatingProfile,
                updatingListenable: widget.isUpdatingProfileListenable,
                onEdit: widget.onEditAvatar,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: _DisplayNameText(
                            displayName: data.displayName,
                            displayNameListenable: widget.displayNameListenable,
                          ),
                        ),
                        if (widget.onEditDisplayName != null) ...[
                          const SizedBox(width: 4),
                          _ProfileEditButton(
                            isUpdating: widget.isUpdatingProfile,
                            updatingListenable:
                                widget.isUpdatingProfileListenable,
                            onTap: widget.onEditDisplayName!,
                          ),
                        ],
                      ],
                    ),
                    if (widget.nameUidGap > 0)
                      SizedBox(height: widget.nameUidGap),
                    CopyableIdLabel(
                      label: 'UID',
                      value: formatUidForDisplay(data.uid),
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
            labelFontSize: widget.tabLabelFontSize,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBarView(
              controller: _tabController,
              children: [
                _OriginProfileCollectionList(
                  items: data.origins,
                  isLoading: widget.originsLoading,
                  listenable: widget.originsListenable,
                ),
                _WorldProfileCollectionList(
                  items: data.worlds,
                  isLoading: widget.worldsLoading,
                  listenable: widget.worldsListenable,
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
      showGenesisToast(context, 'Follow update failed');
    }
  }

  void _openMessages() {
    Navigator.of(context).pushNamed(
      RouteNames.chat,
      arguments: {
        'peer_uid': widget.data.uid,
        'peer_name': _currentDisplayName,
        'peer_avatar': widget.data.avatarUrl,
      },
    );
  }

  void _openFollows(int initialIndex) {
    Navigator.of(context).pushNamed(
      RouteNames.follows,
      arguments: {
        'uid': widget.data.uid,
        'title': _currentDisplayName,
        'initialIndex': initialIndex,
      },
    );
  }

  String get _currentDisplayName {
    final listenableName = widget.displayNameListenable?.value.trim() ?? '';
    if (listenableName.isNotEmpty) return listenableName;
    return widget.data.displayName;
  }

  int _decrementCount(int value) {
    return value > 0 ? value - 1 : 0;
  }
}

class UserProfileCollectionState<T> {
  const UserProfileCollectionState({
    required this.items,
    required this.isLoading,
  });

  final List<T> items;
  final bool isLoading;
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
    String? uid,
    int? followingCount,
    int? followerCount,
    bool? isSelf,
    bool? isFollowed,
    List<UserProfileOriginItem>? origins,
    List<UserProfileWorldItem>? worlds,
  }) {
    return UserProfileData(
      avatarUrl: avatarUrl ?? this.avatarUrl,
      displayName: displayName ?? this.displayName,
      uid: uid ?? this.uid,
      followingCount: followingCount ?? this.followingCount,
      followerCount: followerCount ?? this.followerCount,
      isSelf: isSelf ?? this.isSelf,
      isFollowed: isFollowed ?? this.isFollowed,
      origins: origins ?? this.origins,
      worlds: worlds ?? this.worlds,
    );
  }
}

class _OriginProfileCollectionList extends StatelessWidget {
  const _OriginProfileCollectionList({
    required this.items,
    required this.isLoading,
    required this.listenable,
  });

  final List<UserProfileOriginItem> items;
  final bool isLoading;
  final ValueListenable<UserProfileCollectionState<UserProfileOriginItem>>?
  listenable;

  @override
  Widget build(BuildContext context) {
    final listenable = this.listenable;
    if (listenable == null) {
      return _buildOriginList(context, items, isLoading);
    }
    return ValueListenableBuilder<
      UserProfileCollectionState<UserProfileOriginItem>
    >(
      valueListenable: listenable,
      builder: (context, state, _) {
        return _buildOriginList(context, state.items, state.isLoading);
      },
    );
  }

  Widget _buildOriginList(
    BuildContext context,
    List<UserProfileOriginItem> items,
    bool isLoading,
  ) {
    return ProfileCollectionList(
      items: items
          .map(
            (item) => GenesisProfileCollectionItemData(
              imageUrl: item.imageUrl,
              title: originDisplayName(item.title),
              subtitle: item.subtitle,
              stats: [
                GenesisProfileCollectionStat(
                  icon: MyFlutterApp.save,
                  value: item.copyCount,
                ),
                GenesisProfileCollectionStat(
                  iconAsset: _connectIconAsset,
                  value: item.interactCount,
                ),
                GenesisProfileCollectionStat(
                  iconAsset: aiCharacterIconAsset,
                  preserveIconAssetColor: true,
                  value: item.characterCount,
                ),
              ],
              onTap: () => Navigator.of(context).pushNamed(
                RouteNames.originWorld,
                arguments: {'originId': item.originId, 'oid': item.oid},
              ),
            ),
          )
          .toList(growable: false),
      emptyText: 'No Origins you created yet.',
      isLoading: isLoading,
      loadingKey: const ValueKey('profile-origin-list-loading'),
    );
  }
}

class _WorldProfileCollectionList extends StatelessWidget {
  const _WorldProfileCollectionList({
    required this.items,
    required this.isLoading,
    required this.listenable,
  });

  final List<UserProfileWorldItem> items;
  final bool isLoading;
  final ValueListenable<UserProfileCollectionState<UserProfileWorldItem>>?
  listenable;

  @override
  Widget build(BuildContext context) {
    final listenable = this.listenable;
    if (listenable == null) {
      return _buildWorldList(context, items, isLoading);
    }
    return ValueListenableBuilder<
      UserProfileCollectionState<UserProfileWorldItem>
    >(
      valueListenable: listenable,
      builder: (context, state, _) {
        return _buildWorldList(context, state.items, state.isLoading);
      },
    );
  }

  Widget _buildWorldList(
    BuildContext context,
    List<UserProfileWorldItem> items,
    bool isLoading,
  ) {
    return ProfileCollectionList(
      items: items
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
                  iconAsset: _connectIconAsset,
                  value: item.interactCount,
                ),
                GenesisProfileCollectionStat(
                  iconAsset: aiCharacterIconAsset,
                  preserveIconAssetColor: true,
                  value: item.characterCount,
                ),
                GenesisProfileCollectionStat(
                  icon: MyFlutterApp.user,
                  value: item.playerCount,
                ),
              ],
              onTap: () => Navigator.of(
                context,
              ).pushNamed(RouteNames.world, arguments: {'wid': item.wid}),
            ),
          )
          .toList(growable: false),
      emptyText: 'No Worlds you created yet.',
      isLoading: isLoading,
      loadingKey: const ValueKey('profile-world-list-loading'),
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
      fontSize: 16,
      height: 1,
      color: Color(0xFF111111),
      fontWeight: FontWeight.w600,
    );
    const labelStyle = TextStyle(
      fontSize: 14,
      height: 1,
      color: Color(0xFF666666),
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
        : const Color(0xFFF42C47);
    final foregroundColor = isFollowed ? Colors.black : Colors.white;
    final disabledBackgroundColor = isFollowed
        ? const Color(0xFFE5E5E5)
        : const Color(0xFFF42C47).withValues(alpha: 0.55);
    final disabledForegroundColor = isFollowed ? Colors.black54 : Colors.white;
    const actionTextStyle = TextStyle(fontWeight: FontWeight.w400);

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
                  : Text(
                      isFollowed ? 'Unfollow' : 'Follow',
                      style: actionTextStyle,
                    ),
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
  });

  static const double _size = 80;
  static const double _radius = 8;

  final String url;
  final String name;
  final ValueListenable<String>? urlListenable;
  final ValueListenable<String>? nameListenable;
  final bool isUpdating;
  final ValueListenable<bool>? updatingListenable;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final listenableName = nameListenable;
    if (listenableName != null) {
      return ValueListenableBuilder<String>(
        valueListenable: listenableName,
        builder: (context, displayName, _) =>
            _buildUrlLayer(displayName.trim().isEmpty ? name : displayName),
      );
    }
    return _buildUrlLayer(name);
  }

  Widget _buildUrlLayer(String displayName) {
    final avatarListenable = urlListenable;
    if (avatarListenable == null) {
      return _buildAvatar(url, displayName, isUpdating);
    }
    return ValueListenableBuilder<String>(
      valueListenable: avatarListenable,
      builder: (context, avatarUrl, _) {
        final loadingListenable = updatingListenable;
        if (loadingListenable == null) {
          return _buildAvatar(avatarUrl, displayName, isUpdating);
        }
        return ValueListenableBuilder<bool>(
          valueListenable: loadingListenable,
          builder: (context, updating, _) =>
              _buildAvatar(avatarUrl, displayName, updating),
        );
      },
    );
  }

  Widget _buildAvatar(String avatarUrl, String displayName, bool updating) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GenesisAvatar(
            url: avatarUrl,
            name: displayName,
            size: _size,
            borderRadius: _radius,
            imageKey: const ValueKey('user-profile-avatar-image'),
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
                  onTap: updating ? null : onEdit,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      MyFlutterApp.editImage,
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

class _DisplayNameText extends StatelessWidget {
  const _DisplayNameText({
    required this.displayName,
    required this.displayNameListenable,
  });

  final String displayName;
  final ValueListenable<String>? displayNameListenable;

  @override
  Widget build(BuildContext context) {
    final listenable = displayNameListenable;
    if (listenable == null) {
      return _buildName(displayName);
    }
    return ValueListenableBuilder<String>(
      valueListenable: listenable,
      builder: (context, name, _) {
        final resolvedName = name.trim().isEmpty ? displayName : name;
        return _buildName(resolvedName);
      },
    );
  }

  Widget _buildName(String name) {
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 18,
        height: 1,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }
}

class _ProfileEditButton extends StatelessWidget {
  const _ProfileEditButton({
    required this.isUpdating,
    required this.updatingListenable,
    required this.onTap,
  });

  final bool isUpdating;
  final ValueListenable<bool>? updatingListenable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listenable = updatingListenable;
    if (listenable == null) {
      return _buildButton(isUpdating);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, updating, _) => _buildButton(updating),
    );
  }

  Widget _buildButton(bool updating) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: updating ? null : onTap,
      child: const Padding(
        padding: EdgeInsets.all(5),
        child: Icon(Icons.edit, size: 14),
      ),
    );
  }
}
