import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/common/copyable_id_label.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import '../../components/auth/login_guard.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/discuss/story_badge.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/login_sheet.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/origin/stat_item.dart';
import '../../components/world_map.dart';
import '../../components/world_map_stage.dart';
import '../../components/world_details_shell.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../components/world_tick_event_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/origin.dart';
import '../../platform/auth/auth_session.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/stat_count_formatter.dart';
import '../chat/location_chat_page.dart';

class OriginWorldPage extends StatefulWidget {
  const OriginWorldPage({super.key, required this.oid, required this.originId});

  final String oid;
  final int originId;

  @override
  State<OriginWorldPage> createState() => _OriginWorldPageState();
}

class _OriginWorldPageState extends State<OriginWorldPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final OriginDiscussListController _discussController;
  Future<OriginDetail>? _future;
  bool _launching = false;
  _OriginLocationChatDescriptor? _activeChatLocation;
  var _currentUid = '';
  var _currentUidRequested = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _discussController = OriginDiscussListController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _loadOriginDetail();
    if (!_currentUidRequested) {
      _currentUidRequested = true;
      unawaited(_loadCurrentUid());
    }
  }

  @override
  void didUpdateWidget(covariant OriginWorldPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oid != widget.oid) {
      _future = _loadOriginDetail();
      _activeChatLocation = null;
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _future = _loadOriginDetail();
    });
  }

  @override
  void dispose() {
    GenesisSystemUiChrome.applyDefault();
    _discussController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<OriginDetail> _loadOriginDetail() {
    final api = AppServicesScope.read(context).api;
    final future = api.getOrigin(widget.oid);
    future.then((origin) {
      if (!mounted) return;
      _configureDiscuss(origin.oid);
      unawaited(_discussController.loadInitialIfNeeded());
    }, onError: (_) {});
    return future;
  }

  void _refreshOriginDetail() {
    setState(() {
      _future = _loadOriginDetail();
    });
  }

  Future<void> _loadCurrentUid() async {
    final uid =
        (await AppServicesScope.of(context).sessionStore.readUid())?.trim() ??
        '';
    if (!mounted || uid == _currentUid) return;
    setState(() => _currentUid = uid);
  }

  void _configureDiscuss(String oid) {
    _discussController.configure(
      oid: oid,
      loader: ({required String oid, required int pn, required int rn}) async {
        return loadOriginDiscussPage(context, oid, pn: pn, rn: rn);
      },
    );
  }

  void _showMapTab() {
    if (_tabController.index == 0) return;
    _tabController.animateTo(
      0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  void _openChatForPoint(OriginDetail origin, WorldPoint point) {
    final pointId = point.pointId.trim().isNotEmpty
        ? point.pointId.trim()
        : point.id.trim();
    final locationId = point.sceneId.trim().isNotEmpty
        ? point.sceneId.trim()
        : pointId;
    if (locationId.isEmpty) return;

    setState(() {
      _activeChatLocation = _OriginLocationChatDescriptor(
        originId: origin.oid,
        locationId: locationId,
        locationName: point.name,
        isLeafLocation: point.isLeafLocation,
      );
    });
  }

  void _closeLocationChat() {
    if (_activeChatLocation == null) return;
    setState(() => _activeChatLocation = null);
  }

  void _handleOriginPopBlocked() {
    if (_activeChatLocation == null) return;
    _closeLocationChat();
  }

  Widget? _buildLocationChatOverlay(OriginDetail origin) {
    final descriptor = _activeChatLocation;
    if (descriptor == null) return null;
    return Positioned.fill(
      child: LocationChatPanel(
        key: ValueKey('origin-location-chat-${descriptor.locationId}'),
        worldId: descriptor.originId,
        locationId: descriptor.locationId,
        locationName: descriptor.locationName,
        isLeafLocation: descriptor.isLeafLocation,
        active: false,
        leaveOnInactive: false,
        onBack: _closeLocationChat,
        showConnectionStatus: false,
        composerReplacement: _OriginLocationChatLaunchBar(
          launching: _launching,
          onLaunch: () => _showLaunchRoleSheet(origin),
        ),
      ),
    );
  }

  Widget _buildPersistentMapTabs(int pointsCount, double top) {
    return Positioned(
      left: 12,
      right: 12,
      top: top,
      child: WorldTopOverlayBar(
        pointsCount: pointsCount,
        controller: _tabController,
      ),
    );
  }

  Future<void> _showLaunchRoleSheet(OriginDetail origin) async {
    if (_launching) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    final selection = await showOriginRoleLaunchSheet(
      context: context,
      characters: origin.characters,
      resolveAvatarUrl: _resolveAssetUrl,
      onFillFromProfile: _customRoleFromProfile,
    );
    if (!mounted || selection == null) return;
    await _launchOrigin(origin, selection);
  }

  Future<void> _launchOrigin(
    OriginDetail origin,
    OriginRoleLaunchSelection roleSelection,
  ) async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      final result = await AppServicesScope.of(context).api.v1.origin.launch(
        oid: origin.oid,
        presetCharacterId: roleSelection.presetCharacterId,
        customRole: roleSelection.customRole?.toPayload(),
      );
      if (!mounted) return;
      final wid = '${result['world_id'] ?? result['wid'] ?? ''}'.trim();
      if (wid.isEmpty) {
        showGenesisToast(context, 'Launch failed');
        return;
      }
      Navigator.of(context).pushNamed(
        RouteNames.world,
        arguments: {'wid': wid, 'wait_for_tick1': true},
      );
    } catch (_) {
      if (!mounted) return;
      showGenesisToast(context, 'Launch failed');
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<OriginCustomRoleDraft?> _customRoleFromProfile() async {
    if (!await _ensureProfileFillLogin()) return null;
    if (!mounted) return null;
    final services = AppServicesScope.read(context);
    final userInfo = await services.sessionStore.readUserInfo();
    final profile = services.identityAuth.currentProfile();
    if ((userInfo == null || userInfo.isEmpty) && profile == null) {
      if (mounted) {
        showGenesisToast(context, 'No saved profile found');
      }
      return null;
    }
    final cachedUser = userInfo ?? const <String, dynamic>{};
    final profileAvatar = profile?.photoUrl.trim() ?? '';
    final cachedName = _mapString(cachedUser, const [
      'name',
      'nickname',
      'user_name',
      'displayName',
      'display_name',
    ]);
    final profileName = (profile?.displayName.trim().isNotEmpty ?? false)
        ? profile!.displayName.trim()
        : (profile?.email.trim() ?? '');
    final resolvedAvatar = _resolvedProfileAvatar(cachedUser, profileAvatar);

    return OriginCustomRoleDraft(
      avatarUrl: resolvedAvatar,
      name: cachedName.isNotEmpty ? cachedName : profileName,
      identity: _mapString(cachedUser, const ['identity']),
      bio: _mapString(cachedUser, const ['bio', 'description']),
    );
  }

  Future<bool> _ensureProfileFillLogin() async {
    if (await _hasLocalLoginSession()) return true;
    if (!mounted) return false;
    final loggedIn = await showLoginSheet(
      context: context,
      onLogin: _loginWithProvider,
    );
    if (!mounted || !loggedIn) return false;
    return _hasLocalLoginSession();
  }

  Future<bool> _hasLocalLoginSession() async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    return uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty;
  }

  Future<bool> _loginWithProvider(IdentityProvider provider) async {
    final services = AppServicesScope.read(context);
    final session = await services.identityAuth.signIn(provider);
    final user = await services.backendAuth.loginWithIdentity(session);
    if (user.uid.trim().isNotEmpty) {
      await services.sessionStore.saveUid(user.uid);
    }
    final cachedUserInfo = await services.sessionStore.readUserInfo();
    final loginUserInfo = <String, dynamic>{
      if (cachedUserInfo != null) ...cachedUserInfo,
      'uid': user.uid,
    };
    if (user.nickname.trim().isNotEmpty) {
      loginUserInfo['name'] = user.nickname;
    }
    if (user.avatar.trim().isNotEmpty) {
      loginUserInfo['avatar'] = user.avatar;
    }
    await services.sessionStore.saveUserInfo(loginUserInfo);
    services.notifySessionChanged();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return FutureBuilder<OriginDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return WorldDetailsPageScaffold(
            panelTopGap: 50,
            panelCollapsedHeightOffset: 100,
            persistentTopOverlay: _buildPersistentMapTabs(0, topPadding + 8),
            map: WorldMapStage(
              controller: _tabController,
              pointsCount: 0,
              top: topPadding + 8,
              showTopOverlay: false,
              mapBuilder: (context, pointMode) => WorldMap(
                points: const <WorldPoint>[],
                listPoints: const <WorldPoint>[],
                locationNodes: const <WorldMapLocationNode>[],
                fallbackOnEmptyMapUrl: false,
                dimmed: pointMode,
                showPointsList: pointMode,
                overlayTop: topPadding + 8 + 48,
                drillExitTop: topPadding + 68,
              ),
            ),
            slivers: const [_OriginDetailsLoadingContent()],
            bottomBar: const _OriginBottomLaunchBarSkeleton(),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Load failed'),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => setState(() {
                      _future = _loadOriginDetail();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final origin = snapshot.data;
        if (origin == null) {
          return const Scaffold(body: Center(child: Text('No data')));
        }

        final processedLocationTree = origin.processedLocationTree;
        final rootLocationNodes = processedLocationTree.mapRoots;
        final mapImageUrl = _originRootMapImageUrl(rootLocationNodes);
        final renderLocationNodes = processedLocationTree.renderRoots;
        final allLocationNodes = processedLocationTree.flattened;
        final avatarsByLocation = _originAvatarsByLocation(
          origin.characters,
          origin.allLocations,
        );
        final locationNodes = _originMapLocationNodes(
          rootLocationNodes,
          avatarsByLocation,
          processedLocationTree,
        );
        final points = renderLocationNodes.isNotEmpty
            ? _pointsFromLocations(
                renderLocationNodes
                    .map((node) => node.value)
                    .toList(growable: false),
                avatarsByLocation,
                depths: renderLocationNodes
                    .map((node) => node.depth)
                    .toList(growable: false),
                isLeafLocations: renderLocationNodes
                    .map((node) => node.children.isEmpty)
                    .toList(growable: false),
                usersByIndex: renderLocationNodes
                    .map(
                      (node) =>
                          processedLocationTree.aggregateValues<UserAvatar>(
                            node.id,
                            avatarsByLocation,
                            idOf: _userAvatarStableId,
                          ),
                    )
                    .toList(growable: false),
              )
            : _pointsFromLocations(
                _rootOriginLocations(origin.allLocations),
                avatarsByLocation,
              );
        final listPoints = allLocationNodes.isNotEmpty
            ? _pointsFromLocations(
                allLocationNodes
                    .map((node) => node.value)
                    .toList(growable: false),
                avatarsByLocation,
                depths: allLocationNodes
                    .map((node) => node.depth)
                    .toList(growable: false),
                isLeafLocations: allLocationNodes
                    .map((node) => node.children.isEmpty)
                    .toList(growable: false),
                usersByIndex: allLocationNodes
                    .map(
                      (node) =>
                          processedLocationTree.aggregateValues<UserAvatar>(
                            node.id,
                            avatarsByLocation,
                            idOf: _userAvatarStableId,
                          ),
                    )
                    .toList(growable: false),
              )
            : origin.allLocations.isNotEmpty
            ? _pointsFromLocations(origin.allLocations, avatarsByLocation)
            : points;

        return PopScope(
          canPop: _activeChatLocation == null,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleOriginPopBlocked();
          },
          child: WorldDetailsPageScaffold(
            panelTopGap: 50,
            panelCollapsedHeightOffset: 60,
            topOverlay: _buildLocationChatOverlay(origin),
            persistentTopOverlay: _buildPersistentMapTabs(
              listPoints.length,
              topPadding + 8,
            ),
            map: WorldMapStage(
              controller: _tabController,
              pointsCount: listPoints.length,
              top: topPadding + 8,
              showTopOverlay: false,
              mapBuilder: (context, pointMode) => WorldMap(
                points: points,
                listPoints: listPoints,
                locationNodes: locationNodes,
                mapImageUrl: mapImageUrl,
                dimmed: pointMode,
                showPointsList: pointMode,
                overlayTop: topPadding + 8 + 48,
                drillExitTop: topPadding + 68,
                onDrillIntoLocation: _showMapTab,
                onPointTap: (point) => _openChatForPoint(origin, point),
              ),
            ),
            slivers: [
              _WorldDetailsContent(
                origin: origin,
                currentUid: _currentUid,
                discussController: _discussController,
                onOriginChanged: _refreshOriginDetail,
              ),
            ],
            bottomBar: _OriginBottomLaunchBar(
              origin: origin,
              launching: _launching,
              onLaunch: () => _showLaunchRoleSheet(origin),
            ),
          ),
        );
      },
    );
  }
}

