import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/auth/login_guard.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/chat/shared/location_chat_overlay_transition.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import '../../components/common/genesis_generation_wait_overlay.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/copyable_id_label.dart';
import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/discuss/story_badge.dart';
import '../../components/login_sheet.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/origin/stat_item.dart';
import '../../components/world_map.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../components/world_tick_event_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../ui/components/genesis_static_network_image.dart';
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
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_radii.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/gems/daily_check_in_coordinator.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/stat_count_formatter.dart';
import '../chat/location_chat_page.dart';
import '../world/world_header.dart';
import '../world/world_map_bubble_candidates.dart';
import '../world/world_navigation.dart';
import '../world/world_page_result.dart';
import 'origin_launch_coordinator.dart';
import 'origin_launch_flow.dart';

part 'origin_world_map_shell.dart';
part 'origin_world_detail_sheet.dart';
part 'origin_world_sections.dart';
part 'origin_world_copy_progress.dart';
part 'origin_world_location_chat.dart';
part 'origin_world_map_data.dart';
part 'origin_world_launch_wait.dart';

class OriginWorldPage extends StatefulWidget {
  const OriginWorldPage({super.key, required this.oid, required this.originId});

  final String oid;
  final int originId;

  @override
  State<OriginWorldPage> createState() => _OriginWorldPageState();
}

@visibleForTesting
const double originDetailSheetHorizontalPaddingForTesting = 12;

@visibleForTesting
const double originDetailSheetHeaderHeightForTesting = 30;

@visibleForTesting
const double originDetailSheetHeaderBodyGapForTesting = 0;

@visibleForTesting
const double originDetailSheetHandleTopOffsetForTesting = 2;

@visibleForTesting
const double originDetailSectionGapForTesting = 24;

@visibleForTesting
const double originDetailSectionTitleIconGapForTesting = 8;

