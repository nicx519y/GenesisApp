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
import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
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
  static const SystemUiOverlayStyle _transparentDarkStatusBarStyle =
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
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

  SystemUiOverlayStyle get _baseStatusBarStyle => _showLocationPage
      ? _transparentDarkStatusBarStyle
      : _transparentStatusBarStyle;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_baseStatusBarStyle);
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
      SystemChrome.setSystemUIOverlayStyle(_baseStatusBarStyle);
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

  void _refreshOriginDetail() {
    setState(() {
      _future = _loadOriginDetail();
    });
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
    SystemChrome.setSystemUIOverlayStyle(_transparentStatusBarStyle);
  }

  void _handleLocationTitleTap() {
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'worldo_detail_location_list',
      object1: widget.oid,
    );
    if (_showLocationPage) return;
    setState(() => _showLocationPage = true);
    SystemChrome.setSystemUIOverlayStyle(_transparentDarkStatusBarStyle);
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
            bottomSheetOverlayBuilder: (minChildSize) =>
                _OriginDetailDraggableSheet(
                  origin: origin,
                  baseStatusBarStyle: _baseStatusBarStyle,
                  minChildSize: minChildSize,
                  onOriginChanged: _refreshOriginDetail,
                ),
            bottomOverlay: _OriginBottomLaunchBar(
              origin: origin,
              launching: _launching,
              onLaunch: () => _showLaunchRoleSheet(origin),
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
    Widget Function(double minChildSize)? bottomSheetOverlayBuilder,
    Widget? bottomOverlay,
    Widget? topOverlay,
  }) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _baseStatusBarStyle,
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
            final bottomOverlayHeight = bottomOverlay == null
                ? 0.0
                : _OriginBottomLaunchBar.heightFor(context);
            final sheetHostHeight = (viewportHeight - bottomOverlayHeight)
                .clamp(0.0, viewportHeight)
                .toDouble();
            final sheetMinChildSize = sheetHostHeight <= 0
                ? _OriginDetailDraggableSheet.defaultInitialChildSize
                : ((sheetHostHeight - mapHeight) / sheetHostHeight)
                      .clamp(0.08, 0.42)
                      .toDouble();
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(height: mapHeight, child: map),
                ),
                mapOverlay,
                if (bottomSheetOverlayBuilder != null)
                  Positioned.fill(
                    bottom: bottomOverlayHeight,
                    child: bottomSheetOverlayBuilder(sheetMinChildSize),
                  ),
                if (bottomOverlay != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: bottomOverlay,
                  ),
                if (topOverlay != null) topOverlay,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OriginBottomLaunchBar extends StatelessWidget {
  const _OriginBottomLaunchBar({
    required this.origin,
    required this.launching,
    required this.onLaunch,
  });

  static double heightFor(BuildContext context) {
    return 56 + GenesisSafeAreaInsets.bottom(context);
  }

  final OriginDetail origin;
  final bool launching;
  final VoidCallback onLaunch;

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
                          icon: Icons.copy_rounded,
                          value: origin.copyCount,
                        ),
                        const SizedBox(width: 20),
                        _LaunchBarStat(
                          icon: Icons.hub_outlined,
                          value: origin.interactCount,
                        ),
                        const SizedBox(width: 20),
                        _LaunchBarStat(
                          icon: Icons.group_rounded,
                          value: origin.characterCount > 0
                              ? origin.characterCount
                              : origin.characters.length,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              GenesisPrimaryButton(
                label: 'Launch',
                onPressed: launching ? null : onLaunch,
                width: 140,
                height: 35,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                isLoading: launching,
                loadingSize: 22,
                loadingStrokeWidth: 2.4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaunchBarStat extends StatelessWidget {
  const _LaunchBarStat({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF111111)),
        const SizedBox(width: 4),
        Text(
          '$value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w400,
            color: Color(0xFF111111),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _OriginDetailDraggableSheet extends StatefulWidget {
  const _OriginDetailDraggableSheet({
    required this.origin,
    required this.baseStatusBarStyle,
    required this.minChildSize,
    required this.onOriginChanged,
  });

  static const double defaultInitialChildSize = 0.22;

  final OriginDetail origin;
  final SystemUiOverlayStyle baseStatusBarStyle;
  final double minChildSize;
  final VoidCallback onOriginChanged;

  @override
  State<_OriginDetailDraggableSheet> createState() =>
      _OriginDetailDraggableSheetState();
}

class _OriginDetailDraggableSheetState
    extends State<_OriginDetailDraggableSheet> {
  static const double _initialChildSize =
      _OriginDetailDraggableSheet.defaultInitialChildSize;
  static const double _maxChildSize = 1.0;
  static const double _extentUpdateEpsilon = 0.001;

  late final OriginDiscussListController _discussController;
  var _currentUid = '';
  var _didLoadCurrentUid = false;
  var _sheetExtent = _initialChildSize;

  double get _minChildSize => widget.minChildSize.clamp(0.08, 0.42).toDouble();

  double get _effectiveInitialChildSize =>
      _initialChildSize.clamp(_minChildSize, _maxChildSize).toDouble();

  @override
  void initState() {
    super.initState();
    _discussController = OriginDiscussListController();
    _configureDiscuss();
    unawaited(_discussController.loadInitialIfNeeded());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final initialExtent = _effectiveInitialChildSize;
    if (_sheetExtent < initialExtent) {
      _sheetExtent = initialExtent;
    }
    if (!_didLoadCurrentUid) {
      _didLoadCurrentUid = true;
      unawaited(_loadCurrentUid());
    }
  }

  @override
  void didUpdateWidget(covariant _OriginDetailDraggableSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origin.oid != widget.origin.oid) {
      _configureDiscuss();
      unawaited(_discussController.refreshFirstPage());
    }
    if (oldWidget.minChildSize != widget.minChildSize) {
      final nextExtent = _sheetExtent
          .clamp(_minChildSize, _maxChildSize)
          .toDouble();
      if (nextExtent != _sheetExtent) _sheetExtent = nextExtent;
    }
    if (oldWidget.baseStatusBarStyle != widget.baseStatusBarStyle) {
      SystemChrome.setSystemUIOverlayStyle(
        _statusBarStyleForExtent(context, _sheetExtent),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(widget.baseStatusBarStyle);
    _discussController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUid() async {
    final uid =
        (await AppServicesScope.of(context).sessionStore.readUid())?.trim() ??
        '';
    if (!mounted || uid == _currentUid) return;
    setState(() => _currentUid = uid);
  }

  void _configureDiscuss() {
    _discussController.configure(
      oid: widget.origin.oid,
      loader: ({required String oid, required int pn, required int rn}) async {
        return loadOriginDiscussPage(context, oid, pn: pn, rn: rn);
      },
    );
  }

  bool _handleSheetNotification(DraggableScrollableNotification notification) {
    final extent = notification.extent
        .clamp(_minChildSize, _maxChildSize)
        .toDouble();
    final extentChanged = (extent - _sheetExtent).abs() > _extentUpdateEpsilon;
    if (!extentChanged) return false;
    setState(() => _sheetExtent = extent);
    SystemChrome.setSystemUIOverlayStyle(
      _statusBarStyleForExtent(context, extent),
    );
    return false;
  }

  double _statusBarAlphaForExtent(BuildContext context, double extent) {
    final statusBarHeight = GenesisSafeAreaInsets.top(context);
    if (statusBarHeight <= 0) return extent >= _maxChildSize ? 1.0 : 0.0;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHostHeight =
        viewportHeight - _OriginBottomLaunchBar.heightFor(context);
    final sheetTop = sheetHostHeight * (1.0 - extent);
    return ((statusBarHeight - sheetTop) / statusBarHeight)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  SystemUiOverlayStyle _statusBarStyleForExtent(
    BuildContext context,
    double extent,
  ) {
    final alpha = _statusBarAlphaForExtent(context, extent);
    if (alpha <= 0.001) return widget.baseStatusBarStyle;
    final darkIcons = alpha >= 0.5;
    return widget.baseStatusBarStyle.copyWith(
      statusBarColor: Colors.white.withValues(alpha: alpha),
      statusBarIconBrightness: darkIcons
          ? Brightness.dark
          : widget.baseStatusBarStyle.statusBarIconBrightness,
      statusBarBrightness: darkIcons
          ? Brightness.light
          : widget.baseStatusBarStyle.statusBarBrightness,
    );
  }

  double _sheetTopProgress(BuildContext context) {
    final alpha = _statusBarAlphaForExtent(context, _sheetExtent);
    if (alpha > 0) return alpha;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHostHeight =
        viewportHeight - _OriginBottomLaunchBar.heightFor(context);
    final statusBarHeight = GenesisSafeAreaInsets.top(context);
    final sheetTop = sheetHostHeight * (1.0 - _sheetExtent);
    final transitionDistance = statusBarHeight <= 0 ? 1.0 : statusBarHeight;
    return ((transitionDistance - (sheetTop - statusBarHeight)) /
            transitionDistance)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final minChildSize = _minChildSize;
    final initialChildSize = _effectiveInitialChildSize;
    final topProgress = _sheetTopProgress(context);
    final topPadding =
        GenesisSafeAreaInsets.top(context) *
        _statusBarAlphaForExtent(context, _sheetExtent);
    final topRadius = 28.0 * (1.0 - topProgress);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _statusBarStyleForExtent(context, _sheetExtent),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: _handleSheetNotification,
        child: DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: _maxChildSize,
          snap: false,
          builder: (context, scrollController) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(topRadius),
                ),
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(overscroll: false),
                child: ListView(
                  controller: scrollController,
                  key: PageStorageKey<String>(
                    'origin-detail-bottom-sheet-${widget.origin.oid}',
                  ),
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(24, topPadding + 5, 24, 32),
                  children: [
                    const _OriginSheetDragHandle(),
                    const SizedBox(height: 10),
                    _OriginSheetHeaderContent(
                      origin: widget.origin,
                      currentUid: _currentUid,
                      onOriginChanged: widget.onOriginChanged,
                    ),
                    const SizedBox(height: 24),
                    _WorldViewSection(origin: widget.origin),
                    if (_originPreviewTick(widget.origin) case final tick?) ...[
                      const SizedBox(height: 24),
                      _LaunchPreviewSection(
                        origin: widget.origin,
                        previewTick: tick,
                      ),
                    ],
                    const SizedBox(height: 24),
                    CopyWorldProgressSection(originId: widget.origin.oid),
                    const SizedBox(height: 24),
                    _DiscussSection(
                      origin: widget.origin,
                      controller: _discussController,
                    ),
                    const SizedBox(height: 24),
                    _OriginCharactersSection(
                      characters: widget.origin.characters,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OriginSheetDragHandle extends StatelessWidget {
  const _OriginSheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Center(
        child: Container(
          width: 64,
          height: 5,
          decoration: BoxDecoration(
            color: const Color(0xFFD2D2D2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _OriginSheetHeaderContent extends StatelessWidget {
  const _OriginSheetHeaderContent({
    required this.origin,
    required this.currentUid,
    required this.onOriginChanged,
  });

  final OriginDetail origin;
  final String currentUid;
  final VoidCallback onOriginChanged;

  @override
  Widget build(BuildContext context) {
    final originator = origin.ownerDeleted
        ? deletedEntityDisplayText
        : origin.originator.trim().isEmpty
        ? '-'
        : origin.originator.trim();
    final ownerUid = origin.ownerUid.trim();
    final canEditOrigin =
        currentUid.trim().isNotEmpty && currentUid == ownerUid;
    final version = origin.versionNum <= 0 ? 1 : origin.versionNum;
    final age = formatGenesisTimestamp(
      origin.updatedAt?.millisecondsSinceEpoch == null
          ? 0
          : origin.updatedAt!.millisecondsSinceEpoch ~/ 1000,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          origin.name.trim().isEmpty ? origin.oid : origin.name.trim(),
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B6192),
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'OID: ${origin.deleted ? deletedEntityDisplayText : origin.oid}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: Color(0xFF666666),
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: ownerUid.isEmpty || origin.ownerDeleted
              ? null
              : () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.userInfo, arguments: {'uid': ownerUid}),
          child: Text(
            'Originator: $originator',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w400,
              color: Color(0xFF666666),
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Latest Version: V$version${age.isEmpty ? '' : ' · $age'}',
          style: const TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w400,
            color: Color(0xFF666666),
            decoration: TextDecoration.none,
          ),
        ),
        if (canEditOrigin) ...[
          const SizedBox(height: 8),
          GenesisPrimaryButton(
            label: 'Edit Worldo',
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
        const _SectionTitle(title: 'Worldo Brief'),
        const SizedBox(height: 8),
        Text(body, style: _bodyTextStyle),
        const SizedBox(height: 8),
        _OriginPreviewImage(url: _resolveAssetUrl(origin.mapImage)),
      ],
    );
  }
}

class _OriginPreviewImage extends StatelessWidget {
  const _OriginPreviewImage({required this.url});

  static const double _maxHeight = 360;
  static const double _aspectRatio = 2 / 3;

  final String url;

  @override
  Widget build(BuildContext context) {
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
        final imageUrl = url.trim();
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isEmpty
                  ? fallback
                  : imageUrl.startsWith('assets/')
                  ? Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => fallback,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => fallback,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return fallback;
                      },
                    ),
            ),
          ),
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
    final paragraphsRaw = tickResult['paragraphs'];
    final paragraphs = paragraphsRaw is List
        ? paragraphsRaw.whereType<Map>().map((raw) => raw.cast()).toList()
        : const <Map<dynamic, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Launch Preview'),
        const SizedBox(height: 8),
        if (globalBody.trim().isNotEmpty)
          _OriginPreviewEventCard(label: 'Global', body: globalBody)
        else if (paragraphs.isEmpty)
          const Text('No preview', style: _mutedBodyTextStyle),
        for (final paragraph in paragraphs)
          _OriginPreviewEventCard(
            label: _mapString(paragraph, const [
              'location_name',
              'name',
              'label',
            ]),
            body: _mapString(paragraph, const [
              'content',
              'text',
              'summary',
              'narrator',
            ]),
          ),
      ],
    );
  }
}

class _OriginPreviewEventCard extends StatelessWidget {
  const _OriginPreviewEventCard({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final visibleBody = body.trim();
    if (visibleBody.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF8F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.trim().isNotEmpty) ...[
                Text(
                  label.trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(visibleBody, style: _bodyTextStyle),
            ],
          ),
        ),
      ),
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
                    _SectionTitle(title: 'Discuss (${origin.discussCount})'),
                    if (showDiscussList) ...[
                      const SizedBox(height: 8),
                      OriginDiscussList(
                        controller: controller,
                        count: origin.discussCount,
                        showHeader: false,
                        showActions: false,
                        showReplies: false,
                        disableAvatarProfileTap: true,
                        onViewMoreTap: () => _openDiscussPage(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!hasDiscussContent) ...[
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Characters (${characters.length})'),
        const SizedBox(height: 14),
        if (characters.isEmpty)
          const Text('No characters', style: _mutedBodyTextStyle)
        else
          for (int i = 0; i < characters.length; i++) ...[
            _OriginCharacterRow(character: characters[i]),
            if (i != characters.length - 1) const SizedBox(height: 20),
          ],
      ],
    );
  }
}

class _OriginCharacterRow extends StatelessWidget {
  const _OriginCharacterRow({required this.character});

  final OriginCharacter character;

  @override
  Widget build(BuildContext context) {
    final identity = _splitTags(character.tags).join(' · ');
    final tagline = character.tagline.trim();
    final description = character.description.trim();
    final visibleDescription = _sameCharacterText(tagline, description)
        ? ''
        : description;
    final goal = character.goal.trim();
    final avatarUrl = _resolveAssetUrl(character.avatar);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _OriginCharacterPortrait(url: avatarUrl, name: character.name),
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
                  decoration: TextDecoration.none,
                ),
              ),
              if (identity.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(identity, style: _bodyTextStyle),
              ],
              if (tagline.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  tagline,
                  style: _bodyTextStyle.copyWith(
                    color: const Color(0xFFFF2442),
                  ),
                ),
              ],
              if (visibleDescription.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(visibleDescription, style: _characterBodyTextStyle),
              ],
              if (goal.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text('Goal: $goal', style: _characterBodyTextStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OriginCharacterPortrait extends StatelessWidget {
  const _OriginCharacterPortrait({required this.url, required this.name});

  static const double _width = 86;

  final String url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final fallback = GenesisAvatarFallback(
      name: name,
      width: _width,
      height: _width,
      borderRadius: 8,
    );
    final imageUrl = url.trim();
    final image = imageUrl.isEmpty
        ? fallback
        : imageUrl.startsWith('assets/')
        ? Image.asset(
            imageUrl,
            width: _width,
            height: _width,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : Image.network(
            imageUrl,
            width: _width,
            height: _width,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: image),
        const Positioned(
          top: -7,
          right: -8,
          child: Icon(Icons.auto_awesome, size: 20, color: Color(0xFFFF2442)),
        ),
      ],
    );
  }
}

const _bodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.45,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
  decoration: TextDecoration.none,
);

const _characterBodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.35,
  fontWeight: FontWeight.w400,
  color: Color(0xFF111111),
  decoration: TextDecoration.none,
);

const _mutedBodyTextStyle = TextStyle(
  fontSize: 13,
  height: 1.3,
  fontWeight: FontWeight.w600,
  color: Color(0xFF999999),
  decoration: TextDecoration.none,
);

List<String> _splitTags(String tags) {
  if (tags.trim().isEmpty) return const [];
  return tags
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

bool _sameCharacterText(String a, String b) {
  final left = a.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  final right = b.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  return left.isNotEmpty && left == right;
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
  return origin.ticks.isEmpty ? null : origin.ticks.first;
}

bool _originPreviewParagraphHasText(Map<String, dynamic> paragraph) {
  return _mapString(paragraph, const [
    'content',
    'text',
    'summary',
    'narrator',
  ]).isNotEmpty;
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