class _OriginLocationChatDescriptor {
  const _OriginLocationChatDescriptor({
    required this.originId,
    required this.locationId,
    required this.locationName,
    required this.isLeafLocation,
  });

  final String originId;
  final String locationId;
  final String locationName;
  final bool isLeafLocation;
}

class _OriginLocationChatLaunchBar extends StatelessWidget {
  const _OriginLocationChatLaunchBar({
    required this.launching,
    required this.onLaunch,
  });

  final bool launching;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF9F9F9)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
        child: GenesisPrimaryButton(
          label: launching ? 'Launching...' : 'Launch to send',
          onPressed: launching ? null : onLaunch,
          backgroundColor: const Color(0xFF238861),
          disabledBackgroundColor: const Color(
            0xFF238861,
          ).withValues(alpha: 0.62),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
        ),
      ),
    );
  }
}

class _OriginDetailsLoadingContent extends StatelessWidget {
  const _OriginDetailsLoadingContent();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        _OriginHeaderLoadingSkeleton(),
        SizedBox(height: 22),
        _OriginSectionLoadingSkeleton(
          titleWidth: 96,
          imageAspectRatio: 2 / 3,
          lineWidths: [0.94, 0.82, 0.68],
        ),
        SizedBox(height: 26),
        _OriginSectionLoadingSkeleton(
          titleWidth: 118,
          imageHeight: 92,
          lineWidths: [0.88, 0.76],
        ),
        SizedBox(height: 28),
        _OriginSectionTitleLoadingSkeleton(width: 146),
        SizedBox(height: 10),
        _OriginLoadingBone(width: 108, height: 12),
        SizedBox(height: 18),
        _OriginSectionTitleLoadingSkeleton(width: 92),
        SizedBox(height: 14),
        _OriginLoadingBone(widthFactor: 0.96, height: 74, radius: 6),
        SizedBox(height: 24),
        Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
        SizedBox(height: 24),
        _OriginSectionTitleLoadingSkeleton(width: 112),
        SizedBox(height: 14),
        _OriginCharacterLoadingSkeleton(),
      ],
    );
  }
}

