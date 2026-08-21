import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/components/genesis_feature_themes.dart';

import '../../app/telemetry/genesis_telemetry.dart';
import '../../app/telemetry/firebase_performance_operation.dart';
import '../../components/auth/login_guard.dart';
import '../../components/chat/shared/chat_ui.dart';
import '../../components/chat/shared/location_chat_overlay_transition.dart';
import '../../components/common/genesis_image_viewer_overlay.dart';
import '../../components/common/genesis_report_actions.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/copyable_id_label.dart';
import '../../components/discuss/discuss_post_input.dart';
import '../../components/discuss/origin_discuss_list.dart';
import '../../components/discuss/story_badge.dart';
import '../../components/login_sheet.dart';
import '../../components/map_detail_sheet_surface.dart';
import '../../components/origin/origin_role_launch_sheet.dart';
import '../../components/origin/origin_role_recommendation.dart';
import '../../components/origin/stat_item.dart';
import '../../components/tilemap/tilemap_renderer.dart';
import '../../components/tilemap/tilemap_settings_store.dart';
import '../../components/world_map.dart';
import '../../ui/genesis_ui.dart';
import '../../components/world_top_overlay_bar.dart';
import '../../network/genesis_http_cache_manager.dart';
import '../../components/world_tick_event_item.dart';
import '../../icons/custom_icon_assets.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/chatroom/world_chatroom_service.dart';
import '../../network/genesis_api.dart';
import '../../network/json_utils.dart';
import '../../network/models/location_tree.dart';
import '../../network/models/origin.dart';
import '../../platform/auth/auth_session.dart';
import '../../routers/app_router.dart';
import '../../app/bootstrap/app_services_scope.dart';
import '../../app/gems/daily_check_in_coordinator.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/genesis_timestamp_formatter.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/genesis_image_resource.dart';
import '../../utils/stat_count_formatter.dart';
import '../chat/location_chat_background_preloader.dart';
import '../chat/location_chat_page.dart';
import '../world/world_header.dart';
import '../world/world_map_bubble_candidates.dart';
import '../world/world_navigation.dart';
import '../world/world_page_result.dart';
import 'origin_launch_flow.dart';
import 'origin_role_portrait_image_provider.dart';
import 'origin_world_layout.dart';

part 'origin_world_map_shell.dart';
part 'origin_world_detail_sheet.dart';
part 'origin_world_sections.dart';
part 'origin_world_role_setup.dart';
part 'origin_world_characters.dart';
part 'origin_world_copy_progress.dart';
part 'origin_world_location_chat.dart';
part 'origin_world_map_data.dart';

class OriginWorldPage extends StatefulWidget {
  const OriginWorldPage({super.key, required this.oid, required this.originId});

  final String oid;
  final int originId;

  @override
  State<OriginWorldPage> createState() => _OriginWorldPageState();
}

@visibleForTesting
const double originDetailSheetHorizontalPaddingForTesting = 20;

@visibleForTesting
const double originDetailSheetHeaderHeightForTesting = 30;

@visibleForTesting
const double originInfoPinnedHeaderHeightForTesting = 76;

@visibleForTesting
const double originDetailSheetHeaderBodyGapForTesting = 0;

@visibleForTesting
const double originDetailSheetHandleTopOffsetForTesting = 2;

@visibleForTesting
const double originDetailSectionGapForTesting = 20;

@visibleForTesting
const double originDetailSectionTitleIconGapForTesting = 8;

enum _OriginWorldPageRenderStage { framework, detailShell, content }

