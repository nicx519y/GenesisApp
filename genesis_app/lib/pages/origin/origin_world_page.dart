import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/auth/login_guard.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/chat/shared/location_chat_overlay_transition.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/discuss/story_badge.dart';
import '../../components/login_sheet.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/world_map.dart';
import '../../components/world_tick1_wait_dialog.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/origin.dart';
import '../../platform/auth/auth_session.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_edge_swipe_back.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_safe_area.dart';
import '../../ui/components/genesis_search_field.dart';
import '../../ui/theme/genesis_ui_theme.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../chat/location_chat_page.dart';
import '../world/world_header.dart';
import 'origin_launch_coordinator.dart';
import 'origin_launch_flow.dart';

class OriginWorldPage extends StatefulWidget {
  const OriginWorldPage({super.key, required this.oid, required this.originId});

  final String oid;
  final int originId;

  @override
  State<OriginWorldPage> createState() => _OriginWorldPageState();
}

class _OriginWorldPageState extends State<OriginWorldPage> {
  static const SystemUiOverlayStyle _transparentStatusBarStyle =
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      );
  static const double _mapPanelTopGap = 50;
  static const double _mapLoadingCollapsedHeightOffset = 100;
  static const double _mapLoadedCollapsedHeightOffset = 60;
  static const double _mapDefaultExposedChildSize = 0.31;

  final OriginLaunchCoordinator _launchCoordinator =
      OriginLaunchCoordinator.instance;
  Future<OriginDetail>? _future;
  bool _launching = false;
  bool _didResumePendingLaunch = false;
  bool _showLocationPage = false;
  _OriginLocationChatDescriptor? _activeChatLocation;
  late final VoidCallback _removeLaunchOutcomeListener;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_transparentStatusBarStyle);
    _launchCoordinator.state.addListener(_syncLaunchState);
    _removeLaunchOutcomeListener = _launchCoordinator.addOutcomeListener(
      _handleLaunchOutcome,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _loadOriginDetail();
    if (!_didResumePendingLaunch) {
      _didResumePendingLaunch = true;
      _resumePendingLaunch();
    }
  }

  @override
  void didUpdateWidget(covariant OriginWorldPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oid != widget.oid) {
      _future = _loadOriginDetail();
      _activeChatLocation = null;
      _showLocationPage = false;
      _didResumePendingLaunch = false;
      _syncLaunchState();
      _resumePendingLaunch();
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
    _launchCoordinator.state.removeListener(_syncLaunchState);
    _removeLaunchOutcomeListener();
    super.dispose();
  }

  Future<OriginDetail> _loadOriginDetail() async {
    final api = AppServicesScope.read(context).api;
    final origin = await api.getOrigin(widget.oid);
    return origin;
  }

  void _resumePendingLaunch() {
    final api = AppServicesScope.read(context).api;
    unawaited(
      _launchCoordinator.ensurePolling(
        originId: widget.oid,
        loadWorld: api.getWorld,
        context: context,
      ),
    );
    _syncLaunchState();
  }

  void _syncLaunchState() {
    if (!mounted) return;
    final launching = _launchCoordinator.isLaunchingOrigin(widget.oid);
    if (_launching != launching) {
      setState(() => _launching = launching);
    }
  }

  void _handleLaunchOutcome(OriginLaunchOutcome outcome) {
    if (!mounted || outcome.originId != widget.oid) return;
    _syncLaunchState();
  }

  void _handleLaunchWaitBack() {
    if (_activeChatLocation != null) {
      setState(() => _activeChatLocation = null);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) navigator.pop();
      });
    });
  }

  void _openChatForPoint(OriginDetail origin, WorldPoint point) {
    final pointId = point.pointId.trim().isNotEmpty
        ? point.pointId.trim()
        : point.id.trim();
    final locationId = point.sceneId.trim().isNotEmpty
        ? point.sceneId.trim()
        : pointId;
    if (locationId.isEmpty) return;
    final openingPreviewMessages = _originLocationOpeningPreviewMessages(
      origin,
      [locationId, pointId, point.id],
    );
    final openingPreviewEntities = _originLocationOpeningPreviewEntities(
      origin.characters,
      openingPreviewMessages,
      locationId,
    );
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'worldo_map',
      object1: origin.oid,
      object2: locationId,
    );
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'worldo_location_chat',
      object1: origin.oid,
      object2: locationId,
    );

    setState(() {
      _activeChatLocation = _OriginLocationChatDescriptor(
        originId: origin.oid,
        locationId: locationId,
        locationName: point.name,
        backgroundImageUrl: point.iconUrl.trim().isNotEmpty
            ? point.iconUrl
            : point.mapImageUrl,
        backgroundPreviewImageUrl: '',
        isLeafLocation: point.isLeafLocation,
        openingPreviewMessages: openingPreviewMessages,
        openingPreviewEntities: openingPreviewEntities,
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

  Widget _buildLocationChatOverlay(OriginDetail origin) {
    final descriptor = _activeChatLocation;
    return Positioned.fill(
      child: LocationChatOverlayTransition(
        active: descriptor != null,
        child: descriptor == null
            ? null
            : GenesisEdgeSwipeBack(
                onBack: _closeLocationChat,
                child: LocationChatPanel(
                  key: ValueKey(
                    'origin-location-chat-${descriptor.locationId}',
                  ),
                  worldId: descriptor.originId,
                  locationId: descriptor.locationId,
                  locationName: descriptor.locationName,
                  backgroundImageUrl: descriptor.backgroundImageUrl,
                  backgroundPreviewImageUrl:
                      descriptor.backgroundPreviewImageUrl,
                  openingPreviewMessages: descriptor.openingPreviewMessages,
                  openingPreviewEntities: descriptor.openingPreviewEntities,
                  isLeafLocation: descriptor.isLeafLocation,
                  active: false,
                  leaveOnInactive: false,
                  showMoreButton: false,
                  onBack: _closeLocationChat,
                  composerReplacement: _OriginLocationChatLaunchBar(
                    launching: _launching,
                    onLaunch: () => _showLaunchRoleSheet(origin),
                  ),
                ),
              ),
      ),
    );
  }

  void _handleMapTitleTap() {
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'worldo_map',
      object1: widget.oid,
    );
    if (!_showLocationPage) return;
    setState(() => _showLocationPage = false);
  }

  void _handleLocationTitleTap() {
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'worldo_detail_location_list',
      object1: widget.oid,
    );
    if (_showLocationPage) return;
    setState(() => _showLocationPage = true);
  }

  Widget _buildPersistentMapOverlay(double top, {int locationCount = 0}) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned(
                left: 12,
                top: top + 6,
                child: WorldMapBackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                left: 60,
                right: 12,
                top: top + 6,
                child: _OriginMapTabsPill(
                  locationCount: locationCount,
                  selectedIndex: _showLocationPage ? 1 : 0,
                  onMapTap: _handleMapTitleTap,
                  onLocationTap: _handleLocationTitleTap,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showLaunchRoleSheet(OriginDetail origin) async {
    if (_launching) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'launch_sheet',
      object1: origin.oid,
    );
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
    final started = await startOriginLaunch(
      context: context,
      origin: origin,
      roleSelection: roleSelection,
    );
    if (!mounted) return;
    if (!started) {
      setState(() => _launching = false);
      return;
    }
    _syncLaunchState();
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
    final topPadding = GenesisSafeAreaInsets.top(context);
    final content = _buildPageContent(context, topPadding);
    return Stack(
      children: [
        content,
        if (_launching)
          Positioned.fill(
            child: _OriginPendingLaunchWaitOverlay(
              onBackPressed: _handleLaunchWaitBack,
            ),
          ),
      ],
    );
  }

  Widget _buildPageContent(BuildContext context, double topPadding) {
    return FutureBuilder<OriginDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildMapOnlyScaffold(
            topPadding: topPadding,
            panelCollapsedHeightOffset: _mapLoadingCollapsedHeightOffset,
            mapOverlay: _buildPersistentMapOverlay(topPadding),
            map: WorldKeepAlivePage(
              child: WorldMap(
                key: PageStorageKey<String>('origin-map-loading-${widget.oid}'),
                points: const <WorldPoint>[],
                listPoints: const <WorldPoint>[],
                locationNodes: const <WorldMapLocationNode>[],
                fallbackOnEmptyMapUrl: false,
                dimmed: false,
                showPointsList: false,
                pointsListOuterScrollHandoff: false,
                overlayTop: topPadding + 8 + 48,
                drillExitTop: topPadding + 68,
              ),
            ),
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
        final rootLocationNodes = processedLocationTree.initialMapDisplayRoots;
        final mapImageUrl = _originRootMapImageUrl(rootLocationNodes);
        final renderLocationNodes = processedLocationTree.initialMapRenderRoots;
        final allLocationNodes = processedLocationTree.flattened;
        final avatarsByLocation = _originAvatarsByLocation(
          origin.characters,
          origin.allLocations,
        );
        final locationNodes = _originMapLocationNodes(
          rootLocationNodes,
          avatarsByLocation,
          processedLocationTree,
          markAsMapRoot:
              rootLocationNodes.length == 1 &&
              rootLocationNodes.single.children.isNotEmpty,
        );
        final listLocationNodes = _originMapLocationNodes(
          processedLocationTree.mapRoots,
          avatarsByLocation,
          processedLocationTree,
          markAsMapRoot: false,
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
        final locationCount = listLocationNodes.isNotEmpty
            ? _originLeafLocationNodeCount(listLocationNodes)
            : listPoints.length;

        return PopScope(
          canPop: _activeChatLocation == null,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleOriginPopBlocked();
          },
          child: _buildMapOnlyScaffold(
            topPadding: topPadding,
            panelCollapsedHeightOffset: _mapLoadedCollapsedHeightOffset,
            mapOverlay: _buildPersistentMapOverlay(
              topPadding,
              locationCount: locationCount,
            ),
            topOverlay: _buildLocationChatOverlay(origin),
            map: WorldKeepAlivePage(
              child: WorldMap(
                key: PageStorageKey<String>('origin-map-${origin.oid}'),
                points: points,
                listPoints: listPoints,
                locationNodes: locationNodes,
                listLocationNodes: listLocationNodes,
                mapImageUrl: mapImageUrl,
                dimmed: _showLocationPage,
                showPointsList: _showLocationPage,
                pointsListOuterScrollHandoff: false,
                overlayTop: topPadding + 8 + 48,
                drillExitTop: topPadding + 68,
                onPointTap: (point) => _openChatForPoint(origin, point),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMapOnlyScaffold({
    required double topPadding,
    required double panelCollapsedHeightOffset,
    required Widget mapOverlay,
    required Widget map,
    Widget? topOverlay,
  }) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _transparentStatusBarStyle,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final mediaQuery = MediaQuery.of(context);
            final bottomSafeArea =
                mediaQuery.padding.bottom > mediaQuery.viewPadding.bottom
                ? mediaQuery.padding.bottom
                : mediaQuery.viewPadding.bottom;
            final maxMapHeight =
                (viewportHeight - _mapPanelTopGap - bottomSafeArea)
                    .clamp(0.0, viewportHeight)
                    .toDouble();
            final mapHeight =
                (viewportHeight * (1 - _mapDefaultExposedChildSize) +
                        panelCollapsedHeightOffset -
                        bottomSafeArea)
                    .clamp(0.0, maxMapHeight)
                    .toDouble();
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(height: mapHeight, child: map),
                ),
                mapOverlay,
                if (topOverlay != null) topOverlay,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OriginMapTabsPill extends StatelessWidget {
  const _OriginMapTabsPill({
    required this.locationCount,
    required this.selectedIndex,
    required this.onMapTap,
    required this.onLocationTap,
  });

  final int locationCount;
  final int selectedIndex;
  final VoidCallback onMapTap;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    final uiTheme = GenesisUiTheme.of(context);
    const height = genesisSearchFieldHeight;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMapTap,
            child: _OriginMapTabTitle(
              selected: selectedIndex == 0,
              icon: Icons.map_outlined,
              label: 'Map',
              labelStyle:
                  (selectedIndex == 0
                          ? uiTheme.bodyStrongStyle
                          : uiTheme.bodyStyle)
                      .copyWith(fontSize: 16),
              indicatorColor: uiTheme.tabIndicatorColor,
              indicatorWidth: uiTheme.tabIndicatorWidth,
              indicatorHeight: uiTheme.tabIndicatorHeight,
            ),
          ),
          const SizedBox(width: 24),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLocationTap,
            child: _OriginMapTabTitle(
              selected: selectedIndex == 1,
              icon: Icons.place_outlined,
              label: 'Location ($locationCount)',
              labelStyle:
                  (selectedIndex == 1
                          ? uiTheme.bodyStrongStyle
                          : uiTheme.bodyStyle)
                      .copyWith(fontSize: 16),
              indicatorColor: uiTheme.tabIndicatorColor,
              indicatorWidth: uiTheme.tabIndicatorWidth,
              indicatorHeight: uiTheme.tabIndicatorHeight,
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginMapTabTitle extends StatelessWidget {
  const _OriginMapTabTitle({
    required this.selected,
    required this.icon,
    required this.label,
    required this.labelStyle,
    required this.indicatorColor,
    required this.indicatorWidth,
    required this.indicatorHeight,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final TextStyle labelStyle;
  final Color indicatorColor;
  final double indicatorWidth;
  final double indicatorHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: genesisSearchFieldHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: const Color(0xFF111111)),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle.copyWith(color: const Color(0xFF111111)),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              left: 12,
              right: 12,
              bottom: 3,
              child: Center(
                child: Container(
                  width: indicatorWidth,
                  height: indicatorHeight,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    borderRadius: BorderRadius.circular(indicatorHeight / 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OriginLocationChatDescriptor {
  const _OriginLocationChatDescriptor({
    required this.originId,
    required this.locationId,
    required this.locationName,
    required this.backgroundImageUrl,
    required this.backgroundPreviewImageUrl,
    required this.isLeafLocation,
    required this.openingPreviewMessages,
    required this.openingPreviewEntities,
  });

  final String originId;
  final String locationId;
  final String locationName;
  final String backgroundImageUrl;
  final String backgroundPreviewImageUrl;
  final bool isLeafLocation;
  final List<WorldChatroomMessage> openingPreviewMessages;
  final List<WorldChatroomEntity> openingPreviewEntities;
}

class _OriginPendingLaunchWaitOverlay extends StatefulWidget {
  const _OriginPendingLaunchWaitOverlay({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  State<_OriginPendingLaunchWaitOverlay> createState() =>
      _OriginPendingLaunchWaitOverlayState();
}

class _OriginPendingLaunchWaitOverlayState
    extends State<_OriginPendingLaunchWaitOverlay> {
  Timer? _dotsTimer;
  int _dotCount = 1;
  bool _allowRoutePop = false;

  @override
  void initState() {
    super.initState();
    _dotsTimer = Timer.periodic(kWorldTick1WaitDotsInterval, (_) {
      if (!mounted) return;
      setState(() => _dotCount = _dotCount == 6 ? 1 : _dotCount + 1);
    });
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackRequest();
      },
      child: GenesisEdgeSwipeBack(
        onBack: _handleBackRequest,
        child: ColoredBox(
          color: const Color(0x8A000000),
          child: Center(
            child: AlertDialog(
              key: const ValueKey('world-tick1-wait-dialog'),
              backgroundColor: const Color(0xFFFFFFFF),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              title: Text(
                'AI is generating${List.filled(_dotCount, '.').join()}',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: 260,
                child: const Text(
                  'Generate  a live and customized world for you.\n'
                  'Please wait for a moment.',
                  style: TextStyle(fontSize: 14, height: 1.35),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackRequest() {
    if (!_allowRoutePop && mounted) {
      setState(() => _allowRoutePop = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onBackPressed();
      });
    });
  }
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
    final style = kLocationChatStyle;
    final bottomInset = GenesisSafeAreaInsets.bottom(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.composerBackdropBlurSigma,
          sigmaY: style.composerBackdropBlurSigma,
        ),
        child: Container(
          padding: style.composerPadding.copyWith(
            bottom: style.composerPadding.bottom + bottomInset,
          ),
          decoration: BoxDecoration(
            color: style.composerBackgroundGradient == null
                ? style.composerBackgroundColor
                : null,
            gradient: style.composerBackgroundGradient,
          ),
          child: Center(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.7,
              child: GenesisPrimaryButton(
                label: launching ? 'Launching...' : 'Launch to send',
                onPressed: launching ? null : onLaunch,
                height: style.inputMinHeight,
                borderRadius: BorderRadius.circular(
                  style.systemMessageBorderRadius,
                ),
              ),
            ),
          ),
        ),
      ),
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
  var _didLoadSummaries = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadSummaries) return;
    _didLoadSummaries = true;
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
        const _SectionTitle(title: 'Copy World Progress'),
        const SizedBox(height: 8),
        _CopyWorldProgressCard(summary: summary),
      ],
    );
  }
}

class _CopyWorldProgressCard extends StatelessWidget {
  const _CopyWorldProgressCard({required this.summary});

  static const double _bodyFontSize = 13;
  static const double _bodyLineHeight = 1.45;
  static const double _bodyHeight = _bodyFontSize * _bodyLineHeight * 5 + 6;
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
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.deleted
          ? null
          : () => Navigator.of(
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
                style: const TextStyle(
                  fontSize: _bodyFontSize,
                  height: _bodyLineHeight,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111111),
                ),
              ),
            ),
          ),
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
    if (item == null) return const SizedBox(height: 18);
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
                      'WID: ${deletedAwareIdLabel(item.worldId, deleted: item.deleted)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DiscussStoryBadge(count: item.tickNo),
                ],
              ),
            ),
            if (hasTimestamp) ...[
              const SizedBox(width: gap),
              SizedBox(
                width: timeWidth,
                child: Text(
                  timestamp,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8C8C8C),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.history, size: 14, color: Color(0xFFFF2442)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111111),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatSummaryTimestamp(int seconds) {
  if (seconds <= 0) return '';
  return formatGenesisTimestamp(seconds);
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

List<WorldChatroomMessage> _originLocationOpeningPreviewMessages(
  OriginDetail origin,
  Iterable<String> locationIds,
) {
  return originLocationOpeningPreviewMessagesForTesting(
    origin.ticks,
    locationIds,
  );
}

@visibleForTesting
List<WorldChatroomMessage> originLocationOpeningPreviewMessagesForTesting(
  List<Map<String, dynamic>> ticks,
  Iterable<String> locationIds,
) {
  final locationIdSet = locationIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  if (locationIdSet.isEmpty) return const <WorldChatroomMessage>[];

  final orderedTicks = ticks.toList(growable: false);
  orderedTicks.sort((left, right) {
    final leftTickNo = _mapInt(left, const ['tick_no']);
    final rightTickNo = _mapInt(right, const ['tick_no']);
    if (leftTickNo == 1 && rightTickNo != 1) return -1;
    if (rightTickNo == 1 && leftTickNo != 1) return 1;
    if (leftTickNo != 0 && rightTickNo != 0 && leftTickNo != rightTickNo) {
      return leftTickNo.compareTo(rightTickNo);
    }
    return 0;
  });

  for (final tick in orderedTicks) {
    final tickNo = _mapInt(tick, const ['tick_no']);
    final createdAt = asDateTime(tick['created_at']);
    final result = tick['tick_result'] is Map
        ? (tick['tick_result'] as Map).cast<String, dynamic>()
        : tick;
    final resultCurrentTime = _mapString(result, const [
      'current_time',
      'time',
    ]);
    final currentTime = resultCurrentTime.isNotEmpty
        ? resultCurrentTime
        : _mapString(tick, const ['current_time', 'time']);
    final groupsRaw = result['location_groups'] ?? tick['location_groups'];
    if (groupsRaw is! List) continue;
    for (final rawGroup in groupsRaw.whereType<Map>()) {
      final group = rawGroup.cast<String, dynamic>();
      final groupLocationId = _mapString(group, const [
        'location_id',
        'loc_id',
        'id',
      ]);
      if (!locationIdSet.contains(groupLocationId)) continue;
      final dialogueRaw =
          group['initial_dialogue'] ??
          group['initialDialogue'] ??
          group['dialogue'];
      if (dialogueRaw is! List) continue;
      final messages = <WorldChatroomMessage>[];
      if (tickNo > 0 || currentTime.isNotEmpty) {
        messages.add(
          WorldChatroomMessage(
            messageId: 0,
            conversationRoundId:
                'opening-preview-tick-${tickNo == 0 ? 1 : tickNo}',
            roundOrder: 0,
            tickNo: tickNo == 0 ? 1 : tickNo,
            locationId: groupLocationId,
            senderType: 'tick',
            senderId: 'tick',
            senderName: 'Time',
            content: currentTime,
            createdAt: createdAt,
          ),
        );
      }
      messages.addAll(
        dialogueRaw
            .whereType<Map>()
            .indexed
            .map((entry) {
              final index = entry.$1;
              final line = entry.$2.cast<String, dynamic>();
              final content = _mapString(line, const ['content', 'text']);
              if (content.isEmpty) return null;
              final charId = _mapString(line, const [
                'char_id',
                'character_id',
                'sender_id',
              ]);
              final charName = _mapString(line, const [
                'char_name',
                'name',
                'sender_name',
              ]);
              final senderId = charId.isEmpty
                  ? 'opening-preview-$index'
                  : charId;
              final senderName = charName.isEmpty ? senderId : charName;
              final isNarrator =
                  charId.trim().toLowerCase() == 'nar' &&
                  charName.trim().toLowerCase() == 'narrator';
              return WorldChatroomMessage(
                messageId: 0,
                conversationRoundId: 'opening-preview-$index',
                roundOrder: index,
                tickNo: tickNo == 0 ? 1 : tickNo,
                locationId: groupLocationId,
                senderType: isNarrator ? 'narrator' : 'character',
                senderId: senderId,
                senderName: senderName,
                currentTime: currentTime,
                content: content,
                createdAt:
                    createdAt ?? DateTime.fromMillisecondsSinceEpoch(index),
              );
            })
            .whereType<WorldChatroomMessage>()
            .toList(growable: false),
      );
      return messages;
    }
  }
  return const <WorldChatroomMessage>[];
}

List<WorldChatroomEntity> _originLocationOpeningPreviewEntities(
  List<OriginCharacter> characters,
  List<WorldChatroomMessage> messages,
  String locationId,
) {
  return originLocationOpeningPreviewEntitiesForTesting(
    characters,
    messages,
    locationId,
  );
}

@visibleForTesting
List<WorldChatroomEntity> originLocationOpeningPreviewEntitiesForTesting(
  List<OriginCharacter> characters,
  List<WorldChatroomMessage> messages,
  String locationId,
) {
  final charactersByKey = <String, OriginCharacter>{};
  for (final character in characters) {
    void addKey(String value) {
      final key = value.trim().toLowerCase();
      if (key.isEmpty) return;
      charactersByKey.putIfAbsent(key, () => character);
    }

    addKey(character.characterId);
    if (character.id > 0) addKey('${character.id}');
    addKey(character.name);
  }

  final entities = <WorldChatroomEntity>[];
  final seen = <String>{};
  for (final message in messages) {
    final senderId = message.senderId.trim();
    if (senderId.isEmpty || !seen.add(senderId.toLowerCase())) continue;
    final character =
        charactersByKey[senderId.toLowerCase()] ??
        charactersByKey[message.senderName.trim().toLowerCase()];
    if (character == null) continue;
    entities.add(
      WorldChatroomEntity(
        id: senderId,
        name: message.senderName.trim().isNotEmpty
            ? message.senderName.trim()
            : character.name,
        avatarUrl: _resolveAssetUrl(character.avatar),
        type: WorldChatroomEntityType.character,
        locationId: locationId,
        isAi: true,
      ),
    );
  }
  return entities;
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

List<OriginLocation> _rootOriginLocations(List<OriginLocation> locations) {
  return locations
      .where((location) => location.parentLocationId.trim().isEmpty)
      .toList(growable: false);
}

List<WorldMapLocationNode> _originMapLocationNodes(
  List<LocationTreeNode<OriginLocation>> nodes,
  Map<String, List<UserAvatar>> avatarsByLocation,
  ProcessedLocationTree<OriginLocation> processedLocationTree, {
  bool markAsMapRoot = true,
}) {
  return nodes
      .map((node) {
        return WorldMapLocationNode(
          id: node.id,
          isRoot: markAsMapRoot && node.children.isNotEmpty,
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
            markAsMapRoot: false,
          ),
        );
      })
      .toList(growable: false);
}

int _originLeafLocationNodeCount(List<WorldMapLocationNode> nodes) {
  var count = 0;
  for (final node in nodes) {
    if (node.children.isEmpty) {
      count += 1;
    } else {
      count += _originLeafLocationNodeCount(node.children);
    }
  }
  return count;
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
      mapImageUrl: _resolveAssetUrl(l.mapUrl),
      description: l.description,
      locationDescription: l.description,
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
