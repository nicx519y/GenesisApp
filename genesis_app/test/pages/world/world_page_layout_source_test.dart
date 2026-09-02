import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';

void main() {
  final worldPageSource = File('lib/pages/world/world_page.dart');
  final worldPageRootSource = worldPageSource.readAsStringSync();
  final worldPageLayoutSource = File(
    'lib/pages/world/world_page_layout.dart',
  ).readAsStringSync();
  final worldPageDetailSyncSource = File(
    'lib/pages/world/world_page_detail_sync.dart',
  ).readAsStringSync();
  final worldPageTickFlowSource = File(
    'lib/pages/world/world_page_tick_flow.dart',
  ).readAsStringSync();
  final worldPageSheetsSource = File(
    'lib/pages/world/world_page_sheets.dart',
  ).readAsStringSync();
  final worldPageImplementationSource =
      [
            worldPageRootSource,
            'lib/pages/world/world_page_tabs.dart',
            'lib/pages/world/world_page_chatroom_session.dart',
            'lib/pages/world/world_page_detail_sync.dart',
            'lib/pages/world/world_page_tick_flow.dart',
            'lib/pages/world/world_page_location_chat.dart',
            'lib/pages/world/world_page_sheets.dart',
            'lib/pages/world/world_page_layout.dart',
          ]
          .map((source) {
            if (source == worldPageRootSource) return source;
            return File(source).readAsStringSync();
          })
          .join('\n');
  final worldHeaderSource = File('lib/pages/world/world_header.dart');
  final worldDetailsShellSource = File(
    'lib/components/world_details_shell.dart',
  ).readAsStringSync();
  final worldMapSource = File(
    'lib/components/legacy_world_map/legacy_world_map_background.dart',
  );
  final worldBottomSheetSource = File(
    'lib/pages/world/world_bottom_sheet.dart',
  );
  final originWorldPageSource = File('lib/pages/origin/origin_world_page.dart');
  final worldModelsSource = File('lib/pages/world/world_models.dart');
  final worldConstantsSource = File(
    'lib/pages/world/world_constants.dart',
  ).readAsStringSync();
  final worldSectionsSource = [
    'lib/pages/world/world_sections.dart',
    'lib/pages/world/world_sections_loading_detail.dart',
    'lib/pages/world/world_sections_events.dart',
    'lib/pages/world/world_sections_tick_cards.dart',
    'lib/pages/world/world_sections_characters.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');
  final worldLocationChatSource = File(
    'lib/pages/world/world_location_chat_host.dart',
  );

  String allWorldSource() {
    return Directory('lib/pages/world')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
  }

  test('world page keeps only page shell and delegates modules', () {
    final source = worldPageRootSource;

    expect(source, contains('class WorldPage extends StatefulWidget'));
    expect(source, contains('class _WorldPageState'));
    expect(source, contains('WorldDetailsPageScaffold('));
    expect(source, contains('WorldBottomTags('));
    expect(source, contains('WorldLocationChatRouterHost('));
    expect(source, isNot(contains('class WorldSingleSectionBottomSheet')));
    expect(source, isNot(contains('class WorldEventsSection')));
    expect(source, isNot(contains('class WorldLocationChatPageCache')));
  });

  test('world loading shell keeps the settled panel geometry', () {
    final source = worldPageLayoutSource;
    final loadingShell = source.substring(
      source.indexOf('Widget _buildInitialLoadingScaffold'),
      source.indexOf('Widget _buildPersistentMapOverlay'),
    );

    expect(
      loadingShell,
      contains(
        'final collapsedPanelHeight = worldCollapsedPanelHeightFor(\n'
        '      context,\n'
        '      world: world,\n'
        '      assumeLaunched: true,\n'
        '    );',
      ),
    );
    expect(
      loadingShell,
      contains('const infoHeaderHeight = worldLaunchedInfoHeaderHeight;'),
    );
    expect(loadingShell, contains('useCompactAction: true'));
    expect(
      loadingShell,
      contains('fixedCollapsedPanelHeight: collapsedPanelHeight'),
    );
    expect(
      loadingShell,
      contains('fixedCollapsedPanelHeightIncludesBottomSafeArea: true'),
    );
    expect(loadingShell, contains('contentBottomPaddingOverride: 0'));
    expect(loadingShell, contains("'world-map-loading-background'"));
    expect(loadingShell, contains('_tilemapLoadingBackgroundColor'));
    expect(loadingShell, contains('_buildWorldBottomTagsOverlay('));
    expect(loadingShell, contains('interactive: false'));
    expect(loadingShell, isNot(contains('map: WorldMap(')));
  });

  test('world map owns identity while collapsed panel keeps only actions', () {
    final source = allWorldSource();
    final headerSource = worldHeaderSource.readAsStringSync();
    final bottomHeader = headerSource.substring(
      headerSource.indexOf('class WorldInfoHeader'),
      headerSource.indexOf('IconData? worldCounterIcon'),
    );

    expect(headerSource, contains('class WorldMapIdentityPill'));
    expect(worldPageImplementationSource, contains('WorldMapIdentityPill('));
    expect(source, contains('LayoutBuilder'));
    expect(source, contains('maxIdentityWidth'));
    expect(source, isNot(contains('maxWidth: 240')));
    expect(bottomHeader, isNot(contains('GenesisPairedMetaRow')));
    expect(bottomHeader, isNot(contains('GenesisMoreActionMenuButton')));
    expect(bottomHeader, isNot(contains('worldTitleTextStyle')));
    expect(bottomHeader, contains('StatItem'));
    expect(bottomHeader, contains('GenesisPrimaryButton'));
  });

  test('world map top overlay does not expose a separate Model entry', () {
    final source = worldPageLayoutSource;
    final overlayStart = source.indexOf('Widget _buildPersistentMapOverlay(');
    final overlay = source.substring(overlayStart, source.length);

    expect(overlay, isNot(contains('MemoryModelEntryButton(')));
    expect(source, isNot(contains('RouteNames.memoryModel')));
  });

  test('world bottom tags open single-section sheets', () {
    final source = allWorldSource();
    final bottomSheet = worldBottomSheetSource.readAsStringSync();
    final models = worldModelsSource.readAsStringSync();
    final tags = models.substring(models.indexOf('const worldBottomTagItems'));
    final bottomTags = bottomSheet.substring(
      bottomSheet.indexOf('class WorldBottomTags'),
      bottomSheet.indexOf('class WorldBottomTagContent'),
    );
    final bottomTagContent = bottomSheet.substring(
      bottomSheet.indexOf('class WorldBottomTagContent'),
      bottomSheet.indexOf('class WorldSingleSectionBottomSheet'),
    );
    final eventsSectionBuilder = bottomSheet.substring(
      bottomSheet.indexOf('Widget _buildEventsSectionPage('),
      bottomSheet.indexOf('Widget _buildStatusSectionPage('),
    );
    final locationsSectionBuilder = bottomSheet.substring(
      bottomSheet.indexOf('Widget _buildLocationsSectionPage('),
      bottomSheet.indexOf('Widget _buildDetailSectionPage('),
    );
    final singleSectionSheet = bottomSheet.substring(
      bottomSheet.indexOf('class WorldSingleSectionBottomSheet'),
      bottomSheet.indexOf('class WorldSingleSectionSheetHeader'),
    );
    final sheetHeader = bottomSheet.substring(
      bottomSheet.indexOf('class WorldSingleSectionSheetHeader'),
      bottomSheet.indexOf('class WorldSheetPageIndicator'),
    );
    final sectionListView = worldSectionsSource.substring(
      worldSectionsSource.indexOf('class WorldSectionListView'),
      worldSectionsSource.indexOf('class WorldEventsSection'),
    );

    expect(tags, contains("label: 'Locations'"));
    expect(tags, contains("label: 'Detail'"));
    expect(tags, contains('worldDetailIconAsset'));
    expect(tags, contains("label: 'Events'"));
    expect(
      worldConstantsSource,
      contains('assets/custom-icons/svg/events.svg'),
    );
    expect(tags, contains("label: 'Status'"));
    expect(tags, isNot(contains("label: 'Cast'")));
    expect(tags, isNot(contains("label: 'Map'")));
    expect(bottomTags, contains('Color(0xFFFFFFFF)'));
    expect(bottomTags, contains('alignment: Alignment.centerLeft'));
    expect(bottomTags, isNot(contains('alignment: Alignment.center,')));
    expect(bottomTags, contains('physics: const ClampingScrollPhysics()'));
    expect(bottomTags, contains('overscroll: false'));
    expect(eventsSectionBuilder, contains('ScrollConfiguration'));
    expect(eventsSectionBuilder, contains('overscroll: false'));
    expect(
      eventsSectionBuilder,
      contains('scrollController: scrollController'),
    );
    expect(locationsSectionBuilder, contains('ScrollConfiguration'));
    expect(locationsSectionBuilder, contains('overscroll: false'));
    expect(locationsSectionBuilder, contains('controller: scrollController'));
    expect(eventsSectionBuilder, contains('worldSheetVisibleContentTopGap'));
    expect(
      locationsSectionBuilder,
      contains('worldSheetVisibleContentTopGap - 5'),
    );
    expect(singleSectionSheet, contains('Expanded('));
    expect(
      singleSectionSheet,
      contains('_buildSheetContent(scrollController)'),
    );
    expect(singleSectionSheet, contains('DraggableScrollableSheet('));
    expect(
      singleSectionSheet,
      contains('_buildSheetPage(kind, scrollController)'),
    );
    expect(singleSectionSheet, contains('snap: false'));
    expect(singleSectionSheet, contains('shouldCloseOnMinExtent: false'));
    expect(singleSectionSheet, contains('onPointerUp: _handleSheetPointerEnd'));
    expect(
      singleSectionSheet,
      contains('onPointerCancel: _handleSheetPointerEnd'),
    );
    expect(singleSectionSheet, contains('worldCollapsedPanelHeightFor('));
    expect(singleSectionSheet, contains('_collapseSnapThreshold = 0.5'));
    expect(
      singleSectionSheet,
      isNot(contains('GenesisBottomSheetDragDismissArea(')),
    );
    expect(singleSectionSheet, isNot(contains('PointerDownEvent')));
    expect(singleSectionSheet, contains('ScrollConfiguration('));
    expect(singleSectionSheet, contains('overscroll: false'));
    expect(singleSectionSheet, contains('borderRadius: GenesisRadii.sheet'));
    expect(sheetHeader, contains('item.kind != WorldBottomSheetKind.detail'));
    expect(sectionListView, contains('physics: const ClampingScrollPhysics()'));
    expect(sectionListView, contains('worldSheetVisibleContentTopGap'));
    expect(sectionListView, contains('ListView.builder('));
    expect(source, isNot(contains('EdgeInsets.fromLTRB(24, 14, 24, 32)')));
    expect(bottomTags, isNot(contains('TabBar(')));
    expect(source, contains('_openWorldBottomSheet('));
    expect(source, contains('enableDrag: false'));
    expect(bottomTagContent, contains('Color(0xFFEBEFF2)'));
    expect(bottomTagContent, contains('Color(0xFF666666)'));
    expect(
      bottomTagContent,
      contains('borderRadius: BorderRadius.circular(12)'),
    );
    expect(source, contains('class WorldSingleSectionBottomSheet'));
    expect(source, contains('class WorldSingleSectionSheetHeader'));
    expect(sheetHeader, isNot(contains('onVerticalDragEnd')));
    expect(sheetHeader, isNot(contains('GestureDetector')));
    expect(source, contains('top: 5'));
    expect(source, contains('fontSize: 16'));
    expect(source, contains('fontWeight: FontWeight.w600'));
    expect(source, contains('minimumSize: const Size(28, 28)'));
    expect(source, isNot(contains('WorldSectionsSheetTabs')));
  });

  test('world detail includes cast content below the brief', () {
    final sections = worldSectionsSource;
    final detailSection = sections.substring(
      sections.indexOf('class WorldDetailSection'),
      sections.indexOf('class WorldDetailSectionTitle'),
    );
    final briefIndex = detailSection.indexOf("title: 'World Brief'");
    final castIndex = detailSection.indexOf('WorldCharactersSection(');

    expect(detailSection, contains('final String currentUid;'));
    expect(castIndex, greaterThan(briefIndex));
    expect(detailSection, isNot(contains('worldSectionCastIconAsset')));
    expect(detailSection, isNot(contains('MyFlutterApp.eye')));
    expect(detailSection, contains('currentUid: currentUid'));
    expect(detailSection, contains("label: 'Invite'"));
    expect(detailSection, contains('width: 92'));
    expect(detailSection, contains('height: 34'));
    expect(detailSection, contains('fontSize: 14'));
    expect(detailSection, contains('Color(0xFFFF2442)'));
    expect(detailSection, contains('Clipboard.setData'));
    expect(detailSection, contains('Link copied. Share it with your friends.'));
    expect(
      detailSection,
      contains("WorldDetailSectionTitle(title: 'World Brief')"),
    );
    expect(detailSection, contains("WorldDetailSectionTitle(title: 'Cast')"));
    expect(
      detailSection,
      contains(
        'if (showCharacters)\n'
        '          WorldCharactersSection',
      ),
    );
    expect(sections, contains('class WorldDetailSectionListView'));
    expect(sections, contains('WorldSectionListView.builder('));
    expect(sections, contains('showCharacters: false'));
    expect(
      detailSection,
      contains("key: const ValueKey<String>('world-detail-basic-info')"),
    );
    expect(detailSection, contains('WorldDetailCoverImage(url: cover)'));
    expect(detailSection, contains('const SizedBox(width: 14)'));
    expect(detailSection, contains('fontSize: 16'));
    expect(detailSection, contains("label: 'WID'"));
    expect(detailSection, contains("text: 'Owner: \$owner'"));
    expect(
      detailSection,
      contains('trailingIconSize: genesisCopyableIdIconSize'),
    );
    expect(
      detailSection.indexOf('WorldDetailCoverImage(url: cover)'),
      lessThan(briefIndex),
    );
  });

  test('world cast subtitle uses readable body sizing', () {
    final sections = worldSectionsSource;
    final characterRow = sections.substring(
      sections.indexOf('class WorldCharacterRow'),
      sections.indexOf('String worldResizedCharacterAvatarUrl'),
    );

    expect(characterRow, contains('fontSize: 13'));
    expect(characterRow, contains('maxLines: 4'));
    expect(characterRow, contains('Color(0xFFFF2442)'));
    expect(characterRow, contains('height: 1.4'));
    expect(characterRow, contains('SizedBox(height: 5)'));
    expect(characterRow, contains('SizedBox(width: 14)'));
    expect(characterRow, isNot(contains('isCharacterRole ? 6 : 0')));
    expect(characterRow, contains("const ['brief']"));
    expect(characterRow, isNot(contains('personality')));
    expect(characterRow, contains('if (showCharacterDetails)'));
  });

  test('world cast subtitle includes brief for AI and player roles', () {
    expect(
      worldCharacterDescriptionText(const {
        'player_uid': '',
        'identity': 'Archivist',
        'brief': 'Keeps every forgotten story indexed',
        'goal': 'Protect the archive',
      }),
      'Archivist\nKeeps every forgotten story indexed\nGoal: Protect the archive',
    );
    expect(
      worldCharacterDescriptionText(const {
        'player_uid': 'user_1',
        'identity': 'Visitor',
        'brief': 'Travels between unfinished worlds',
        'goal': 'Should stay hidden',
      }),
      'Visitor\nTravels between unfinished worlds',
    );
    expect(
      worldCharacterDescriptionText(const {'player_uid': 'user_1'}),
      isEmpty,
    );
  });

  test('world invite copy highlights world name and wid', () {
    expect(
      worldInviteShareTextForTesting(worldName: 'Dream Bazaar', wid: 'w_123'),
      'Join my world "Dream Bazaar" on Worldo!\n'
      'w_123\n'
      'Search this WID on Worldo to find and join.\n'
      'https://worldo.ai/download',
    );
    expect(
      worldInviteShareTextForTesting(worldName: '', wid: 'w_empty'),
      'Join my world "w_empty" on Worldo!\n'
      'w_empty\n'
      'Search this WID on Worldo to find and join.\n'
      'https://worldo.ai/download',
    );
  });

  test('world bottom sheet supports horizontal page switching', () {
    final bottomSheet = worldBottomSheetSource.readAsStringSync();
    final singleSectionSheet = bottomSheet.substring(
      bottomSheet.indexOf('class WorldSingleSectionBottomSheet'),
      bottomSheet.indexOf('class WorldSingleSectionSheetHeader'),
    );

    expect(singleSectionSheet, contains('PageController'));
    expect(singleSectionSheet, contains('PageView.builder'));
    expect(singleSectionSheet, contains('_kindForPage'));
    expect(singleSectionSheet, contains('_pageForKind'));
    expect(singleSectionSheet, contains('_handleSheetPageChanged'));
    expect(singleSectionSheet, contains('_animateToSelectionPage'));
  });

  test('world detail cover uses static network image', () {
    final sections = worldSectionsSource;
    final cover = sections.substring(
      sections.indexOf('class WorldDetailCoverImage'),
      sections.indexOf('class WorldStatusSection'),
    );

    expect(cover, contains('GenesisStaticNetworkImage('));
    expect(cover, contains('static const double width = 120'));
    expect(cover, contains('static const double height = 180'));
    expect(cover, contains("ValueKey<String>('world-detail-cover')"));
    expect(cover, isNot(contains('Image.network(')));
  });

  test('world map bubbles are derived from chatroom state', () {
    final source = worldPageImplementationSource;

    expect(source, contains('worldMapBubbleCandidatesFor('));
    expect(source, contains('final preparingInitialTilemap ='));
    expect(
      source,
      matches(
        RegExp(
          r'messageBubbles:\s+\(_activeChatLocationId\.isEmpty \|\|\s+'
          r'preparingInitialTilemap\)',
        ),
      ),
    );
    expect(source, contains('_mapBubbleMessagesReady'));
    expect(source, contains('_mapMessageBubbles'));
    expect(
      source,
      matches(
        RegExp(r'messageBubblePlaybackPaused:\s+mapPausedForLocationChat'),
      ),
    );
    expect(
      source,
      contains(
        'final mapPausedForLocationChat =\n'
        '          _activeChatLocationId.isNotEmpty && '
        '!preparingInitialTilemap;',
      ),
    );
    expect(source, isNot(contains('destroyTilemapForLocationChat')));
    expect(
      source,
      isNot(contains("'world-tilemap-destroyed-for-location-chat'")),
    );
    expect(
      source,
      matches(
        RegExp(
          r'animationsPaused:\s*'
          r'_worldBottomSheetOpen \|\| mapPausedForLocationChat',
        ),
      ),
    );
    expect(
      source,
      contains(
        'final _tilemapRestorationController = '
        'TilemapRestorationController();',
      ),
    );
    expect(
      source,
      contains('restorationController: _tilemapRestorationController,'),
    );
    expect(source, isNot(contains('TickerMode(')));
    expect(source, isNot(contains('messageBubbleIndex:')));
    expect(source, isNot(contains('messageBubbleVisible:')));
    expect(source, isNot(contains('WorldMapBubbleCoordinator')));
  });

  test('world sheet coalesces background map chatroom updates', () {
    final chatroom = File(
      'lib/pages/world/world_page_chatroom_session.dart',
    ).readAsStringSync();
    final sheets = worldPageSheetsSource;

    expect(chatroom, contains('_deferredBottomSheetMapChatroomState = state'));
    expect(chatroom, contains('if (deferMapVisuals)'));
    expect(chatroom, contains('_sameMapBubbleCandidates('));
    expect(chatroom, isNot(contains('_sameRecentChatLocationSelection(')));
    expect(sheets, contains('_applyDeferredBottomSheetMapChatroomState();'));
  });

  test('map updates preload current Tilemap while location chat is open', () {
    final chatroom = File(
      'lib/pages/world/world_page_chatroom_session.dart',
    ).readAsStringSync();

    expect(
      chatroom,
      contains('_prefetchTilemapUpdateForLocationChat(currentWorld);'),
    );
    expect(chatroom, contains('world.definitionVersion != 2'));
    expect(chatroom, contains('_activeChatLocationId.isEmpty'));
    expect(
      chatroom,
      contains('_tilemapRestorationController.prefetchWorldMapUpdate('),
    );
    expect(chatroom, contains('drillableLocationIds:'));
  });

  test('world sheet caches location projection inputs', () {
    final bottomSheet = worldBottomSheetSource.readAsStringSync();
    final locationBuilder = bottomSheet.substring(
      bottomSheet.indexOf(
        'WorldLocationListData _locationListDataForCurrentWorld()',
      ),
      bottomSheet.indexOf('Widget _buildDetailSectionPage('),
    );

    expect(locationBuilder, contains('identical(_cachedProcessedLocationTree'));
    expect(locationBuilder, contains('identical(_cachedCharacterPositions'));
    expect(locationBuilder, contains('worldLocationListDataFor('));
  });

  test('world keyboard metrics do not rebuild the covered map', () {
    final headerSource = worldHeaderSource.readAsStringSync();
    final bottomSafeArea = headerSource.substring(
      headerSource.indexOf('double worldBottomSafeAreaOf'),
      headerSource.indexOf('IconData? worldCounterIcon'),
    );
    final detailsBottomSafeArea = worldDetailsShellSource.substring(
      worldDetailsShellSource.indexOf('double _bottomSafeAreaOf'),
      worldDetailsShellSource.indexOf(
        'class WorldDetailsPanelScrollControllerScope',
      ),
    );

    expect(
      worldPageDetailSyncSource,
      contains('MediaQuery.devicePixelRatioOf(context)'),
    );
    expect(
      worldPageDetailSyncSource,
      isNot(contains('MediaQuery.maybeOf(context)')),
    );
    expect(bottomSafeArea, contains('GenesisSafeAreaInsets.bottom(context)'));
    expect(bottomSafeArea, isNot(contains('MediaQuery.of(context)')));
    expect(
      detailsBottomSafeArea,
      contains('GenesisSafeAreaInsets.bottom(context)'),
    );
    expect(detailsBottomSafeArea, isNot(contains('MediaQuery.of(context)')));
  });

  test('image precaches handle failures with onError', () {
    final worldMap = worldMapSource.readAsStringSync();
    final worldPage = worldPageDetailSyncSource;
    final originWorldPage = originWorldPageSource.readAsStringSync();
    final preloadSecondaryImages = worldMap.substring(
      worldMap.indexOf('Future<void> _preloadSecondaryImages'),
      worldMap.indexOf('ImageProvider _mapImageProvider'),
    );
    final progressWaitAvatarPrecache = worldPage.substring(
      worldPage.indexOf('void _precacheProgressWaitAvatarImages'),
      worldPage.indexOf('String _rootMapImageUrlForWorld'),
    );
    final launchWaitAvatarPrecache = originWorldPage.substring(
      originWorldPage.indexOf('void _precacheLaunchWaitAvatarImages'),
      originWorldPage.indexOf('bool _sameWaitAvatars'),
    );

    expect(
      preloadSecondaryImages,
      contains('onError: (exception, stackTrace)'),
    );
    expect(
      preloadSecondaryImages,
      isNot(contains('precacheImage(_mapImageProvider(url), context)')),
    );
    expect(
      preloadSecondaryImages,
      isNot(contains('precacheImage(_avatarImageProvider(url), context)')),
    );
    expect(
      progressWaitAvatarPrecache,
      contains('onError: (exception, stackTrace)'),
    );
    expect(
      progressWaitAvatarPrecache,
      contains(').catchError((Object error, StackTrace stackTrace)'),
    );
    expect(
      launchWaitAvatarPrecache,
      contains('unawaited(_precacheOriginAvatarFile(resolvedUrl))'),
    );
    expect(launchWaitAvatarPrecache, contains('catch (error)'));
  });

  test('world tick completion closes other sheets before opening events', () {
    final tickDone = worldPageTickFlowSource.substring(
      worldPageTickFlowSource.indexOf('Future<void> _handleWorldTickDone()'),
      worldPageTickFlowSource.indexOf('void _showOrSelectEventsAfterTick()'),
    );
    final showOrSelectEvents = worldPageTickFlowSource.substring(
      worldPageTickFlowSource.indexOf('void _showOrSelectEventsAfterTick()'),
      worldPageTickFlowSource.indexOf('void _markWorldTickIdle()'),
    );
    final suppressAutoEvents = worldPageTickFlowSource.substring(
      worldPageTickFlowSource.indexOf(
        'bool get _shouldSuppressAutoEventsAfterTick',
      ),
      worldPageTickFlowSource.indexOf('void _showOrSelectEventsAfterTick()'),
    );
    final openBottomSheet = worldPageSheetsSource.substring(
      worldPageSheetsSource.indexOf('void _openWorldBottomSheet('),
      worldPageSheetsSource.indexOf(
        'Future<void> _confirmAndDeleteWorldFromDetail(',
      ),
    );

    expect(tickDone, contains('_showOrSelectEventsAfterTick();'));
    expect(tickDone, contains('!_shouldSuppressAutoEventsAfterTick'));
    expect(suppressAutoEvents, contains('_activeChatLocationId.isNotEmpty'));
    expect(
      suppressAutoEvents,
      contains('_locationChatPageCache.activeLocationId.isNotEmpty'),
    );
    expect(suppressAutoEvents, contains('!route.isCurrent'));
    expect(showOrSelectEvents, contains('_worldBottomSheetOpen'));
    expect(
      showOrSelectEvents,
      contains('_worldBottomSheetSelection.value.kind !='),
    );
    expect(showOrSelectEvents, contains('WorldBottomSheetKind.events'));
    expect(
      showOrSelectEvents,
      contains('_openEventsAfterCurrentBottomSheetClosed = true'),
    );
    expect(
      showOrSelectEvents,
      contains('Navigator.of(sheetContext).maybePop()'),
    );
    expect(showOrSelectEvents, contains('scrollEventsToLatest: true'));
    expect(
      showOrSelectEvents,
      contains('eventsTargetTickNumber: _world?.tickCount'),
    );
    expect(openBottomSheet, contains('_worldBottomSheetSelection.value'));
    expect(openBottomSheet, contains('if (_worldBottomSheetOpen) return;'));
    expect(
      openBottomSheet,
      contains(
        'if (openEvents && mounted && !_shouldSuppressAutoEventsAfterTick)',
      ),
    );
    expect(openBottomSheet, contains('showModalBottomSheet<void>'));
  });

  test('world events force refreshes and releases stale target', () {
    final bottomSheet = worldBottomSheetSource.readAsStringSync();
    final sections = worldSectionsSource;
    final ensureEvents = bottomSheet.substring(
      bottomSheet.indexOf('void _ensureEventsForCurrentWorld'),
      bottomSheet.indexOf('void _mutateEventsCache'),
    );
    final loadEvents = bottomSheet.substring(
      bottomSheet.indexOf('Future<void> _loadEventsPage('),
      bottomSheet.indexOf('Widget _buildEventsSectionPage('),
    );
    final eventsSectionState = sections.substring(
      sections.indexOf('class WorldEventsSectionState'),
      sections.indexOf('class WorldTickPendingEventPage'),
    );
    final setCurrentPage = sections.substring(
      sections.indexOf(
        'bool _setCurrentPageToRequestedTargetOrLatestIfAvailable',
      ),
      sections.indexOf('void _jumpToCurrentPage()'),
    );

    expect(
      ensureEvents,
      contains('unawaited(_loadEventsPage(1, force: true))'),
    );
    expect(loadEvents, contains('{bool force = false}'));
    expect(
      loadEvents,
      contains('if (_eventsCache.initialLoading && !force) return;'),
    );
    expect(loadEvents, contains('worldId != _eventsCache.worldId'));
    expect(bottomSheet, contains('if (_eventsCache.page <= 0) return true;'));
    expect(
      bottomSheet,
      contains(
        'return _eventsCache.page * _eventsPageSize < _eventsCache.total',
      ),
    );
    expect(setCurrentPage, contains('final resolvedTargetPage'));
    expect(setCurrentPage, contains('final pendingTargetPage'));
    expect(
      setCurrentPage,
      isNot(contains('??\n          _insertionPageForTickNumber')),
    );
    expect(eventsSectionState, contains('final hasPendingTargetPage'));
    expect(
      eventsSectionState,
      isNot(contains('final hasRequestedTickPage = _requestedTickNumber')),
    );
  });

  test('world events group sub ticks into one tick-number page', () {
    final merged = worldMergeEventTicksAscending(
      const [
        {'tick_no': 4, 'sub_tick_no': 2, 'tick_result': <String, dynamic>{}},
        {'tick_no': 3, 'sub_tick_no': 1, 'tick_result': <String, dynamic>{}},
      ],
      const [
        {'tick_no': 4, 'sub_tick_no': 1, 'tick_result': <String, dynamic>{}},
      ],
    );
    final pages = worldEventTickPagesAscending(merged);

    expect(merged, hasLength(3));
    expect(pages, hasLength(2));
    expect(pages.first.map(worldEventTickNumber), [3]);
    expect(pages.last.map(worldEventTickNumber), [4, 4]);
    expect(pages.last.map(worldEventSubTickNumber), [1, 2]);
    expect(worldEventTickPageIdentity(pages.last), 'tick:4');

    final eventsSection = worldSectionsSource.substring(
      worldSectionsSource.indexOf('class WorldEventsSectionState'),
      worldSectionsSource.indexOf('class WorldTickPendingEventPage'),
    );
    expect(eventsSection, contains('final ticks = visibleTickPages'));
    expect(
      eventsSection,
      contains('subTickNumber: worldEventSubTickNumber(tick)'),
    );
  });

  test('world events group tick zero sub ticks into one page', () {
    final pages = worldEventTickPagesAscending(const [
      {
        'tick_id': 'tick_0_2',
        'tick_no': 0,
        'sub_tick_no': 2,
        'tick_result': <String, dynamic>{},
      },
      {
        'tick_id': 'tick_0_0',
        'tick_no': 0,
        'sub_tick_no': 0,
        'tick_result': <String, dynamic>{},
      },
      {
        'tick_id': 'tick_0_1',
        'tick_no': 0,
        'sub_tick_no': 1,
        'tick_result': <String, dynamic>{},
      },
    ]);

    expect(pages, hasLength(1));
    expect(pages.single.map(worldEventTickNumber), [0, 0, 0]);
    expect(pages.single.map(worldEventSubTickNumber), [0, 1, 2]);
    expect(worldEventTickPageIdentity(pages.single), 'tick:0');
  });

  test('world tick edge pull ignores stale pointer callbacks', () {
    final sections = worldSectionsSource;
    final tickCardState = sections.substring(
      sections.indexOf('class WorldTickEventCardPageState'),
      sections.indexOf('class WorldTickCardScrollPhysics'),
    );
    final setEdgePullDistance = tickCardState.substring(
      tickCardState.indexOf('void _setEdgePullDistance'),
      tickCardState.indexOf('Widget _buildEdgeArrow'),
    );

    expect(tickCardState, contains('void _handlePointerMove'));
    expect(setEdgePullDistance, contains('if (!mounted) return;'));
    expect(
      setEdgePullDistance.indexOf('if (!mounted) return;'),
      lessThan(setEdgePullDistance.indexOf('setState(()')),
    );
  });

  test('location chat code lives outside world page', () {
    final worldPage = worldPageImplementationSource;
    final locationChat = worldLocationChatSource.readAsStringSync();

    expect(locationChat, contains('class WorldLocationChatRouterHost'));
    expect(locationChat, contains('class WorldLocationChatPageCache'));
    expect(worldPage, isNot(contains('class WorldLocationChatRouterHost')));
  });
}