class _OriginHeaderLoadingSkeleton extends StatelessWidget {
  const _OriginHeaderLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _OriginLoadingBone(width: 170, height: 18)),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _OriginLoadingBone(width: 122, height: 12)),
            SizedBox(width: 12),
            _OriginLoadingBone(width: 128, height: 12),
          ],
        ),
        SizedBox(height: 12),
        _OriginLoadingBone(width: 150, height: 12),
      ],
    );
  }
}

class _OriginSectionLoadingSkeleton extends StatelessWidget {
  const _OriginSectionLoadingSkeleton({
    required this.titleWidth,
    this.imageHeight,
    this.imageAspectRatio,
    required this.lineWidths,
  }) : assert(imageHeight != null || imageAspectRatio != null);

  final double titleWidth;
  final double? imageHeight;
  final double? imageAspectRatio;
  final List<double> lineWidths;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OriginSectionTitleLoadingSkeleton(width: titleWidth),
        const SizedBox(height: 12),
        for (final width in lineWidths) ...[
          _OriginLoadingBone(widthFactor: width, height: 12),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        if (imageAspectRatio == null)
          _OriginLoadingBone(widthFactor: 1, height: imageHeight!, radius: 4)
        else
          _OriginLoadingAspectBone(aspectRatio: imageAspectRatio!, radius: 4),
      ],
    );
  }
}

class _OriginLoadingAspectBone extends StatelessWidget {
  const _OriginLoadingAspectBone({required this.aspectRatio, this.radius = 4});

  final double aspectRatio;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE9EDF2),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _OriginSectionTitleLoadingSkeleton extends StatelessWidget {
  const _OriginSectionTitleLoadingSkeleton({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _OriginLoadingBone(width: 14, height: 14, radius: 7),
        const SizedBox(width: 8),
        _OriginLoadingBone(width: width, height: 14),
      ],
    );
  }
}

