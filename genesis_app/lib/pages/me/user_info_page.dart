import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/blocked_user_review_return.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../components/auth/login_guard.dart';
import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/me/user_profile_content.dart';
import '../../network/api_exception.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/origin.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_page_header.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_skeleton.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key, required this.uid});

  final String uid;

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {
  late Future<UserProfileData> _future;
  int _loadGeneration = 0;
  String _profileUid = '';
  String _profileTitle = '';
  bool _profileIsSelf = true;
  bool _profileBlocked = false;
  bool _isBlockingUser = false;
  bool _profileCollapsed = false;
  final ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>>
  _originsState =
      ValueNotifier<UserProfileCollectionState<UserProfileOriginItem>>(
        const UserProfileCollectionState<UserProfileOriginItem>(
          items: <UserProfileOriginItem>[],
          isLoading: false,
        ),
      );
  final ValueNotifier<UserProfileCollectionState<UserProfileWorldItem>>
  _worldsState =
      ValueNotifier<UserProfileCollectionState<UserProfileWorldItem>>(
        const UserProfileCollectionState<UserProfileWorldItem>(
          items: <UserProfileWorldItem>[],
          isLoading: false,
        ),
      );

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void dispose() {
    _originsState.dispose();
    _worldsState.dispose();
    super.dispose();
  }

  Future<UserProfileData> _loadData() async {
    final generation = _loadGeneration + 1;
    _loadGeneration = generation;
    final services = AppServicesScope.read(context);
    final api = services.api;
    final uid = widget.uid.trim();
    final localUid = (await services.sessionStore.readUid())?.trim() ?? '';
    final userInfo = await api.v1.user.info(uid: uid);
    final user = userInfo['user'] is Map
        ? userInfo['user'] as Map
        : const <String, dynamic>{};
    final relation = userInfo['relation'] is Map
        ? userInfo['relation'] as Map
        : const <String, dynamic>{};
    final resolvedUid = _mapString(user, 'uid', fallback: uid);
    final displayName = _mapString(user, 'name', fallback: 'User');
    final avatarUrl = asResolvedImageUrl(
      user['avatar'],
      resolveAssetUrl,
      fallback: user['avatar_url'],
    );
    final profileUid = resolvedUid.trim().isNotEmpty ? resolvedUid : uid;
    final isSelf =
        _mapBool(relation, 'is_self') ||
        (localUid.isNotEmpty && localUid == profileUid);
    final isBlocked = !isSelf && _mapBool(relation, 'is_blocked');
    if (mounted &&
        (_profileUid != profileUid ||
            _profileTitle != displayName ||
            _profileIsSelf != isSelf ||
            _profileBlocked != isBlocked)) {
      setState(() {
        _profileUid = profileUid;
        _profileTitle = displayName;
        _profileIsSelf = isSelf;
        _profileBlocked = isBlocked;
      });
    }

    final data = UserProfileData(
      avatarUrl: avatarUrl,
      displayName: displayName,
      uid: profileUid.trim().isEmpty ? 'Unknown' : profileUid,
      followingCount: _mapInt(user, 'following_cnt'),
      followerCount: _mapInt(user, 'follower_cnt'),
      deleted: entityDeleted(user['deleted']),
      isSelf: isSelf,
      isFollowed:
          _mapBool(relation, 'is_followed') || _mapBool(relation, 'i_followed'),
      origins: const [],
      worlds: const [],
    );
    if (!mounted || generation != _loadGeneration) return data;

    if (profileUid.isEmpty || isBlocked) {
      _clearProfileCollections();
    } else {
      _markProfileCollectionsLoading();
      unawaited(_loadOrigins(generation, api, profileUid));
      unawaited(_loadWorlds(generation, api, profileUid));
    }
    if (isSelf) {
      unawaited(services.gemWallet.refresh());
    }
    return data;
  }

  Future<void> _loadOrigins(int generation, GenesisApi api, String uid) async {
    try {
      final items = await _loadOriginItems(api, uid);
      if (!mounted || generation != _loadGeneration) return;
      _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
        items: items,
        isLoading: false,
      );
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      _originsState.value =
          const UserProfileCollectionState<UserProfileOriginItem>(
            items: <UserProfileOriginItem>[],
            isLoading: false,
          );
    }
  }

  Future<void> _loadWorlds(int generation, GenesisApi api, String uid) async {
    try {
      final items = await _loadWorldItems(api, uid);
      if (!mounted || generation != _loadGeneration) return;
      _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
        items: items,
        isLoading: false,
      );
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      _worldsState.value =
          const UserProfileCollectionState<UserProfileWorldItem>(
            items: <UserProfileWorldItem>[],
            isLoading: false,
          );
    }
  }

  Future<void> _refresh() async {
    final refresh = _loadData();
    setState(() {
      _future = refresh;
    });
    try {
      await refresh;
    } on ApiException {
      // FutureBuilder owns the visible error state. Do not let an expected
      // request failure escape an async callback used as a VoidCallback.
    }
  }

  Future<void> _refreshOrigins() async {
    final uid = _profileUid.trim().isEmpty ? widget.uid.trim() : _profileUid;
    if (uid.isEmpty) return;
    final current = _originsState.value;
    _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
      items: current.items,
      isLoading: true,
    );
    try {
      final api = AppServicesScope.read(context).api;
      final items = await _loadOriginItems(api, uid);
      if (!mounted) return;
      _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
        items: items,
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      _originsState.value = UserProfileCollectionState<UserProfileOriginItem>(
        items: current.items,
        isLoading: false,
      );
    }
  }

  Future<void> _refreshWorlds() async {
    final uid = _profileUid.trim().isEmpty ? widget.uid.trim() : _profileUid;
    if (uid.isEmpty) return;
    final current = _worldsState.value;
    _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
      items: current.items,
      isLoading: true,
    );
    try {
      final api = AppServicesScope.read(context).api;
      final items = await _loadWorldItems(api, uid);
      if (!mounted) return;
      _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
        items: items,
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      _worldsState.value = UserProfileCollectionState<UserProfileWorldItem>(
        items: current.items,
        isLoading: false,
      );
    }
  }

  void _handleProfileCollapsedChanged(bool collapsed) {
    if (_profileCollapsed == collapsed) return;
    setState(() => _profileCollapsed = collapsed);
  }

  void _handleBlockUser() {
    unawaited(_blockUser());
  }

  void _handleUnblockUser() {
    unawaited(_unblockUser());
  }

  Future<void> _blockUser() async {
    if (_isBlockingUser || _profileBlocked) return;
    final targetUid = _targetUid();
    if (targetUid.isEmpty) {
      showGenesisToast(context, 'Block failed');
      return;
    }
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    final confirmed = await _confirmBlockUser();
    if (!confirmed || !mounted) return;
    setState(() => _isBlockingUser = true);
    try {
      final api = AppServicesScope.read(context).api;
      await api.v1.user.block(targetUid: targetUid);
      await api.v1.report.create(
        targetType: 'user',
        targetId: targetUid,
        content: 'User blocked from profile.',
      );
      BlockedUserReviewReturn.markPendingHomePopularRefresh();
      if (!mounted) return;
      _clearProfileCollections();
      setState(() {
        _isBlockingUser = false;
        _profileBlocked = true;
      });
      showGenesisToast(
        context,
        'User blocked. This content has been reported to Worldo team.',
      );
    } catch (error, stackTrace) {
      debugPrint('[UserInfo][Block] failed: $error');
      debugPrint('[UserInfo][Block] stacktrace:\n$stackTrace');
      if (!mounted) return;
      setState(() => _isBlockingUser = false);
      showGenesisToast(
        context,
        _blockActionFailureMessage(error, 'Block failed'),
      );
    }
  }

  Future<bool> _confirmBlockUser() async {
    final confirmed = await showGenesisActionBox<bool>(
      context: context,
      title: 'Block this user?',
      actions: [
        GenesisActionBoxAction<bool>(
          label: 'Block',
          value: true,
          color: context.genesisColors.danger,
        ),
      ],
    );
    return confirmed == true;
  }

  Future<void> _unblockUser() async {
    if (_isBlockingUser || !_profileBlocked) return;
    final targetUid = _targetUid();
    if (targetUid.isEmpty) {
      showGenesisToast(context, 'Unblock failed');
      return;
    }
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    setState(() => _isBlockingUser = true);
    try {
      await AppServicesScope.read(
        context,
      ).api.v1.user.unblock(targetUid: targetUid);
      if (!mounted) return;
      _markProfileCollectionsLoading();
      setState(() {
        _isBlockingUser = false;
        _profileBlocked = false;
      });
      unawaited(_refreshOrigins());
      unawaited(_refreshWorlds());
    } catch (error, stackTrace) {
      debugPrint('[UserInfo][Unblock] failed: $error');
      debugPrint('[UserInfo][Unblock] stacktrace:\n$stackTrace');
      if (!mounted) return;
      setState(() => _isBlockingUser = false);
      showGenesisToast(
        context,
        _blockActionFailureMessage(error, 'Unblock failed'),
      );
    }
  }

  String _targetUid() {
    return _profileUid.trim().isEmpty ? widget.uid.trim() : _profileUid.trim();
  }

  void _clearProfileCollections() {
    _originsState.value =
        const UserProfileCollectionState<UserProfileOriginItem>(
          items: <UserProfileOriginItem>[],
          isLoading: false,
        );
    _worldsState.value = const UserProfileCollectionState<UserProfileWorldItem>(
      items: <UserProfileWorldItem>[],
      isLoading: false,
    );
  }

  void _markProfileCollectionsLoading() {
    _originsState.value =
        const UserProfileCollectionState<UserProfileOriginItem>(
          items: <UserProfileOriginItem>[],
          isLoading: true,
        );
    _worldsState.value = const UserProfileCollectionState<UserProfileWorldItem>(
      items: <UserProfileWorldItem>[],
      isLoading: true,
    );
  }

  String _blockActionFailureMessage(Object error, String fallback) {
    if (error is ApiException && error.code != null) {
      return '${error.message}[${error.code}]';
    }
    return fallback;
  }

  void _handleBack() {
    if (!BlockedUserReviewReturn.consumePendingHomePopularRefresh()) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.home,
      (route) => false,
      arguments: const {'home_tab': 'popular'},
    );
  }

  Future<List<UserProfileOriginItem>> _loadOriginItems(
    GenesisApi api,
    String uid,
  ) async {
    final originPage = await api.getMyLaunchedOrigins(
      uid: uid,
      scene: 'uid',
      limit: 30,
      offset: 0,
    );
    return originPage.data
        .map(
          (item) => UserProfileOriginItem(
            originId: item.id,
            oid: item.oid,
            title: item.name.trim().isEmpty ? item.oid : item.name.trim(),
            subtitle: _originSubtitle(item),
            deleted: item.deleted,
            imageUrl: resolveAssetUrl(item.mapImage),
            copyCount: item.copyCount,
            interactCount: item.interactCount,
            characterCount: item.characterCount,
          ),
        )
        .toList(growable: false);
  }

  Future<List<UserProfileWorldItem>> _loadWorldItems(
    GenesisApi api,
    String uid,
  ) async {
    final worlds = await api.getMyWorlds(
      uid: uid,
      scene: 'uid',
      limit: 30,
      offset: 0,
    );
    return worlds
        .map(
          (item) => UserProfileWorldItem(
            wid: item.wid,
            title: item.name.trim().isEmpty ? item.wid : item.name.trim(),
            subtitle: _worldSubtitle(
              item.wid,
              item.ownerName,
              deleted: item.deleted,
            ),
            deleted: item.deleted,
            imageUrl: resolveAssetUrl(item.snapshotCoverUrl),
            progressCount: item.progressCount,
            interactCount: item.interactCount,
            characterCount: item.characterCount,
            playerCount: item.playerCount,
            ownerName: item.ownerName,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !BlockedUserReviewReturn.hasPendingHomePopularRefresh,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!BlockedUserReviewReturn.consumePendingHomePopularRefresh()) {
          Navigator.of(context).maybePop();
          return;
        }
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteNames.home,
          (route) => false,
          arguments: const {'home_tab': 'popular'},
        );
      },
      child: Scaffold(
        backgroundColor: context.genesisColors.pageBackground,
        appBar: GenesisBackAppBar(
          pageName: _profileCollapsed ? _profileTitle : '',
          onBack: _handleBack,
          actions: [
            if (!_profileIsSelf)
              GenesisMoreActionMenuButton(
                visualRightInset: 16,
                items: [
                  genesisReportMenuItem(
                    context: context,
                    targetType: 'user',
                    targetId: _profileUid.trim().isEmpty
                        ? widget.uid.trim()
                        : _profileUid.trim(),
                  ),
                  GenesisActionMenuItem(
                    label: _profileBlocked ? 'Unblock' : 'Block',
                    iconData: Icons.block,
                    onSelected: _profileBlocked
                        ? _handleUnblockUser
                        : _handleBlockUser,
                  ),
                ],
              ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: FutureBuilder<UserProfileData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _UserInfoLoadingSkeleton();
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Load failed'),
                      const SizedBox(height: 8),
                      GenesisButton(
                        label: 'Retry',
                        onPressed: _refresh,
                        size: GenesisButtonSize.compact,
                        fullWidth: false,
                      ),
                    ],
                  ),
                );
              }

              final data = snapshot.data;
              if (data == null) return const SizedBox.shrink();
              return UserProfileContent(
                data: data,
                originsListenable: _originsState,
                worldsListenable: _worldsState,
                gemWalletStateListenable: data.isSelf
                    ? AppServicesScope.of(context).gemWallet.state
                    : null,
                onRefreshOrigins: _refreshOrigins,
                onRefreshWorlds: _refreshWorlds,
                onCollapsedChanged: _handleProfileCollapsedChanged,
                isBlocking: _isBlockingUser,
                isBlocked: _profileBlocked,
                appearance: UserProfileAppearance.worldoMe,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UserInfoLoadingSkeleton extends StatelessWidget {
  const _UserInfoLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    // Mirrors the worldoMe profile header geometry: 72px circular avatar,
    // 22px page margin, 36px-tall action buttons on the design button radius.
    return const _UserInfoSkeletonShimmer(
      child: Column(
        key: ValueKey<String>('user-info-loading-skeleton'),
        children: [
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _UserInfoSkeletonBone(width: 72, height: 72, borderRadius: 36),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _UserInfoSkeletonBone(
                        widthFactor: 0.58,
                        height: 20,
                        borderRadius: 4,
                      ),
                      SizedBox(height: 8),
                      _UserInfoSkeletonBone(
                        width: 96,
                        height: 10,
                        borderRadius: 4,
                      ),
                      SizedBox(height: 8),
                      _UserInfoSkeletonBone(
                        width: 128,
                        height: 12,
                        borderRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: _UserInfoSkeletonBone(height: 36, borderRadius: 11),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _UserInfoSkeletonBone(height: 36, borderRadius: 11),
                ),
              ],
            ),
          ),
          SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 22),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UserInfoSkeletonBone(width: 54, height: 20, borderRadius: 4),
                  SizedBox(width: 20),
                  _UserInfoSkeletonBone(width: 48, height: 20, borderRadius: 4),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: _UserInfoCollectionSkeletonList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserInfoCollectionSkeletonList extends StatelessWidget {
  const _UserInfoCollectionSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 17, bottom: 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemBuilder: (context, index) => const _UserInfoCollectionSkeletonItem(),
    );
  }
}

