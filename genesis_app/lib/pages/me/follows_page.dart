import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/page_header.dart';
import '../../components/secend_tabs.dart';
import '../../network/genesis_api.dart';
import '../../routers/app_router.dart';
import '../../utils/stat_count_formatter.dart';

class FollowsPage extends StatefulWidget {
  const FollowsPage({
    super.key,
    required this.uid,
    this.initialIndex = 0,
    this.initialTitle,
  });

  final String uid;
  final int initialIndex;
  final String? initialTitle;

  @override
  State<FollowsPage> createState() => _FollowsPageState();
}

class _FollowsPageState extends State<FollowsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<_FollowUserItem>> _followingFuture;
  late Future<List<_FollowUserItem>> _followersFuture;
  final Set<String> _loadingUids = <String>{};
  final Map<String, bool> _followStateOverrides = <String, bool>{};
  String _title = 'Follows';
  int? _followingTotal;
  int? _followersTotal;

  @override
  void initState() {
    super.initState();
    _title = _cleanTitle(widget.initialTitle) ?? _title;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 1),
    );
    unawaited(_loadCachedTotals());
    _followingFuture = _loadUsers(_FollowListType.following);
    _followersFuture = _loadUsers(_FollowListType.followers);
    if (_cleanTitle(widget.initialTitle) == null) {
      _loadTitle();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedTotals() async {
    final uid = widget.uid.trim();
    if (uid.isEmpty) return;
    final sessionStore = AppServicesScope.read(context).sessionStore;
    final cachedUser = await sessionStore.readUserInfo();
    if (cachedUser == null || cachedUser.isEmpty) return;

    final localUid = (await sessionStore.readUid())?.trim() ?? '';
    final cachedUid = _mapString(cachedUser, 'uid') ?? '';
    final matchesCurrentUser =
        (localUid.isNotEmpty && localUid == uid) ||
        (cachedUid.isNotEmpty && cachedUid == uid);
    if (!matchesCurrentUser || !mounted) return;

    setState(() {
      _followingTotal =
          _mapIntOrNull(cachedUser, 'following_cnt') ?? _followingTotal;
      _followersTotal =
          _mapIntOrNull(cachedUser, 'follower_cnt') ?? _followersTotal;
    });
  }

  Future<void> _loadTitle() async {
    final uid = widget.uid.trim();
    if (uid.isEmpty) return;
    try {
      final info = await AppServicesScope.read(
        context,
      ).api.v1.user.info(uid: uid);
      final user = _asMap(info['user']);
      final title =
          _mapString(user, 'name') ??
          _mapString(user, 'display_name') ??
          _mapString(user, 'nickname');
      if (!mounted || title == null) return;
      setState(() => _title = title);
    } catch (_) {}
  }

  Future<List<_FollowUserItem>> _loadUsers(_FollowListType type) async {
    final uid = widget.uid.trim();
    if (uid.isEmpty) return const <_FollowUserItem>[];

    final followApi = AppServicesScope.read(context).api.v1.follow;
    final response = type == _FollowListType.following
        ? await followApi.following(uid: uid, pn: 1, rn: 50)
        : await followApi.followers(uid: uid, pn: 1, rn: 50);
    final rawList = _asList(response['list']);
    final items = rawList
        .map((entry) => _FollowUserItem.fromJson(entry, type: type))
        .where((item) => item.uid.trim().isNotEmpty)
        .toList(growable: false);
    final total = _mapInt(response, 'total', fallback: items.length);
    if (mounted) {
      setState(() {
        if (type == _FollowListType.following) {
          _followingTotal = total;
        } else {
          _followersTotal = total;
        }
      });
    }
    return items;
  }

  Future<void> _toggleFollow(_FollowUserItem item, bool isFollowed) async {
    final uid = item.uid.trim();
    if (uid.isEmpty || _loadingUids.contains(uid)) return;

    setState(() => _loadingUids.add(uid));
    try {
      final api = AppServicesScope.read(context).api.v1.follow;
      if (isFollowed) {
        await api.unfollow(uid: uid);
      } else {
        await api.follow(uid: uid);
      }
      if (!mounted) return;
      setState(() {
        final nextFollowed = !isFollowed;
        _followStateOverrides[uid] = nextFollowed;
        _loadingUids.remove(uid);
        final followingTotal = _followingTotal;
        if (followingTotal != null) {
          _followingTotal = nextFollowed
              ? followingTotal + 1
              : _decrementCount(followingTotal);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUids.remove(uid));
      showGenesisToast(context, 'Follow update failed');
    }
  }

  Future<void> _refresh(_FollowListType type) async {
    setState(() {
      if (type == _FollowListType.following) {
        _followingFuture = _loadUsers(type);
      } else {
        _followersFuture = _loadUsers(type);
      }
    });
    await (type == _FollowListType.following
        ? _followingFuture
        : _followersFuture);
  }

  @override
  Widget build(BuildContext context) {
    final followingCount = formatStatCount(_followingTotal ?? 0);
    final followersCount = formatStatCount(_followersTotal ?? 0);
    return Scaffold(
      appBar: GenesisBackAppBar(pageName: _title),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const SizedBox(height: 12),
            SecendTabs(
              controller: _tabController,
              labels: [
                '$followingCount Following',
                '$followersCount Followers',
              ],
              // horizontalPadding: 28,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _FollowUsersPane(
                    future: _followingFuture,
                    emptyText: 'No following yet.',
                    defaultFollowed: true,
                    loadingUids: _loadingUids,
                    followStateOverrides: _followStateOverrides,
                    onRefresh: () => _refresh(_FollowListType.following),
                    onToggleFollow: _toggleFollow,
                  ),
                  _FollowUsersPane(
                    future: _followersFuture,
                    emptyText: 'No followers yet.',
                    defaultFollowed: false,
                    loadingUids: _loadingUids,
                    followStateOverrides: _followStateOverrides,
                    onRefresh: () => _refresh(_FollowListType.followers),
                    onToggleFollow: _toggleFollow,
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

class _FollowUsersPane extends StatelessWidget {
  const _FollowUsersPane({
    required this.future,
    required this.emptyText,
    required this.defaultFollowed,
    required this.loadingUids,
    required this.followStateOverrides,
    required this.onRefresh,
    required this.onToggleFollow,
  });

  static const double _itemExtent = 66;

  final Future<List<_FollowUserItem>> future;
  final String emptyText;
  final bool defaultFollowed;
  final Set<String> loadingUids;
  final Map<String, bool> followStateOverrides;
  final Future<void> Function() onRefresh;
  final Future<void> Function(_FollowUserItem item, bool isFollowed)
  onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_FollowUserItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Load failed'),
                const SizedBox(height: 8),
                FilledButton(onPressed: onRefresh, child: const Text('Retry')),
              ],
            ),
          );
        }
        final items = snapshot.data ?? const <_FollowUserItem>[];
        if (items.isEmpty) {
          return Center(
            child: Text(
              emptyText,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A8A8A),
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            cacheExtent: 0,
            itemExtent: _itemExtent,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isFollowed =
                  followStateOverrides[item.uid] ??
                  (defaultFollowed || item.isFollowed);
              return _FollowUserTile(
                item: item,
                isFollowed: isFollowed,
                isLoading: loadingUids.contains(item.uid),
                onToggleFollow: () => onToggleFollow(item, isFollowed),
              );
            },
          ),
        );
      },
    );
  }
}