class _OriginCharacterLoadingSkeleton extends StatelessWidget {
  const _OriginCharacterLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OriginLoadingBone(width: 86, height: 86, radius: 6),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OriginLoadingBone(width: 118, height: 14),
              SizedBox(height: 8),
              _OriginLoadingBone(widthFactor: 0.68, height: 12),
              SizedBox(height: 10),
              _OriginLoadingBone(widthFactor: 0.94, height: 12),
              SizedBox(height: 8),
              _OriginLoadingBone(widthFactor: 0.72, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginBottomLaunchBarSkeleton extends StatelessWidget {
  const _OriginBottomLaunchBarSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF9F9F9)),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(13, 0, 13, 0),
        child: SizedBox(
          height: 56,
          child: Row(
            children: const [
              _OriginLoadingBone(width: 36, height: 12),
              SizedBox(width: 20),
              _OriginLoadingBone(width: 36, height: 12),
              SizedBox(width: 20),
              _OriginLoadingBone(width: 36, height: 12),
              Spacer(),
              _OriginLoadingBone(width: 140, height: 35, radius: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OriginLoadingBone extends StatelessWidget {
  const _OriginLoadingBone({
    this.width,
    this.widthFactor,
    required this.height,
    this.radius = 4,
  });

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF2),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: SizedBox(width: width, height: height),
    );
    final widthFactor = this.widthFactor;
    if (widthFactor == null) return child;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

class _WorldDetailsContent extends StatelessWidget {
  const _WorldDetailsContent({
    required this.origin,
    required this.currentUid,
    required this.discussController,
    required this.onOriginChanged,
  });

  final OriginDetail origin;
  final String currentUid;
  final OriginDiscussListController discussController;
  final VoidCallback onOriginChanged;

  @override
  Widget build(BuildContext context) {
    final previewTick = _originPreviewTick(origin);
    return SliverList.list(
      children: [
        _OriginHeader(
          origin: origin,
          currentUid: currentUid,
          onOriginChanged: onOriginChanged,
        ),
        // Section gap: header -> world view.
        const SizedBox(height: 24),
        _WorldViewSection(origin: origin),
        if (previewTick != null) ...[
          // Section gap: world view -> launch preview.
          const SizedBox(height: 24),
          _LaunchPreviewSection(origin: origin, previewTick: previewTick),
        ],
        // Section gap: previous content -> copy world progress.
        const SizedBox(height: 24),
        CopyWorldProgressSection(originId: origin.oid),
        // Section gap: copy world progress -> discuss.
        const SizedBox(height: 24),
        _DiscussSection(origin: origin, controller: discussController),
        // Section gap: discuss -> characters.
        const SizedBox(height: 24),
        _OriginCharactersSection(characters: origin.characters),
      ],
    );
  }
}

class _OriginBottomLaunchBar extends StatelessWidget {
  const _OriginBottomLaunchBar({
    required this.origin,
    required this.launching,
    required this.onLaunch,
  });

  final OriginDetail origin;
  final bool launching;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFF9F9F9)),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(13, 0, 13, 0),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _LaunchBarStat(
                          iconAsset: copyStatIconAsset,
                          value: origin.copyCount,
                        ),
                        const SizedBox(width: 20),
                        _LaunchBarStat(
                          iconAsset: connectStatIconAsset,
                          value: origin.interactCount,
                        ),
                        const SizedBox(width: 20),
                        _LaunchBarStat(
                          iconAsset: characterStatIconAsset,
                          preserveIconAssetColor: true,
                          value: origin.characterCount,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 140,
                height: 35,
                child: FilledButton(
                  onPressed: launching ? null : onLaunch,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF238861),
                    disabledBackgroundColor: const Color(
                      0xFF238861,
                    ).withValues(alpha: 0.62),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      height: 1,
                      fontWeight: FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: launching
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Launch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchBarStat extends StatelessWidget {
  const _LaunchBarStat({
    this.icon,
    this.iconAsset,
    this.preserveIconAssetColor = false,
    required this.value,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final bool preserveIconAssetColor;
  final int value;

  @override
  Widget build(BuildContext context) {
    return StatItem(
      icon: icon,
      iconAsset: iconAsset,
      preserveIconAssetColor: preserveIconAssetColor,
      iconSize: 14,
      iconAssetScale: 1,
      iconVerticalOffset: 0,
      iconColor: const Color(0xFF111111),
      gap: 4,
      text: formatStatCount(value),
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1,
        fontWeight: FontWeight.w400,
        color: Color(0xFF111111),
      ),
    );
  }
}

class _OriginHeader extends StatelessWidget {
  const _OriginHeader({
    required this.origin,
    required this.currentUid,
    required this.onOriginChanged,
  });

  final OriginDetail origin;
  final String currentUid;
  final VoidCallback onOriginChanged;

  @override
  Widget build(BuildContext context) {
    final originator = origin.originator.trim().isEmpty
        ? '-'
        : formatUidForDisplay(origin.originator);
    final ownerUid = origin.ownerUid.trim();
    final canEditOrigin =
        currentUid.trim().isNotEmpty && currentUid.trim() == ownerUid;
    final version = origin.versionNum <= 0 ? 1 : origin.versionNum;
    final age = formatGenesisDateTime(origin.updatedAt, fallback: '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            originDisplayName(origin.name, fallback: origin.oid),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4B6192),
            ),
          ),
        ),
        // Header inner spacing: title -> OID/originator row.
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: CopyableIdLabel(label: 'OID', value: origin.oid),
            ),
            // Header inner spacing: OID label -> originator link.
            const SizedBox(width: 12),
            _OriginatorMetaLink(
              originator: originator,
              onTap: ownerUid.isEmpty
                  ? null
                  : () => Navigator.of(context).pushNamed(
                      RouteNames.userInfo,
                      arguments: {'uid': ownerUid},
                    ),
            ),
          ],
        ),
        // Header inner spacing: OID/originator row -> latest version.
        const SizedBox(height: 0),
        Text(
          'Latest Version: V$version${age.isEmpty ? '' : ' · $age'}',
          style: CopyableIdLabel.textStyle,
        ),
        if (canEditOrigin) ...[
          // Header inner spacing: latest version -> edit button.
          const SizedBox(height: 8),
          GenesisPrimaryButton(
            label: 'Edit Origin',
            onPressed: () async {
              await Navigator.of(context).pushNamed(
                RouteNames.edit,
                arguments: {'origin_id': origin.oid},
              );
              if (!context.mounted) return;
              onOriginChanged();
            },
            backgroundColor: const Color(0xFF3B2468),
            foregroundColor: Colors.white,
          ),
        ],
      ],
    );
  }
}

class _OriginatorMetaLink extends StatelessWidget {
  const _OriginatorMetaLink({required this.originator, required this.onTap});

  final String originator;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Text(
                'Originator: ${formatUidForDisplay(originator)}',
                textAlign: TextAlign.right,
                style: CopyableIdLabel.textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Originator link inner spacing: text -> chevron.
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: CopyableIdLabel.iconColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldViewSection extends StatelessWidget {
  const _WorldViewSection({required this.origin});

  final OriginDetail origin;

  @override
  Widget build(BuildContext context) {
    final body = origin.worldView.trim().isEmpty
        ? origin.description.trim()
        : origin.worldView.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: MyFlutterApp.eye,
          iconColor: Color(0xFFF42C47),
          title: 'World View',
        ),
        // World view inner spacing: section title -> body text.
        const SizedBox(height: 8),
        Text(body, style: _bodyTextStyle),
        // World view inner spacing: body text -> preview image.
        const SizedBox(height: 8),
        _PreviewImage(url: _resolveAssetUrl(origin.mapImage)),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.url});

  static const double _maxHeight = 360;
  static const double _aspectRatio = 2 / 3;

  final String url;