class _UserInfoCollectionSkeletonItem extends StatelessWidget {
  const _UserInfoCollectionSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UserInfoSkeletonBone(
          width: 52,
          height: 52,
          borderRadius: GenesisImageRadii.contentValue,
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserInfoSkeletonBone(
                widthFactor: 0.48,
                height: 15,
                borderRadius: 4,
              ),
              SizedBox(height: 7),
              _UserInfoSkeletonBone(
                widthFactor: 0.92,
                height: 10,
                borderRadius: 4,
              ),
              SizedBox(height: 6),
              _UserInfoSkeletonBone(
                widthFactor: 0.68,
                height: 10,
                borderRadius: 4,
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  _UserInfoSkeletonBone(width: 34, height: 14, borderRadius: 3),
                  SizedBox(width: 10),
                  _UserInfoSkeletonBone(width: 42, height: 14, borderRadius: 3),
                  SizedBox(width: 10),
                  _UserInfoSkeletonBone(width: 36, height: 14, borderRadius: 3),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _UserInfoSkeletonShimmer = GenesisShimmer;
typedef _UserInfoSkeletonBone = GenesisSkeletonBone;

String _originSubtitle(OriginSummary item) {
  final oid = deletedAwareIdLabel(item.oid, deleted: item.deleted);
  final originator = item.originator.trim().isEmpty
      ? '-'
      : formatUidForDisplay(item.originator);
  final version = item.versionNum <= 0 ? '-' : 'V${item.versionNum}';
  return 'OID: $oid  Originator: $originator\n'
      'Latest Version: $version';
}

String _worldSubtitle(String wid, String ownerName, {bool deleted = false}) {
  final displayWid = deletedAwareIdLabel(wid, deleted: deleted);
  final owner = formatUidForDisplay(ownerName, fallback: '-');
  return 'WID: $displayWid  Owner: $owner';
}

String _mapString(
  Map<dynamic, dynamic>? map,
  String key, {
  String fallback = '',
}) {
  final value = map == null ? null : map[key];
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _mapInt(Map<dynamic, dynamic>? map, String key) {
  final value = map == null ? null : map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _mapBool(Map<dynamic, dynamic>? map, String key) {
  final value = map == null ? null : map[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}