class _FollowUserTile extends StatelessWidget {
  const _FollowUserTile({
    required this.item,
    required this.isFollowed,
    required this.isLoading,
    required this.onToggleFollow,
  });

  static const double _actionWidth = 86;
  static const double _actionHeight = 28;

  final _FollowUserItem item;
  final bool isFollowed;
  final bool isLoading;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(
        context,
      ).pushNamed(RouteNames.userInfo, arguments: {'uid': item.uid}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _FollowAvatar(url: item.avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: _actionWidth,
              height: _actionHeight,
              child: FilledButton(
                key: ValueKey('follows-action-${item.uid}'),
                onPressed: isLoading ? null : onToggleFollow,
                style: FilledButton.styleFrom(
                  fixedSize: const Size(_actionWidth, _actionHeight),
                  minimumSize: const Size(_actionWidth, _actionHeight),
                  backgroundColor: isFollowed
                      ? const Color(0xFFE5E5E5)
                      : const Color(0xFFE85050),
                  disabledBackgroundColor: isFollowed
                      ? const Color(0xFFE5E5E5)
                      : const Color(0xFFE85050).withValues(alpha: 0.55),
                  foregroundColor: isFollowed ? Colors.black : Colors.white,
                  disabledForegroundColor: isFollowed
                      ? Colors.black54
                      : Colors.white,
                  alignment: Alignment.center,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
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
                        isFollowed ? 'Unfollow' : 'Follow',
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowAvatar extends StatelessWidget {
  const _FollowAvatar({required this.url});

  static const double _size = 44;

  final String url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDED),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(Icons.person, color: Color(0xFF9A9A9A), size: 24),
    );
    if (url.trim().isEmpty) return placeholder;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

enum _FollowListType { following, followers }

class _FollowUserItem {
  const _FollowUserItem({
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.isFollowed,
  });

  final String uid;
  final String displayName;
  final String avatarUrl;
  final bool isFollowed;

  factory _FollowUserItem.fromJson(
    Map<String, dynamic> json, {
    required _FollowListType type,
  }) {
    final user = _asMap(json['user']).isEmpty ? json : _asMap(json['user']);
    final relation = _asMap(json['relation']);
    final uid =
        _mapString(user, 'uid') ??
        _mapString(user, 'target_user_id') ??
        _mapString(relation, 'target_user_id') ??
        '';
    final displayName =
        _mapString(user, 'name') ??
        _mapString(user, 'display_name') ??
        _mapString(user, 'nickname') ??
        uid;
    final avatar =
        _mapString(user, 'avatar') ?? _mapString(user, 'avatar_url') ?? '';
    final isFollowed =
        type == _FollowListType.following ||
        _mapBool(relation, 'i_followed') ||
        _mapBool(relation, 'is_followed') ||
        _mapBool(user, 'i_followed') ||
        _mapBool(user, 'is_followed');
    return _FollowUserItem(
      uid: uid,
      displayName: displayName.trim().isEmpty ? 'User' : displayName,
      avatarUrl: resolveAssetUrl(avatar),
      isFollowed: isFollowed,
    );
  }
}

String? _cleanTitle(String? title) {
  final value = title?.trim() ?? '';
  return value.isEmpty ? null : value;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.map(_asMap).toList(growable: false);
}

String? _mapString(Map<dynamic, dynamic> map, String key) {
  final value = map[key]?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

int _mapInt(Map<dynamic, dynamic> map, String key, {required int fallback}) {
  return _mapIntOrNull(map, key) ?? fallback;
}

int? _mapIntOrNull(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _mapBool(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

int _decrementCount(int value) {
  return value > 0 ? value - 1 : 0;
}