class _OriginWorldPageState extends State<OriginWorldPage>
    with SingleTickerProviderStateMixin {
  static const SystemUiOverlayStyle _transparentStatusBarStyle =
      kGenesisLightStatusIconsSystemUiOverlayStyle;
  static const SystemUiOverlayStyle _transparentDarkStatusBarStyle =
      kGenesisDefaultSystemUiOverlayStyle;
  late final TabController _tabController;
  OriginDetail? _origin;
  Object? _initialLoadError;
  _OriginWorldPageRenderStage _renderStage =
      _OriginWorldPageRenderStage.framework;
  bool _contentMountScheduled = false;
  int _originLoadGeneration = 0;
  FirebasePerformanceOperation? _initialRequestPerformanceOperation;
  FirebasePerformanceOperation? _initialRenderPerformanceOperation;
  var _initialRequestPerformanceAttempt = 0;
  var _initialContentRenderCompleted = false;
  TilemapVisualMode _tilemapVisualMode = tilemapVisualModeController.value;
  late final Future<void> _tilemapVisualModeLoad;
  bool _tilemapVisualModeReady = false;
  Future<List<OriginMyLaunchPresetCharacter>>? _launchedPresetRolesFuture;
  Future<List<OriginMyLaunchPresetCharacter>>?
  _launchedPresetRolesPreparationFuture;
  List<OriginMyLaunchPresetCharacter>? _launchedPresetRolesData;
  String _launchedPresetRolesCacheKey = '';
  String _launchedPresetRolesPreloadScheduledForOriginId = '';
  ValueListenable<int>? _userInfoRevisionListenable;
  OriginCustomRoleDraft? _cachedProfileRole;
  int _cachedProfileRoleLoadGeneration = 0;
  final Set<String> _preloadedProfileRoleAvatarKeys = <String>{};
  bool _launching = false;
  bool _showIntroPage = false;
  final int _detailSheetCollapseRequest = 0;
  int _detailSheetExpandRequest = 0;
  int _detailSheetRequestedPage = _originOpeningPageIndex;
  int _detailSheetPageRequest = 0;
  bool _entryDetailResponsePending = true;
  bool _waitingForOpeningSheetExpansion = false;
  final ValueNotifier<bool> _detailSheetRaisedNotifier = ValueNotifier<bool>(
    false,
  );
  _OriginLocationChatDescriptor? _activeChatLocation;
  final LocationChatBackgroundPreloader _locationChatBackgroundPreloader =
      LocationChatBackgroundPreloader();
  Set<String> _currentTilemapLocationIds = const <String>{};

  SystemUiOverlayStyle get _baseStatusBarStyle => _showIntroPage
      ? _transparentDarkStatusBarStyle
      : _transparentStatusBarStyle;

  @override
  void initState() {
    super.initState();
    tilemapVisualModeController.addListener(_handleTilemapVisualModeChanged);
    _tilemapVisualModeLoad = _loadTilemapVisualMode();
    _tabController = TabController(length: 2, vsync: this);
    _scheduleInitialOriginLoadAfterFrameworkFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextRevisionListenable = AppServicesScope.read(
      context,
    ).sessionStore.userInfoRevision;
    if (identical(_userInfoRevisionListenable, nextRevisionListenable)) return;
    _userInfoRevisionListenable?.removeListener(_handleCachedUserInfoChanged);
    _userInfoRevisionListenable = nextRevisionListenable;
    nextRevisionListenable.addListener(_handleCachedUserInfoChanged);
    unawaited(_refreshCachedProfileRole());
  }

  @override
  void didUpdateWidget(covariant OriginWorldPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oid != widget.oid) {
      unawaited(_initialRequestPerformanceOperation?.cancel());
      unawaited(_initialRenderPerformanceOperation?.cancel());
      _initialRequestPerformanceOperation = null;
      _initialRenderPerformanceOperation = null;
      _initialRequestPerformanceAttempt = 0;
      _initialContentRenderCompleted = false;
      _launchedPresetRolesFuture = null;
      _launchedPresetRolesPreparationFuture = null;
      _launchedPresetRolesData = null;
      _launchedPresetRolesCacheKey = '';
      _launchedPresetRolesPreloadScheduledForOriginId = '';
      _originLoadGeneration += 1;
      _origin = null;
      _initialLoadError = null;
      _renderStage = _OriginWorldPageRenderStage.framework;
      _contentMountScheduled = false;
      _activeChatLocation = null;
      _currentTilemapLocationIds = const <String>{};
      _locationChatBackgroundPreloader.preload(const <Object?>[]);
      _showIntroPage = false;
      _detailSheetExpandRequest = 0;
      _detailSheetRequestedPage = _originOpeningPageIndex;
      _detailSheetPageRequest += 1;
      _entryDetailResponsePending = true;
      _waitingForOpeningSheetExpansion = false;
      _detailSheetRaisedNotifier.value = false;
      _tabController.index = 0;
      _scheduleInitialOriginLoadAfterFrameworkFrame();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _launchedPresetRolesFuture = null;
      _launchedPresetRolesPreparationFuture = null;
      _launchedPresetRolesData = null;
      _launchedPresetRolesCacheKey = '';
      _launchedPresetRolesPreloadScheduledForOriginId = '';
    });
    unawaited(_fetchOriginDetail());
  }

  @override
  void dispose() {
    unawaited(_initialRequestPerformanceOperation?.cancel());
    unawaited(_initialRenderPerformanceOperation?.cancel());
    _originLoadGeneration += 1;
    _cachedProfileRoleLoadGeneration += 1;
    _userInfoRevisionListenable?.removeListener(_handleCachedUserInfoChanged);
    _locationChatBackgroundPreloader.dispose();
    _detailSheetRaisedNotifier.dispose();
    tilemapVisualModeController.removeListener(_handleTilemapVisualModeChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleCachedUserInfoChanged() {
    unawaited(_refreshCachedProfileRole());
  }

  Future<void> _refreshCachedProfileRole() async {
    final generation = ++_cachedProfileRoleLoadGeneration;
    final services = AppServicesScope.read(context);
    final uid = (await services.sessionStore.readUid())?.trim() ?? '';
    final authToken =
        (await services.sessionStore.readAuthToken())?.trim() ?? '';
    OriginCustomRoleDraft? nextRole;
    if (uid.isNotEmpty && !uid.startsWith('guest_') && authToken.isNotEmpty) {
      final userInfo = await services.sessionStore.readUserInfo();
      final cachedName = userInfo == null
          ? ''
          : _mapString(userInfo, const [
              'name',
              'nickname',
              'user_name',
              'displayName',
              'display_name',
            ]);
      nextRole = OriginCustomRoleDraft(
        avatarUrl: userInfo == null ? '' : _resolvedProfileAvatar(userInfo, ''),
        name: cachedName.isEmpty ? uid : cachedName,
        identity: '',
      );
    }
    if (!mounted || generation != _cachedProfileRoleLoadGeneration) return;
    if (nextRole != null) {
      _precacheProfileRoleAvatar(nextRole);
    }
    if (_sameOriginProfileRole(_cachedProfileRole, nextRole)) return;
    setState(() => _cachedProfileRole = nextRole);
  }

  void _precacheProfileRoleAvatar(OriginCustomRoleDraft profileRole) {
    if (!mounted) return;
    final avatarUrl = _originRoleCardAvatarUrl(
      context,
      _resolveAssetUrl(profileRole.avatarUrl),
    );
    if (avatarUrl.isEmpty) return;

    final devicePixelRatio = genesisImageDevicePixelRatio(
      MediaQuery.devicePixelRatioOf(context),
    );
    final outputSize = (_OriginSetupRoleSection._cardHeight * devicePixelRatio)
        .ceil();
    final cacheKey = '$avatarUrl@$outputSize';
    if (!_preloadedProfileRoleAvatarKeys.add(cacheKey)) return;

    final provider = OriginRolePortraitImageProvider.fromUrl(
      imageUrl: avatarUrl,
      outputSize: outputSize,
    );
    unawaited(
      precacheImage(
        provider,
        context,
        onError: (error, stackTrace) {
          _preloadedProfileRoleAvatarKeys.remove(cacheKey);
          debugPrint(
            '[OriginWorldPage] profile role avatar precache failed '
            'url="$avatarUrl": $error',
          );
        },
      ),
    );
  }

  Color get _tilemapLoadingBackgroundColor =>
      tilemapVisualStyleFor(_tilemapVisualMode).backgroundColor;

  Future<void> _loadTilemapVisualMode() async {
    if (tilemapVisualModeController.isHydrated) {
      _tilemapVisualModeReady = true;
      return;
    }
    try {
      await const TilemapSettingsStore().load().timeout(
        const Duration(seconds: 2),
      );
    } catch (error) {
      debugPrint(
        '[OriginWorldPage] tilemap settings load failed; using defaults: '
        '$error',
      );
    } finally {
      _tilemapVisualModeReady = true;
    }
  }

  void _handleTilemapVisualModeChanged() {
    final visualMode = tilemapVisualModeController.value;
    if (!mounted || _tilemapVisualMode == visualMode) return;
    setState(() => _tilemapVisualMode = visualMode);
  }

  void _scheduleInitialOriginLoadAfterFrameworkFrame() {
    final scheduledGeneration = _originLoadGeneration;
    final scheduledOriginId = widget.oid.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _origin != null ||
          scheduledGeneration != _originLoadGeneration ||
          scheduledOriginId != widget.oid.trim()) {
        return;
      }
      unawaited(_fetchOriginDetail(isInitial: true));
    });
  }

  Future<void> _fetchOriginDetail({bool isInitial = false}) async {
    final generation = ++_originLoadGeneration;
    final requestedOriginId = widget.oid.trim();
    FirebasePerformanceOperation? requestOperation;
    if (isInitial && !_initialContentRenderCompleted) {
      final attempt = ++_initialRequestPerformanceAttempt;
      requestOperation = await FirebasePerformanceOperation.start(
        surface: FirebasePerformanceSurface.originWorldPage,
        phase: FirebasePerformancePhase.request,
        attempt: attempt,
      );
      if (!mounted ||
          generation != _originLoadGeneration ||
          widget.oid.trim() != requestedOriginId) {
        unawaited(requestOperation.cancel());
        return;
      }
      _initialRequestPerformanceOperation = requestOperation;
    }
    try {
      final origin = await AppServicesScope.read(
        context,
      ).api.getOrigin(requestedOriginId);
      if (!mounted ||
          generation != _originLoadGeneration ||
          widget.oid.trim() != requestedOriginId) {
        unawaited(requestOperation?.cancel());
        return;
      }
      if (identical(_initialRequestPerformanceOperation, requestOperation)) {
        _initialRequestPerformanceOperation = null;
      }
      unawaited(requestOperation?.succeed());
      final shouldStageInitialContent =
          isInitial ||
          _origin == null ||
          _renderStage != _OriginWorldPageRenderStage.content;
      final handlesEntryDetailResponse = _entryDetailResponsePending;
      setState(() {
        _origin = origin;
        _initialLoadError = null;
        if (handlesEntryDetailResponse) {
          _entryDetailResponsePending = false;
          if (origin.showOpeningSheet) {
            _detailSheetExpandRequest += 1;
            _waitingForOpeningSheetExpansion = true;
          }
        }
        if (shouldStageInitialContent) {
          _renderStage = _OriginWorldPageRenderStage.detailShell;
          _contentMountScheduled = false;
        }
      });
      _preloadCurrentTilemapLocationBackgrounds(origin);
      if (!shouldStageInitialContent) {
        _scheduleDeferredOriginPreloads(origin, generation);
      }
    } catch (error, stackTrace) {
      if (!mounted ||
          generation != _originLoadGeneration ||
          widget.oid.trim() != requestedOriginId) {
        unawaited(requestOperation?.cancel());
        return;
      }
      if (identical(_initialRequestPerformanceOperation, requestOperation)) {
        _initialRequestPerformanceOperation = null;
      }
      unawaited(
        requestOperation?.fail(errorType: firebasePerformanceErrorType(error)),
      );
      if (_origin == null) {
        setState(() => _initialLoadError = error);
      } else {
        debugPrint(
          '[OriginWorldPage] detail refresh failed: $error\n$stackTrace',
        );
        if (_renderStage == _OriginWorldPageRenderStage.detailShell) {
          unawaited(_mountContentAfterDetailShell(_origin!, generation));
        }
      }
    }
  }

  void _scheduleContentMountAfterDetailShellFrame(OriginDetail origin) {
    if (_renderStage != _OriginWorldPageRenderStage.detailShell ||
        _contentMountScheduled) {
      return;
    }
    final generation = _originLoadGeneration;
    _contentMountScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _originLoadGeneration ||
          !identical(_origin, origin) ||
          _renderStage != _OriginWorldPageRenderStage.detailShell) {
        _contentMountScheduled = false;
        return;
      }
      if (origin.definitionVersion != 2 ||
          _tilemapVisualModeReady ||
          tilemapVisualModeController.isHydrated) {
        unawaited(_mountContentAfterDetailShell(origin, generation));
        return;
      }
      unawaited(_mountContentAfterTilemapVisualModeLoad(origin, generation));
    });
  }

  Future<void> _mountContentAfterTilemapVisualModeLoad(
    OriginDetail origin,
    int generation,
  ) async {
    if (origin.definitionVersion == 2) {
      await _tilemapVisualModeLoad;
    }
    await _mountContentAfterDetailShell(origin, generation);
  }

  Future<void> _mountContentAfterDetailShell(
    OriginDetail origin,
    int generation,
  ) async {
    if (!mounted ||
        generation != _originLoadGeneration ||
        !identical(_origin, origin) ||
        _renderStage != _OriginWorldPageRenderStage.detailShell) {
      _contentMountScheduled = false;
      return;
    }
    FirebasePerformanceOperation? renderOperation;
    if (!_initialContentRenderCompleted &&
        _initialRenderPerformanceOperation == null) {
      renderOperation = await FirebasePerformanceOperation.start(
        surface: FirebasePerformanceSurface.originWorldPage,
        phase: FirebasePerformancePhase.render,
        attempt: _initialRequestPerformanceAttempt == 0
            ? 1
            : _initialRequestPerformanceAttempt,
        timeout: FirebasePerformanceOperation.renderTimeout,
      );
      if (!mounted ||
          generation != _originLoadGeneration ||
          !identical(_origin, origin) ||
          _renderStage != _OriginWorldPageRenderStage.detailShell) {
        unawaited(renderOperation.cancel());
        _contentMountScheduled = false;
        return;
      }
      _initialRenderPerformanceOperation = renderOperation;
    }
    setState(() {
      _contentMountScheduled = false;
      _renderStage = _OriginWorldPageRenderStage.content;
    });
    if (renderOperation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            generation != _originLoadGeneration ||
            !identical(_initialRenderPerformanceOperation, renderOperation) ||
            !identical(_origin, origin) ||
            _renderStage != _OriginWorldPageRenderStage.content) {
          if (identical(_initialRenderPerformanceOperation, renderOperation)) {
            _initialRenderPerformanceOperation = null;
          }
          unawaited(renderOperation?.cancel());
          return;
        }
        _initialRenderPerformanceOperation = null;
        _initialContentRenderCompleted = true;
        unawaited(renderOperation?.succeed());
      });
    }
    _scheduleDeferredOriginPreloads(origin, generation);
  }

  void _scheduleDeferredOriginPreloads(OriginDetail origin, int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _originLoadGeneration ||
          !identical(_origin, origin) ||
          _renderStage != _OriginWorldPageRenderStage.content) {
        return;
      }
      _precacheRoleCardAvatarImages(origin);
      _scheduleLaunchedPresetRolesPreload();
    });
  }

  void _scheduleLaunchedPresetRolesPreload() {
    final originId = widget.oid.trim();
    if (originId.isEmpty ||
        _launchedPresetRolesPreloadScheduledForOriginId == originId) {
      return;
    }
    _launchedPresetRolesPreloadScheduledForOriginId = originId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.oid.trim() != originId) return;
      unawaited(_ensureLaunchedPresetRolesLoaded());
    });
  }

  void _precacheRoleCardAvatarImages(OriginDetail origin) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return;
    final urls = origin.characters
        .map(
          (character) => selectGenesisImageUrl(
            _resolveAssetUrl(character.avatar),
            logicalWidth: _OriginSetupRoleSection._cardWidth,
            logicalHeight: _OriginSetupRoleSection._cardHeight,
            devicePixelRatio: mediaQuery.devicePixelRatio,
          ).trim(),
        )
        .where((url) => url.isNotEmpty && !url.startsWith('assets/'))
        .toSet();
    for (final url in urls) {
      unawaited(_precacheOriginAvatarFile(url));
    }
  }

  Future<void> _precacheOriginAvatarFile(String url) async {
    try {
      await GenesisHttpCacheManager().getSingleFile(url);
    } catch (error) {
      debugPrint('[OriginWorldPage] avatar precache failed url="$url": $error');
    }
  }

  void _refreshOriginDetail() {
    unawaited(_fetchOriginDetail());
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

  void _recordWorldoTilemapClick(OriginDetail origin) {
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_tilemap_click',
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

  void _openOriginInfoSheet() {
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'worldo_detail_intro',
      object1: widget.oid,
    );
    setState(() {
      _detailSheetRequestedPage = _originInfoPageIndex;
      _detailSheetPageRequest += 1;
      _detailSheetExpandRequest += 1;
    });
  }

  void _handleOriginDetailSheetPageChanged(int page) {
    if (!mounted || page == _detailSheetRequestedPage) return;
    _detailSheetRequestedPage = page;
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: page == _originInfoPageIndex
          ? 'worldo_detail_intro'
          : 'worldo_opening',
      object1: widget.oid,
    );
  }

  Future<void> _showLaunchRoleSheet(
    OriginDetail origin, {
    bool initialCustomTab = false,
    bool fillProfileOnOpen = false,
    String initialLocationId = '',
  }) async {
    if (_launching) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    await _openLaunchRoleSheet(
      origin,
      initialCustomTab: initialCustomTab,
      fillProfileOnOpen: fillProfileOnOpen,
      initialLocationId: initialLocationId,
    );
  }

  Future<void> _selectAndLaunchPresetRole(
    OriginDetail origin,
    OriginCharacter character,
  ) async {
    if (_launching) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    final characterId = _characterStableId(character);
    if (characterId.isEmpty) return;
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_setup_role_launch',
      object1: origin.oid,
      object2: characterId,
    );
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_launch_opening',
      object1: origin.oid,
    );
    await _launchOrigin(
      origin,
      OriginRoleLaunchSelection.preset(characterId),
      initialLocationId:
          _originFirstInitialDialoguePreview(origin)?.locationId ?? '',
    );
  }

  Future<void> _selectAndLaunchProfileRole(
    OriginDetail origin,
    OriginCustomRoleDraft profileRole,
  ) async {
    if (_launching) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!mounted) return;
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_setup_role_launch',
      object1: origin.oid,
      object2: 'current_user',
    );
    GenesisTelemetry.collectLog(
      actionType: 'event',
      action: 'worldo_launch_opening',
      object1: origin.oid,
    );
    await _launchOrigin(
      origin,
      OriginRoleLaunchSelection.custom(
        OriginCustomRoleDraft(
          avatarUrl: profileRole.avatarUrl,
          name: profileRole.name,
          identity: '',
        ),
      ),
      initialLocationId:
          _originFirstInitialDialoguePreview(origin)?.locationId ?? '',
    );
  }

  Future<void> _openLaunchRoleSheet(
    OriginDetail origin, {
    bool initialCustomTab = false,
    bool fillProfileOnOpen = false,
    String initialLocationId = '',
  }) async {
    final launchedPresetRoles = _launchedPresetRolesData;
    final launchLocationId = initialLocationId.trim();
    GenesisTelemetry.collectLog(
      actionType: 'pageview',
      action: 'launch_sheet',
      object1: origin.oid,
    );
    await showOriginRoleLaunchSheet(
      context: context,
      characters: origin.characters,
      initialCustomTab: initialCustomTab,
      fillProfileOnOpen: fillProfileOnOpen,
      initialLaunchedTab:
          !initialCustomTab && launchedPresetRoles?.isNotEmpty == true,
      resolveAvatarUrl: _resolveAssetUrl,
      onFillFromProfile: _customRoleFromProfile,
      initialLaunchedPresetRoles: launchedPresetRoles,
      launchedPresetRolesLoader: launchedPresetRoles == null
          ? _ensureLaunchedPresetRolesLoaded
          : null,
      onLaunch: (roleSelection) async {
        final existingWorldId = roleSelection.existingWorldId?.trim() ?? '';
        if (existingWorldId.isNotEmpty) {
          _enterLaunchedWorld(
            existingWorldId,
            initialLocationId: launchLocationId,
          );
          return OriginRoleLaunchHandlerResult.navigationHandled;
        }
        GenesisTelemetry.collectLog(
          actionType: 'event',
          action: 'worldo_launch_sheet',
          object1: origin.oid,
        );
        final launchedWorldId = await _launchOrigin(
          origin,
          roleSelection,
          enterWorldOnSuccess: false,
        );
        if (!mounted || launchedWorldId == null) {
          return OriginRoleLaunchHandlerResult.failed;
        }
        _enterLaunchedWorld(
          launchedWorldId,
          initialLocationId: launchLocationId,
        );
        return OriginRoleLaunchHandlerResult.navigationHandled;
      },
      systemUiOverlayStyle: _baseStatusBarStyle,
    );
  }

  void _enterLaunchedWorld(String worldId, {String initialLocationId = ''}) {
    final navigator = Navigator.of(context);
    openWorldFromMyWorldsRoot(
      navigator,
      arguments: {
        'wid': worldId,
        if (initialLocationId.trim().isNotEmpty)
          'initial_location_id': initialLocationId.trim(),
      },
    );
  }

  Future<List<OriginMyLaunchPresetCharacter>>
  _ensureLaunchedPresetRolesLoaded() {
    final preparation = _launchedPresetRolesPreparationFuture;
    if (preparation != null) return preparation;
    late final Future<List<OriginMyLaunchPresetCharacter>> trackedPreparation;
    trackedPreparation = _prepareLaunchedPresetRoles().whenComplete(() {
      if (identical(
        _launchedPresetRolesPreparationFuture,
        trackedPreparation,
      )) {
        _launchedPresetRolesPreparationFuture = null;
      }
    });
    _launchedPresetRolesPreparationFuture = trackedPreparation;
    return trackedPreparation;
  }

  Future<List<OriginMyLaunchPresetCharacter>>
  _prepareLaunchedPresetRoles() async {
    final originId = widget.oid.trim();
    if (originId.isEmpty) return const <OriginMyLaunchPresetCharacter>[];
    try {
      final services = AppServicesScope.read(context);
      final uid = (await services.sessionStore.readUid())?.trim() ?? '';
      final authToken =
          (await services.sessionStore.readAuthToken())?.trim() ?? '';
      if (!mounted ||
          widget.oid.trim() != originId ||
          uid.isEmpty ||
          uid.startsWith('guest_') ||
          authToken.isEmpty) {
        return const <OriginMyLaunchPresetCharacter>[];
      }

      final cacheKey = '$originId::$uid';
      final cachedFuture = _launchedPresetRolesFuture;
      if (_launchedPresetRolesCacheKey == cacheKey && cachedFuture != null) {
        return cachedFuture;
      }

      final request = _requestLaunchedPresetRoles(
        originId: originId,
        cacheKey: cacheKey,
      );
      _launchedPresetRolesCacheKey = cacheKey;
      _launchedPresetRolesFuture = request;
      return request;
    } catch (error, stackTrace) {
      debugPrint(
        '[OriginWorldPage] launched preset roles preparation failed: '
        '$error\n$stackTrace',
      );
      return const <OriginMyLaunchPresetCharacter>[];
    }
  }

  Future<List<OriginMyLaunchPresetCharacter>> _requestLaunchedPresetRoles({
    required String originId,
    required String cacheKey,
  }) async {
    try {
      final roles = await AppServicesScope.read(
        context,
      ).api.getMyLaunchPresetCharacters(originId);
      if (mounted && _launchedPresetRolesCacheKey == cacheKey) {
        _launchedPresetRolesData = roles;
      }
      return roles;
    } catch (error, stackTrace) {
      debugPrint(
        '[OriginWorldPage] launched preset roles preload failed: '
        '$error\n$stackTrace',
      );
      if (_launchedPresetRolesCacheKey == cacheKey) {
        _launchedPresetRolesCacheKey = '';
        _launchedPresetRolesFuture = null;
        _launchedPresetRolesData = null;
      }
      return const <OriginMyLaunchPresetCharacter>[];
    }
  }

  Future<String?> _launchOrigin(
    OriginDetail origin,
    OriginRoleLaunchSelection roleSelection, {
    String initialLocationId = '',
    bool enterWorldOnSuccess = true,
  }) async {
    if (_launching) return null;
    setState(() => _launching = true);
    final launchedWorldId = await startOriginLaunch(
      context: context,
      origin: origin,
      roleSelection: roleSelection,
    );
    if (!mounted) return null;
    if (launchedWorldId == null) {
      setState(() => _launching = false);
      return null;
    }
    setState(() {
      _launching = false;
      _launchedPresetRolesFuture = null;
      _launchedPresetRolesPreparationFuture = null;
      _launchedPresetRolesData = null;
      _launchedPresetRolesCacheKey = '';
    });
    if (enterWorldOnSuccess) {
      _enterLaunchedWorld(
        launchedWorldId,
        initialLocationId: initialLocationId,
      );
    }
    return launchedWorldId;
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
    return _buildPageContent(topPadding);
  }

  Widget _buildPageContent(double topPadding) {
    final origin = _origin;
    if (origin == null) {
      if (_initialLoadError != null) {
        return GenesisPageScaffold.custom(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Load failed'),
                const SizedBox(height: 10),
                GenesisButton(
                  label: 'Retry',
                  onPressed: () {
                    setState(() => _initialLoadError = null);
                    unawaited(_fetchOriginDetail(isInitial: true));
                  },
                  size: GenesisButtonSize.compact,
                  fullWidth: false,
                ),
              ],
            ),
          ),
        );
      }
      return _buildInitialLoadingScaffold(topPadding);
    }
    if (_renderStage != _OriginWorldPageRenderStage.content) {
      _scheduleContentMountAfterDetailShellFrame(origin);
      return _buildInitialLoadingScaffold(topPadding, origin: origin);
    }

    final processedLocationTree = origin.processedLocationTree;
    final initialTilemapLocationId = processedLocationTree
        .initialTilemapLocationId(
          syntheticRootId: originSyntheticRootLocationId,
        );
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
                  (node) => processedLocationTree.aggregateValues<UserAvatar>(
                    node.id,
                    avatarsByLocation,
                    idOf: worldMapAvatarStableId,
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
            allLocationNodes.map((node) => node.value).toList(growable: false),
            avatarsByLocation,
            depths: allLocationNodes
                .map((node) => node.depth)
                .toList(growable: false),
            isLeafLocations: allLocationNodes
                .map((node) => node.children.isEmpty)
                .toList(growable: false),
            usersByIndex: allLocationNodes
                .map(
                  (node) => processedLocationTree.aggregateValues<UserAvatar>(
                    node.id,
                    avatarsByLocation,
                    idOf: worldMapAvatarStableId,
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
    final deferTilemapRendering =
        origin.definitionVersion == 2 && _waitingForOpeningSheetExpansion;
    final Widget map = deferTilemapRendering
        ? ColoredBox(
            key: const ValueKey<String>('origin-opening-sheet-map-background'),
            color: _tilemapLoadingBackgroundColor,
          )
        : ValueListenableBuilder<bool>(
            valueListenable: _detailSheetRaisedNotifier,
            builder: (context, detailSheetRaised, _) => WorldMap.origin(
              definitionVersion: origin.definitionVersion,
              originId: origin.oid,
              common: WorldMapCommonConfig(
                locationNodes: locationNodes,
                drillExitTop: topPadding + 68,
                messageBubbles: _activeChatLocation == null
                    ? _originMapMessageBubbles(origin)
                    : const <WorldMapMessageBubble>[],
                messageBubblePlaybackPaused: _activeChatLocation != null,
                onMapTap: () => _recordWorldoMapClick(origin),
                onPointTap: (point) => _openChatForPoint(origin, point),
              ),
              legacy: LegacyWorldMapConfig(
                implementationKey: PageStorageKey<String>(
                  'origin-map-${origin.oid}',
                ),
                points: points,
                listPoints: listPoints,
                listLocationNodes: listLocationNodes,
                mapImageUrl: mapImageUrl,
                dimmed: _showIntroPage,
                showPointsList: _showIntroPage,
                showZoomControl: false,
                pointsListBuilder: _showIntroPage
                    ? (context) => _OriginIntroList(
                        origin: origin,
                        topPadding: topPadding + 8 + 48,
                        onOriginChanged: _refreshOriginDetail,
                      )
                    : null,
                initialZoomScale: 1,
                initialZoomFocus: const Offset(0.5, 0.5),
                initialViewportVerticalOffsetFraction: 0.05,
                enableAvatarScaleReboundHint: true,
                pointsListOuterScrollHandoff: false,
                overlayTop: topPadding + 8 + 48,
              ),
              tilemap: WorldMapTilemapOptions(
                implementationKey: PageStorageKey<String>(
                  'origin-tilemap-${origin.oid}',
                ),
                locationId: initialTilemapLocationId,
                locationNodes: listLocationNodes,
                preferredFocusLocationId:
                    origin.initLocationGroup?.locationId.trim() ?? '',
                showVisualModeToggle: !_showIntroPage,
                showZoomControl: false,
                centerInitialViewport: true,
                initialScaleOverride: tilemapInitialScaleMin,
                initialViewportVerticalOffsetFraction: 0.05,
                animationsPaused: detailSheetRaised,
                locationImageFlowPaused: detailSheetRaised,
                visualModeToggleTop: topPadding + 58,
                visualModeToggleRight: 12,
                onMapTap: () => _recordWorldoTilemapClick(origin),
                onCurrentLocationsChanged:
                    _handleCurrentTilemapLocationsChanged,
              ),
            ),
          );

    return PopScope(
      canPop: _activeChatLocation == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleOriginPopBlocked();
      },
      child: _buildMapOnlyScaffold(
        topPadding: topPadding,
        mapOverlay: _buildPersistentMapOverlay(
          topPadding,
          origin: origin,
          locationCount: locationCount,
          tabsInteractive: !_waitingForOpeningSheetExpansion,
        ),
        bottomSheetOverlayBuilder: (minChildSize) =>
            _OriginDetailDraggableSheet(
              origin: origin,
              minChildSize: minChildSize,
              collapseRequest: _detailSheetCollapseRequest,
              expandRequest: _detailSheetExpandRequest,
              requestedPage: _detailSheetRequestedPage,
              pageRequest: _detailSheetPageRequest,
              onPageChanged: _handleOriginDetailSheetPageChanged,
              autoExpansionPending: _waitingForOpeningSheetExpansion,
              onRaisedChanged: _handleDetailSheetRaisedChanged,
              onFullyExpanded: _handleOpeningSheetFullyExpanded,
              onAutoExpansionInterrupted:
                  _handleOpeningSheetExpansionInterrupted,
              onOriginChanged: _refreshOriginDetail,
              launching: _launching,
              profileRole: _cachedProfileRole,
              onSelectRole: (character) =>
                  _selectAndLaunchPresetRole(origin, character),
              onSelectProfileRole: (profileRole) =>
                  _selectAndLaunchProfileRole(origin, profileRole),
              onEditProfileRole: () => _showLaunchRoleSheet(
                origin,
                initialCustomTab: true,
                fillProfileOnOpen: true,
              ),
              onCustomizeRole: () =>
                  _showLaunchRoleSheet(origin, initialCustomTab: true),
              onLaunch: () => _showLaunchRoleSheet(origin),
            ),
        topOverlay: _buildLocationChatOverlay(origin),
        map: WorldKeepAlivePage(child: map),
      ),
    );
  }

  void _handleDetailSheetRaisedChanged(bool raised) {
    if (!mounted || _detailSheetRaisedNotifier.value == raised) return;
    _detailSheetRaisedNotifier.value = raised;
  }

  void _handleOpeningSheetFullyExpanded() {
    if (!mounted || !_waitingForOpeningSheetExpansion) return;
    setState(() => _waitingForOpeningSheetExpansion = false);
  }

  void _handleOpeningSheetExpansionInterrupted() {
    if (!mounted || !_waitingForOpeningSheetExpansion) return;
    setState(() => _waitingForOpeningSheetExpansion = false);
  }
}