  @override
  Widget build(BuildContext context) {
    final viewerUrl = url.trim();
    final fallback = Container(
      color: const Color(0xFFEFF1F4),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFF9A9A9A)),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaHeight = MediaQuery.sizeOf(context).height;
        final maxHeight = mediaHeight.isFinite
            ? _maxHeight.clamp(0.0, mediaHeight * 0.35).toDouble()
            : _maxHeight;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxHeight * _aspectRatio;
        final width = maxWidth.clamp(0.0, maxHeight * _aspectRatio).toDouble();
        final height = width / _aspectRatio;

        final preview = Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: GenesisImageRadii.content,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imageUrl = selectGenesisImageUrl(
                    url,
                    logicalWidth: constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : null,
                    logicalHeight: constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : null,
                    devicePixelRatio:
                        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
                  );
                  return imageUrl.isEmpty
                      ? fallback
                      : imageUrl.startsWith('assets/')
                      ? Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              fallback,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              fallback,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return fallback;
                          },
                        );
                },
              ),
            ),
          ),
        );
        if (viewerUrl.isEmpty) return preview;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showGenesisImageViewer(context, imageUrls: [viewerUrl]),
          child: preview,
        );
      },
    );
  }
}

class _LaunchPreviewSection extends StatelessWidget {
  const _LaunchPreviewSection({
    required this.origin,
    required this.previewTick,
  });

  final OriginDetail origin;
  final Map<String, dynamic> previewTick;

  @override
  Widget build(BuildContext context) {
    final tickResult = previewTick['tick_result'] is Map
        ? (previewTick['tick_result'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final globalBody = _mapString(tickResult, const ['narrator']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: Icons.auto_awesome,
          iconColor: Color(0xFF6554FF),
          title: 'Launch Preview',
        ),
        // Launch preview inner spacing: section title -> preview event item.
        const SizedBox(height: 8),
        WorldTickEventItem(
          tick: previewTick,
          tickNumber: 1,
          fallbackBody: globalBody,
          locationsById: _originLocationsById(origin.allLocations),
          dateLabel: origin.startTime.trim().isEmpty
              ? 'Day 1, 18:00'
              : formatGenesisTimestamp(origin.startTime),
          timeAgoLabel: '',
          stackedContent: true,
        ),
      ],
    );
  }
}

class CopyWorldProgressSection extends StatefulWidget {
  const CopyWorldProgressSection({super.key, required this.originId});

  final String originId;

  @override
  State<CopyWorldProgressSection> createState() =>
      _CopyWorldProgressSectionState();
}

class _CopyWorldProgressSectionState extends State<CopyWorldProgressSection> {
  static const _rotationInterval = Duration(seconds: 8);

  Timer? _timer;
  var _summaries = const <WorldSummaryLatestItem>[];
  var _visibleIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSummaries());
  }

  @override
  void didUpdateWidget(covariant CopyWorldProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.originId != widget.originId) {
      _timer?.cancel();
      _summaries = const <WorldSummaryLatestItem>[];
      _visibleIndex = 0;
      unawaited(_loadSummaries());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadSummaries() async {
    final originId = widget.originId.trim();
    if (originId.isEmpty) {
      _applySummaries(const <WorldSummaryLatestItem>[]);
      return;
    }
    try {
      final summaries = await AppServicesScope.read(
        context,
      ).api.getLatestWorldSummaries(originId: originId);
      if (!mounted || widget.originId.trim() != originId) return;
      _applySummaries(summaries);
    } catch (_) {
      if (!mounted || widget.originId.trim() != originId) return;
      _applySummaries(const <WorldSummaryLatestItem>[]);
    }
  }

  void _applySummaries(List<WorldSummaryLatestItem> summaries) {
    _timer?.cancel();
    final visible = summaries
        .where((item) => item.summary.trim().isNotEmpty)
        .toList(growable: false);
    setState(() {
      _summaries = visible;
      _visibleIndex = 0;
    });
    if (visible.length <= 1) return;
    _timer = Timer.periodic(_rotationInterval, (_) {
      if (!mounted || _summaries.length <= 1) return;
      setState(() {
        _visibleIndex = (_visibleIndex + 1) % _summaries.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryIndex = _visibleIndex >= _summaries.length ? 0 : _visibleIndex;
    final summary = _summaries.isEmpty ? null : _summaries[summaryIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          icon: MyFlutterApp.lastProgress,
          iconColor: Color(0xFFF42C47),
          title: 'Copy World Progress',
        ),
        // Copy progress inner spacing: section title -> summary body.
        const SizedBox(height: 8),
        _CopyWorldProgressCard(summary: summary),
      ],
    );
  }
}

class _CopyWorldProgressCard extends StatelessWidget {
  const _CopyWorldProgressCard({required this.summary});

  static const double _bodyFontSize = 12;
  static const double _bodyLineHeight = 1.45;
  static const double _bodyHeight = _bodyFontSize * _bodyLineHeight * 5 + 6;
  static final _bodyStyle = _bodyTextStyle.copyWith(
    color: const Color(0xFF111111),
  );
  static const _bodyStrutStyle = StrutStyle(
    fontSize: _bodyFontSize,
    height: _bodyLineHeight,
    forceStrutHeight: true,
  );

  final WorldSummaryLatestItem? summary;

  @override
  Widget build(BuildContext context) {
    final item = summary;
    final body = item?.summary.trim();
    if (item == null || body == null || body.isEmpty) {
      return const Text(
        'No launched world',
        key: ValueKey('copy-world-progress-empty'),
        style: TextStyle(
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: Color(0xFF999999),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(
        context,
      ).pushNamed(RouteNames.world, arguments: {'wid': item.worldId}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: const ValueKey('copy-world-progress-body'),
            height: _bodyHeight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 520),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topLeft,
                  clipBehavior: Clip.none,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: Text(
                body,
                key: ValueKey(item.worldId),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                strutStyle: _bodyStrutStyle,
                style: _bodyStyle,
              ),
            ),
          ),
          // Copy progress inner spacing: summary body -> WID/tick/time row.
          const SizedBox(height: 0),
          _CopyWorldProgressMeta(summary: item),
        ],
      ),
    );
  }
}

class _CopyWorldProgressMeta extends StatelessWidget {
  const _CopyWorldProgressMeta({required this.summary});

  final WorldSummaryLatestItem? summary;