class _OriginWorldPageState extends State<OriginWorldPage>
    with SingleTickerProviderStateMixin {
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
  static const double _launchWaitAvatarSize = 88;

  late final TabController _tabController;
  final OriginLaunchCoordinator _launchCoordinator =
      OriginLaunchCoordinator.instance;
  Future<OriginDetail>? _future;
  Future<List<OriginLaunchedWorldRole>>? _launchedWorldsFuture;
  List<OriginLaunchedWorldRole>? _preloadedLaunchedWorlds;
  bool _launching = false;
  bool _didResumePendingLaunch = false;
  bool _showLocationPage = false;
  int _detailSheetCollapseRequest = 0;
  List<GenesisGenerationWaitAvatar> _launchWaitAvatars =
      const <GenesisGenerationWaitAvatar>[];
  _OriginLocationChatDescriptor? _activeChatLocation;
  late final VoidCallback _removeLaunchOutcomeListener;

  SystemUiOverlayStyle get _baseStatusBarStyle => _showLocationPage
      ? _transparentDarkStatusBarStyle
      : _transparentStatusBarStyle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      _launchedWorldsFuture = null;
      _preloadedLaunchedWorlds = null;
      _future = _loadOriginDetail();
      _activeChatLocation = null;
      _showLocationPage = false;
      _tabController.index = 0;
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
      _launchedWorldsFuture = null;
      _preloadedLaunchedWorlds = null;
      _future = _loadOriginDetail();
    });
  }

  @override
  void dispose() {
    GenesisSystemUiChrome.applyDefault();
    _launchCoordinator.state.removeListener(_syncLaunchState);
    _removeLaunchOutcomeListener();
    _tabController.dispose();
    super.dispose();
  }

  Future<OriginDetail> _loadOriginDetail() async {
    final api = AppServicesScope.read(context).api;
    final origin = await api.getOrigin(widget.oid);
    _cacheLaunchWaitAvatars(origin);
    _preloadLaunchedWorlds(origin);
    return origin;
  }

  void _preloadLaunchedWorlds(OriginDetail origin) {
    final future = _launchedWorldsFuture ??= _loadLaunchedWorldRoles(origin);
    unawaited(
      future.then(
        (worlds) {
          if (!mounted) return;
          _preloadedLaunchedWorlds = worlds;
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            '[OriginWorldPage] launched worlds preload failed: '
            '$error\n$stackTrace',
          );
        },
      ),
    );
  }

  void _cacheLaunchWaitAvatars(OriginDetail origin) {
    final avatars = _launchWaitAvatarsFromOrigin(origin);
    _precacheLaunchWaitAvatarImages(avatars);
    if (_sameWaitAvatars(_launchWaitAvatars, avatars)) return;
    if (!mounted) {
      _launchWaitAvatars = avatars;
      return;
    }
    setState(() => _launchWaitAvatars = avatars);
  }

  List<GenesisGenerationWaitAvatar> _launchWaitAvatarsFromOrigin(
    OriginDetail origin,
  ) {
    return origin.characters
        .map((character) {
          return GenesisGenerationWaitAvatar(
            name: character.name.trim(),
            url: _resolveAssetUrl(character.avatar).trim(),
          );
        })
        .where((avatar) => avatar.name.isNotEmpty || avatar.url.isNotEmpty)
        .toList(growable: false);
  }

  void _precacheLaunchWaitAvatarImages(
    List<GenesisGenerationWaitAvatar> avatars,
  ) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 1;
    for (final avatar in avatars) {
      final resolvedUrl = selectGenesisImageUrl(
        avatar.url,
        logicalWidth: _launchWaitAvatarSize,
        logicalHeight: _launchWaitAvatarSize,
        devicePixelRatio: devicePixelRatio,
      ).trim();
      if (resolvedUrl.isEmpty) continue;
      if (resolvedUrl.startsWith('assets/')) continue;
      unawaited(_precacheLaunchAvatarFile(resolvedUrl));
    }
  }

  Future<void> _precacheLaunchAvatarFile(String url) async {
    try {
      await DefaultCacheManager().getSingleFile(url);
    } catch (error) {
      debugPrint(
        '[OriginWorldPage] launch avatar precache failed url="$url": $error',
      );
    }
  }

  bool _sameWaitAvatars(
    List<GenesisGenerationWaitAvatar> a,
    List<GenesisGenerationWaitAvatar> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name || a[i].url != b[i].url) return false;
    }
    return true;
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

  void _recordWorldoMapClick(OriginDetail origin) {
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_map_click',
      object1: origin.oid,
    );
  }

  void _closeLocationChat() {
    if (_activeChatLocation == null) return;
    setState(() => _activeChatLocation = null);
  }

  void _handleOriginPopBlocked() {
    if (_activeChatLocation == null) return;
    _closeLocationChat();
  }

  void _handleMapModeTabTap(int index) {
    final nextShowsLocationPage = index == 1;
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: nextShowsLocationPage
          ? 'worldo_detail_location_list'
          : 'worldo_map',
      object1: widget.oid,
    );
    setState(() {
      _showLocationPage = nextShowsLocationPage;
      _detailSheetCollapseRequest += 1;
    });
    SystemChrome.setSystemUIOverlayStyle(
      nextShowsLocationPage
          ? _transparentDarkStatusBarStyle
          : _transparentStatusBarStyle,
    );
  }

  Future<void> _showLaunchRoleSheet(OriginDetail origin) async {
    if (_launching) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    await _openLaunchRoleSheet(origin);
  }

  Future<void> _openLaunchRoleSheet(OriginDetail origin) async {
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
      launchedWorldsLoader: () =>
          _launchedWorldsFuture ??= _loadLaunchedWorldRoles(origin),
      initialLaunchedWorlds: _preloadedLaunchedWorlds,
    );
    if (!mounted || selection == null) return;
    final existingWorldId = selection.existingWorldId?.trim() ?? '';
    if (existingWorldId.isNotEmpty) {
      _enterLaunchedWorld(existingWorldId);
      return;
    }
    await _launchOrigin(origin, selection);
  }

  void _enterLaunchedWorld(String worldId) {
    final navigator = Navigator.of(context);
    openWorldFromMyWorldsRoot(navigator, arguments: {'wid': worldId});
  }

  Future<List<OriginLaunchedWorldRole>> _loadLaunchedWorldRoles(
    OriginDetail origin,
  ) async {
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    if (uid.isEmpty) return const <OriginLaunchedWorldRole>[];
    final response = await services.api.v1.world.list(
      scene: 'mine',
      originId: origin.oid,
      pn: 1,
      rn: 20,
    );
    final rawList = response['list'];
    if (rawList is! List) return const <OriginLaunchedWorldRole>[];
    final worldIds = rawList
        .whereType<Map>()
        .map((raw) {
          final map = asJsonMap(raw);
          final info = map['info'] is Map ? asJsonMap(map['info']) : map;
          return asString(info['world_id'], fallback: asString(map['wid']));
        })
        .where((worldId) => worldId.isNotEmpty)
        .toList(growable: false);
    final worlds = await Future.wait(worldIds.map(services.api.getWorld));
    return worlds
        .map((world) {
          final role = world.characters
              .where((item) => asString(item['player_uid']) == uid)
              .firstOrNull;
          return OriginLaunchedWorldRole(
            worldId: world.worldId,
            roleName: role == null ? 'My role' : asString(role['name']),
            avatarUrl: role == null ? '' : asString(role['avatar']),
            tickCount: world.tickCount,
            currentTime: world.currentTime,
          );
        })
        .toList(growable: false);
  }

  Future<void> _launchOrigin(
    OriginDetail origin,
    OriginRoleLaunchSelection roleSelection,
  ) async {
    if (_launching) return;
    final avatars = _launchWaitAvatarsFromOrigin(origin);
    setState(() {
      _launchWaitAvatars = avatars;
      _launching = true;
    });
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
    if (userInfo == null || userInfo.isEmpty) {
      if (mounted) {
        showGenesisToast(context, 'No saved profile found');
      }
      return null;
    }
    final cachedUser = userInfo;
    final cachedName = _mapString(cachedUser, const [
      'name',
      'nickname',
      'user_name',
      'displayName',
      'display_name',
    ]);
    final resolvedAvatar = _resolvedProfileAvatar(cachedUser, '');

    return OriginCustomRoleDraft(
      avatarUrl: resolvedAvatar,
      name: cachedName,
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
    await showDailyCheckInAfterLogin(context);
    if (!mounted) return false;
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
      'login_provider': provider.name,
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
              avatars: _launchWaitAvatars,
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
                  collapseRequest: _detailSheetCollapseRequest,
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
                messageBubbles: _activeChatLocation == null
                    ? _originMapMessageBubbles(origin)
                    : const <WorldMapMessageBubble>[],
                messageBubblePlaybackPaused: _activeChatLocation != null,
                dimmed: _showLocationPage,
                showPointsList: _showLocationPage,
                initialZoomScale: _showLocationPage ? 1 : 1.2,
                enableAvatarScaleReboundHint: true,
                pointsListOuterScrollHandoff: false,
                overlayTop: topPadding + 8 + 48,
                drillExitTop: topPadding + 68,
                onMapTap: () => _recordWorldoMapClick(origin),
                onPointTap: (point) => _openChatForPoint(origin, point),
              ),
            ),
          ),
        );
      },
    );
  }
}