  @override
  Widget build(BuildContext context) {
    final item = summary;
    if (item == null) {
      return const SizedBox(height: 18);
    }
    final timestamp = _formatSummaryTimestamp(
      item.tickTime == 0 ? item.createdAt : item.tickTime,
    );
    return LayoutBuilder(
      key: const ValueKey('copy-world-progress-meta'),
      builder: (context, constraints) {
        const gap = 12.0;
        final hasTimestamp = timestamp.isNotEmpty;
        final timeWidth = hasTimestamp
            ? constraints.maxWidth.clamp(0, 96).toDouble()
            : 0.0;
        final leftWidth =
            (constraints.maxWidth - (hasTimestamp ? timeWidth + gap : 0))
                .clamp(0.0, constraints.maxWidth)
                .toDouble();
        return Row(
          children: [
            SizedBox(
              width: leftWidth,
              child: Row(
                key: const ValueKey('copy-world-progress-left-meta'),
                children: [
                  Flexible(
                    child: Text(
                      'WID: ${item.worldId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _copyWorldProgressMetaStyle,
                    ),
                  ),
                  // Copy progress meta spacing: WID -> tick badge.
                  const SizedBox(width: 8),
                  DiscussStoryBadge(count: item.tickNo),
                ],
              ),
            ),
            if (hasTimestamp) ...[
              // Copy progress meta spacing: WID/tick area -> timestamp.
              const SizedBox(width: gap),
              SizedBox(
                width: timeWidth,
                child: Text(
                  timestamp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: _copyWorldProgressMetaStyle,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DiscussSection extends StatelessWidget {
  const _DiscussSection({required this.origin, required this.controller});

  final OriginDetail origin;
  final OriginDiscussListController controller;

  bool get _hasDiscussContent =>
      origin.discussCount > 0 ||
      controller.totalAll > 0 ||
      controller.items.isNotEmpty;

  Future<void> _handleDiscussAreaTap(BuildContext context) {
    if (_hasDiscussContent) return _openDiscussPage(context);
    return _openPostComposer(context);
  }

  Future<void> _openDiscussPage(BuildContext context) {
    return Navigator.of(context).pushNamed(
      RouteNames.discuss,
      arguments: {'oid': origin.oid, 'originId': origin.id},
    );
  }

  Future<void> _openPostComposer(BuildContext context) async {
    final submitted = await showDiscussPostComposer(
      context: context,
      title: 'New post',
      placeholder: 'Write a post',
      submitter: (content, images) async {
        await AppServicesScope.read(context).api.v1.discuss.post(
          bizId: origin.oid.trim(),
          bizType: 1,
          content: content,
          images: images,
        );
      },
    );
    if (!context.mounted || !submitted) return;
    unawaited(controller.refreshFirstPage());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasDiscussContent = _hasDiscussContent;
        final showDiscussList =
            hasDiscussContent ||
            controller.isInitialLoading ||
            controller.error != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              key: const ValueKey('origin-discuss-summary-area'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_handleDiscussAreaTap(context)),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle(
                      iconAsset: discussIconAsset,
                      title: 'Discuss (${origin.discussCount})',
                    ),
                    if (showDiscussList) ...[
                      // Discuss inner spacing: section title -> discuss list.
                      const SizedBox(height: 8),
                      OriginDiscussList(
                        controller: controller,
                        count: origin.discussCount,
                        showHeader: false,
                        showActions: false,
                        showReplies: false,
                        onViewMoreTap: () => _openDiscussPage(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!hasDiscussContent) ...[
              // Discuss inner spacing: empty discuss summary -> post input.
              const SizedBox(height: 8),
              DiscussPostInput(
                bizId: origin.oid,
                onSubmitted: () => unawaited(controller.refreshFirstPage()),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OriginCharactersSection extends StatelessWidget {
  const _OriginCharactersSection({required this.characters});

  final List<OriginCharacter> characters;

  @override
  Widget build(BuildContext context) {
    final characterAvatarUrls = characters
        .map((character) => _resolveAssetUrl(character.avatar).trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          iconAsset: characterStatIconAsset,
          title: 'Characters (${characters.length})',
        ),
        // Characters inner spacing: section title -> first character row.
        const SizedBox(height: 14),
        if (characters.isEmpty)
          const Text('No characters', style: _mutedBodyTextStyle)
        else
          for (int i = 0; i < characters.length; i++) ...[
            _OriginCharacterRow(
              character: characters[i],
              imageUrls: characterAvatarUrls,
            ),
            // Characters inner spacing: one character row -> next row.
            if (i != characters.length - 1) const SizedBox(height: 20),
          ],
      ],
    );
  }
}

class _OriginCharacterRow extends StatelessWidget {
  const _OriginCharacterRow({required this.character, required this.imageUrls});

  final OriginCharacter character;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final identity = _splitTags(character.tags).join(' · ');
    final tagline = character.tagline.trim();
    final description = character.description.trim();
    final goal = character.goal.trim();
    final avatarUrl = _resolveAssetUrl(character.avatar);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OriginCharacterPortrait(
          characterId: _characterStableId(character),
          url: avatarUrl,
          name: character.name,
          imageUrls: imageUrls,
        ),
        // Character row inner spacing: portrait -> text column.
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.name,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
              if (identity.isNotEmpty) ...[
                // Character text spacing: name -> identity.
                const SizedBox(height: 5),
                Text(
                  identity,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
              if (tagline.isNotEmpty) ...[
                // Character text spacing: previous short line -> tagline.
                const SizedBox(height: 5),
                Text(
                  tagline,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFF42C47),
                  ),
                ),
              ],
              if (description.isNotEmpty) ...[
                // Character text spacing: previous line -> description.
                const SizedBox(height: 9),
                Text(description, style: _bodyTextStyle),
              ],
              if (goal.isNotEmpty) ...[
                // Character text spacing: description/previous line -> goal.
                const SizedBox(height: 9),
                Text('Goal: $goal', style: _bodyTextStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginCharacterPortrait extends StatefulWidget {
  const _OriginCharacterPortrait({
    required this.characterId,
    required this.url,
    required this.name,
    required this.imageUrls,
  });

  static const double _width = 86;
  static const double _borderRadius = GenesisAvatarRadii.character;
  static const double _starSize = 22;

  final String characterId;
  final String url;
  final String name;
  final List<String> imageUrls;

  @override
  State<_OriginCharacterPortrait> createState() =>
      _OriginCharacterPortraitState();
}

class _OriginCharacterPortraitState extends State<_OriginCharacterPortrait> {
  late bool _hasVisiblePortrait;

  @override
  void initState() {
    super.initState();
    _hasVisiblePortrait = !_shouldWaitForNetworkPortrait(widget.url);
  }

  @override
  void didUpdateWidget(covariant _OriginCharacterPortrait oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _hasVisiblePortrait = !_shouldWaitForNetworkPortrait(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = selectGenesisImageUrl(
      widget.url,
      logicalWidth: _OriginCharacterPortrait._width,
      logicalHeight: _OriginCharacterPortrait._width,
      devicePixelRatio: MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1,
    ).trim();
    final fallback = GenesisAvatarFallback(
      name: widget.name,
      width: _OriginCharacterPortrait._width,
      height: _OriginCharacterPortrait._width,
      borderRadius: _OriginCharacterPortrait._borderRadius,
    );
    final waitsForNetworkPortrait =
        resolvedUrl.isNotEmpty && !resolvedUrl.startsWith('assets/');
    final image = resolvedUrl.isEmpty
        ? fallback
        : resolvedUrl.startsWith('assets/')
        ? Image.asset(
            resolvedUrl,
            width: _OriginCharacterPortrait._width,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) {
                _updatePortraitVisibility(true);
              }
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              _updatePortraitVisibility(true);
              return fallback;
            },
          )
        : CachedNetworkImage(
            imageUrl: resolvedUrl,
            width: _OriginCharacterPortrait._width,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholderFadeInDuration: Duration.zero,
            imageBuilder: (context, imageProvider) {
              _updatePortraitVisibility(true);
              return Image(
                image: imageProvider,
                width: _OriginCharacterPortrait._width,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              );
            },
            placeholder: (context, url) {
              _updatePortraitVisibility(false);
              return const SizedBox(
                width: _OriginCharacterPortrait._width,
                height: _OriginCharacterPortrait._width,
              );
            },
            errorWidget: (context, url, error) {
              _updatePortraitVisibility(true);
              return fallback;
            },
          );

    final portraitImage = SizedBox(
      width: _OriginCharacterPortrait._width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          _OriginCharacterPortrait._borderRadius,
        ),
        child: image,
      ),
    );
    final initialIndex = widget.imageUrls.indexOf(widget.url.trim());
    final portrait = Stack(
      clipBehavior: Clip.none,
      children: [
        portraitImage,
        if (!waitsForNetworkPortrait || _hasVisiblePortrait)
          Positioned(
            top: -_OriginCharacterPortrait._starSize / 4 - 2,
            right: -_OriginCharacterPortrait._starSize / 4 - 3,
            child: Icon(
              MyFlutterApp.redstarCharIcon,
              size: _OriginCharacterPortrait._starSize,
              color: const Color(0xFFF42C47),
            ),
          ),
      ],
    );
    if (resolvedUrl.isEmpty) return portrait;
    return GestureDetector(
      key: ValueKey('origin-character-portrait-${widget.characterId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showGenesisImageViewer(
        context,
        imageUrls: widget.imageUrls,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
      ),
      child: portrait,
    );
  }

  bool _shouldWaitForNetworkPortrait(String url) {
    final trimmed = url.trim();
    return trimmed.isNotEmpty && !trimmed.startsWith('assets/');
  }

  void _updatePortraitVisibility(bool isVisible) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasVisiblePortrait == isVisible) return;
      setState(() {
        _hasVisiblePortrait = isVisible;
      });
    });
  }
}

String _characterStableId(OriginCharacter character) {
  final explicitId = character.characterId.trim();
  if (explicitId.isNotEmpty) return explicitId;
  if (character.id > 0) return '${character.id}';
  return character.name.trim();
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    this.icon,
    this.iconAsset,
    this.iconColor,
    required this.title,
  }) : assert(icon != null || iconAsset != null);

  final IconData? icon;
  final String? iconAsset;
  final Color? iconColor;
  final String title;

  @override
  Widget build(BuildContext context) {
    final asset = iconAsset;
    final isCharacterIcon = asset == characterStatIconAsset;
    const assetSize = 16.0;
    return Row(
      children: [
        if (asset case final asset?)
          Transform.translate(
            offset: Offset(0, isCharacterIcon ? -1.2 : 0),
            child: asset.endsWith('.svg')
                ? SvgPicture.asset(
                    asset,
                    width: assetSize,
                    height: assetSize,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  )
                : Image.asset(
                    asset,
                    width: assetSize,
                    height: assetSize,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
          )
        else
          Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }
}

const _bodyTextStyle = TextStyle(
  fontSize: 12,
  height: 1.45,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
);

const _mutedBodyTextStyle = TextStyle(
  fontSize: 12,
  height: 1.3,
  fontWeight: FontWeight.w500,
  color: Color(0xFF999999),
);

const _copyWorldProgressMetaStyle = TextStyle(
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
  color: Color(0xFF8C8C8C),
);

List<String> _splitTags(String tags) {
  if (tags.trim().isEmpty) return const [];
  return tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _resolveAssetUrl(String raw) {
  return resolveAssetUrl(raw);
}

String _resolvedProfileAvatar(
  Map<String, dynamic> userInfo,
  String profileAvatar,
) {
  final resolved = asResolvedImageUrl(
    _mapValue(userInfo, const ['avatar']),
    resolveAssetUrl,
    fallback: _mapValue(userInfo, const [
      'avatar_url',
      'photoUrl',
      'photo_url',
      'picture',
    ]),
  );
  if (resolved.isNotEmpty) return resolved;
  return asResolvedImageUrl(profileAvatar, resolveAssetUrl);
}

Object? _mapValue(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return value;
  }
  return null;
}

String _mapString(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = '$value'.trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic>? _originPreviewTick(OriginDetail origin) {
  final tick = _originTick1(origin);
  if (tick == null) return null;
  final result = tick['tick_result'] is Map
      ? (tick['tick_result'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};
  final narrator = _mapString(result, const ['narrator']);
  final paragraphsRaw = result['paragraphs'];
  final paragraphs = paragraphsRaw is List
      ? paragraphsRaw
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .where(_originPreviewParagraphHasText)
            .toList(growable: false)
      : const <Map<String, dynamic>>[];

  return <String, dynamic>{
    'created_at': tick['created_at'] ?? origin.updatedAt,
    'tick_result': <String, dynamic>{
      'narrator': narrator,
      'paragraphs': paragraphs,
    },
  };
}

Map<String, dynamic>? _originTick1(OriginDetail origin) {
  for (final tick in origin.ticks) {
    if (_mapInt(tick, const ['tick_no']) == 1) return tick;
  }
  return null;
}

bool _originPreviewParagraphHasText(Map<String, dynamic> paragraph) {
  return _mapString(paragraph, const [
    'text',
    'content',
    'summary',
    'paragraph',
  ]).isNotEmpty;
}

Map<String, Map<String, dynamic>> _originLocationsById(
  List<OriginLocation> locations,
) {
  final out = <String, Map<String, dynamic>>{};
  for (final location in locations) {
    final locationId = location.locationId.trim();
    if (locationId.isEmpty) continue;
    out[locationId] = <String, dynamic>{
      'location_name': location.name,
      'name': location.name,
    };
  }
  return out;
}

int _mapInt(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

String _formatSummaryTimestamp(int seconds) {
  if (seconds <= 0) return '';
  return formatGenesisTimestamp(seconds);
}

List<OriginLocation> _rootOriginLocations(List<OriginLocation> locations) {
  return locations
      .where((location) => location.parentLocationId.trim().isEmpty)
      .toList(growable: false);
}

List<WorldMapLocationNode> _originMapLocationNodes(
  List<LocationTreeNode<OriginLocation>> nodes,
  Map<String, List<UserAvatar>> avatarsByLocation,
  ProcessedLocationTree<OriginLocation> processedLocationTree,
) {
  return nodes
      .map((node) {
        return WorldMapLocationNode(
          id: node.id,
          isRoot:
              node.id == processedLocationTree.root?.id &&
              node.children.isNotEmpty,
          point: _pointsFromLocations(
            [node.value],
            avatarsByLocation,
            depths: [node.depth],
            isLeafLocations: [node.children.isEmpty],
            usersByIndex: [
              processedLocationTree.aggregateValues<UserAvatar>(
                node.id,
                avatarsByLocation,
                idOf: _userAvatarStableId,
              ),
            ],
          ).first,
          mapImageUrl: _resolveAssetUrl(node.value.mapUrl),
          children: _originMapLocationNodes(
            node.children,
            avatarsByLocation,
            processedLocationTree,
          ),
        );
      })
      .toList(growable: false);
}

String _originRootMapImageUrl(List<LocationTreeNode<OriginLocation>> nodes) {
  for (final node in nodes) {
    final url = _resolveAssetUrl(node.value.mapUrl);
    if (url.isNotEmpty) return url;
  }
  return '';
}

List<WorldPoint> _pointsFromLocations(
  List<OriginLocation> locations,
  Map<String, List<UserAvatar>> avatarsByLocation, {
  List<int>? depths,
  List<bool>? isLeafLocations,
  List<List<UserAvatar>>? usersByIndex,
}) {
  if (locations.isEmpty) return const <WorldPoint>[];

  return List<WorldPoint>.generate(locations.length, (i) {
    final l = locations[i];
    final locationId = l.locationId.trim().isEmpty
        ? '${l.id}'
        : l.locationId.trim();
    final rawDx = l.xPercent > 0 ? (l.xPercent / 100) : null;
    final rawDy = l.yPercent > 0 ? (l.yPercent / 100) : null;
    final col = i % 3;
    final row = i ~/ 3;
    final dx = rawDx ?? (0.18 + col * 0.30);
    final dy = rawDy ?? (0.22 + row * 0.22);
    final type = switch (i % 5) {
      0 => WorldPointType.castle,
      1 => WorldPointType.shop,
      2 => WorldPointType.portal,
      3 => WorldPointType.tavern,
      _ => WorldPointType.camp,
    };
    return WorldPoint(
      id: '${l.id}',
      name: l.name,
      type: type,
      position: Offset(
        dx.clamp(0.0, 1.0).toDouble(),
        dy.clamp(0.0, 1.0).toDouble(),
      ),
      users: usersByIndex == null || i >= usersByIndex.length
          ? (avatarsByLocation[locationId] ??
                avatarsByLocation['${l.id}'] ??
                const <UserAvatar>[])
          : usersByIndex[i],
      sceneId: locationId,
      pointId: locationId,
      iconUrl: _resolveAssetUrl(l.icon),
      description: l.description,
      depth: depths == null || i >= depths.length ? 0 : depths[i],
      isLeafLocation: isLeafLocations == null || i >= isLeafLocations.length
          ? true
          : isLeafLocations[i],
    );
  });
}

Map<String, List<UserAvatar>> _originAvatarsByLocation(
  List<OriginCharacter> characters,
  List<OriginLocation> locations,
) {
  final map = <String, List<UserAvatar>>{};
  final locationIdsByStableId = <int, List<String>>{};
  for (final location in locations) {
    locationIdsByStableId
        .putIfAbsent(location.id, () => <String>[])
        .add(location.locationId.trim());
  }

  for (final c in characters) {
    final locationId = c.currentLocationId > 0
        ? c.currentLocationId
        : c.initialLocationId;
    if (locationId <= 0) continue;
    final avatar = UserAvatar(
      _initials(c.name),
      id: '${c.id}',
      name: c.name,
      avatarUrl: _resolveAssetUrl(c.avatar),
      showStar: true,
    );
    final keys = <String>{'$locationId', ...?locationIdsByStableId[locationId]}
      ..remove('');
    for (final key in keys) {
      (map[key] ??= <UserAvatar>[]).add(avatar);
    }
  }
  return map;
}

String _userAvatarStableId(UserAvatar avatar) {
  final id = avatar.id.trim();
  if (id.isNotEmpty) return id;
  return '${avatar.name ?? ''}|${avatar.avatarUrl}|${avatar.initials}';
}

String _initials(String name) {
  return initialsForAvatarName(name);
}
