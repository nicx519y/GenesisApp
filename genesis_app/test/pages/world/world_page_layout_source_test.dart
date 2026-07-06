import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';

void main() {
  final worldPageSource = File('lib/pages/world/world_page.dart');
  final worldHeaderSource = File('lib/pages/world/world_header.dart');
  final worldBottomSheetSource = File(
    'lib/pages/world/world_bottom_sheet.dart',
  );
  final worldModelsSource = File('lib/pages/world/world_models.dart');
  final worldSectionsSource = File('lib/pages/world/world_sections.dart');
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
    final source = worldPageSource.readAsStringSync();

    expect(source, contains('class WorldPage extends StatefulWidget'));
    expect(source, contains('class _WorldPageState'));
    expect(source, contains('WorldDetailsPageScaffold('));
    expect(source, contains('WorldBottomTags('));
    expect(source, contains('WorldLocationChatRouterHost('));
    expect(source, isNot(contains('class WorldSingleSectionBottomSheet')));
    expect(source, isNot(contains('class WorldEventsSection')));
    expect(source, isNot(contains('class WorldLocationChatPageCache')));
  });

  test('world map owns identity while collapsed panel keeps only actions', () {
    final source = allWorldSource();
    final headerSource = worldHeaderSource.readAsStringSync();
    final bottomHeader = headerSource.substring(
      headerSource.indexOf('class WorldInfoHeader'),
      headerSource.indexOf('IconData? worldCounterIcon'),
    );

    expect(headerSource, contains('class WorldMapIdentityPill'));
    expect(
      worldPageSource.readAsStringSync(),
      contains('WorldMapIdentityPill('),
    );
    expect(source, contains('LayoutBuilder'));
    expect(source, contains('maxIdentityWidth'));
    expect(source, isNot(contains('maxWidth: 240')));
    expect(bottomHeader, isNot(contains('GenesisPairedMetaRow')));
    expect(bottomHeader, isNot(contains('GenesisMoreActionMenuButton')));
    expect(bottomHeader, isNot(contains('worldTitleTextStyle')));
    expect(bottomHeader, contains('StatItem'));
    expect(bottomHeader, contains('GenesisPrimaryButton'));
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
      bottomSheet.indexOf('Widget _buildEventsSectionPage()'),
      bottomSheet.indexOf('Widget _buildStatusSectionPage()'),
    );
    final locationsSectionBuilder = bottomSheet.substring(
      bottomSheet.indexOf('Widget _buildLocationsSectionPage()'),
      bottomSheet.indexOf('Widget _buildDetailSectionPage()'),
    );
    final singleSectionSheet = bottomSheet.substring(
      bottomSheet.indexOf('class WorldSingleSectionBottomSheet'),
      bottomSheet.indexOf('class WorldSingleSectionSheetHeader'),
    );
    final sectionListView = worldSectionsSource.readAsStringSync().substring(
      worldSectionsSource.readAsStringSync().indexOf(
        'class WorldSectionListView',
      ),
      worldSectionsSource.readAsStringSync().indexOf(
        'class WorldEventsSection',
      ),
    );

    expect(tags, contains("label: 'Locations'"));
    expect(tags, contains("label: 'Detail'"));
    expect(tags, contains('worldDetailIconAsset'));
    expect(tags, contains("label: 'Events'"));
    expect(tags, contains("label: 'Status'"));
    expect(tags, isNot(contains("label: 'Cast'")));
    expect(tags, isNot(contains("label: 'Map'")));
    expect(bottomTags, contains('Color(0xFFFFFFFF)'));
    expect(bottomTags, contains('physics: const ClampingScrollPhysics()'));
    expect(bottomTags, contains('overscroll: false'));
    expect(eventsSectionBuilder, contains('ScrollConfiguration'));
    expect(eventsSectionBuilder, contains('overscroll: false'));
    expect(locationsSectionBuilder, contains('ScrollConfiguration'));
    expect(locationsSectionBuilder, contains('overscroll: false'));
    expect(
      eventsSectionBuilder,
      contains('EdgeInsets.fromLTRB(12, 14, 12, 32)'),
    );
    expect(
      locationsSectionBuilder,
      contains('EdgeInsets.fromLTRB(12, 14, 12, 32)'),
    );
    expect(singleSectionSheet, contains('Expanded('));
    expect(singleSectionSheet, contains('_buildDismissibleSheetContent()'));
    expect(singleSectionSheet, contains('Listener('));
    expect(
      singleSectionSheet,
      contains('NotificationListener<ScrollNotification>'),
    );
    expect(singleSectionSheet, contains('ScrollConfiguration('));
    expect(singleSectionSheet, contains('overscroll: false'));
    expect(sectionListView, contains('physics: const ClampingScrollPhysics()'));
    expect(sectionListView, contains('EdgeInsets.fromLTRB(12, 14, 12, 32)'));
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
    expect(source, contains('onVerticalDragEnd'));
    expect(source, contains('top: 5'));
    expect(source, contains('fontSize: 16'));
    expect(source, contains('fontWeight: FontWeight.w600'));
    expect(source, contains('minimumSize: const Size(28, 28)'));
    expect(source, isNot(contains('WorldSectionsSheetTabs')));
  });

  test('world detail includes cast content below the brief', () {
    final sections = worldSectionsSource.readAsStringSync();
    final detailSection = sections.substring(
      sections.indexOf('class WorldDetailSection'),
      sections.indexOf('class WorldDetailSectionTitle'),
    );
    final briefIndex = detailSection.indexOf("title: 'World Brief'");
    final castIndex = detailSection.indexOf('WorldCharactersSection(');

    expect(detailSection, contains('final String currentUid;'));
    expect(castIndex, greaterThan(briefIndex));
    expect(detailSection, contains('asset: worldSectionCastIconAsset'));
    expect(detailSection, contains('iconSize: 17'));
    expect(detailSection, contains('currentUid: currentUid'));
    expect(detailSection, contains("label: 'Invite'"));
    expect(detailSection, contains('width: 140'));
    expect(detailSection, contains('height: 35'));
    expect(detailSection, contains('Color(0xFFFF2442)'));
    expect(detailSection, contains('Clipboard.setData'));
    expect(detailSection, contains('Link copied. Share it with your friends.'));
    expect(
      detailSection,
      contains(
        'WorldDetailSectionTitle(\n          asset: worldSectionCastIconAsset',
      ),
    );
    expect(
      detailSection,
      contains('const SizedBox(height: 8),\n        WorldCharactersSection'),
    );
    expect(
      detailSection,
      contains('const SizedBox(height: 4),\n        GenesisPairedMetaRow'),
    );
  });

  test('world cast subtitle uses readable body sizing', () {
    final sections = worldSectionsSource.readAsStringSync();
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
    expect(characterRow, contains('else if (showCharacterDetails)'));
  });

  test('world cast AI subtitle reads identity brief and goal', () {
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
        'brief': 'Should stay hidden',
        'goal': 'Should stay hidden',
      }),
      'Visitor',
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
    final sections = worldSectionsSource.readAsStringSync();
    final cover = sections.substring(
      sections.indexOf('class WorldDetailCoverImage'),
      sections.indexOf('class WorldStatusSection'),
    );

    expect(cover, contains('GenesisStaticNetworkImage('));
    expect(cover, isNot(contains('Image.network(')));
  });

  test('world map bubbles are derived from chatroom state', () {
    final source = worldPageSource.readAsStringSync();

    expect(source, contains('worldMapBubbleCandidatesFor('));
    expect(source, contains('messageBubbles: _activeChatLocationId.isEmpty'));
    expect(source, contains('_mapBubbleMessagesReady'));
    expect(source, contains('_mapMessageBubbles'));
    expect(
      source,
      contains('messageBubblePlaybackPaused: _activeChatLocationId.isNotEmpty'),
    );
    expect(source, isNot(contains('messageBubbleIndex:')));
    expect(source, isNot(contains('messageBubbleVisible:')));
    expect(source, isNot(contains('WorldMapBubbleCoordinator')));
  });

  test('world tick completion closes other sheets before opening events', () {
    final source = worldPageSource.readAsStringSync();
    final tickDone = source.substring(
      source.indexOf('Future<void> _handleWorldTickDone()'),
      source.indexOf('void _showOrSelectEventsAfterTick()'),
    );
    final showOrSelectEvents = source.substring(
      source.indexOf('void _showOrSelectEventsAfterTick()'),
      source.indexOf('void _markWorldTickIdle()'),
    );
    final suppressAutoEvents = source.substring(
      source.indexOf('bool get _shouldSuppressAutoEventsAfterTick'),
      source.indexOf('void _showOrSelectEventsAfterTick()'),
    );
    final openBottomSheet = source.substring(
      source.indexOf('void _openWorldBottomSheet('),
      source.indexOf('@override\n  Widget build(BuildContext context)'),
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
    final sections = worldSectionsSource.readAsStringSync();
    final ensureEvents = bottomSheet.substring(
      bottomSheet.indexOf('void _ensureEventsForCurrentWorld'),
      bottomSheet.indexOf('void _mutateEventsCache'),
    );
    final loadEvents = bottomSheet.substring(
      bottomSheet.indexOf('Future<void> _loadEventsPage('),
      bottomSheet.indexOf('Widget _buildEventsSectionPage()'),
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

  test('location chat code lives outside world page', () {
    final worldPage = worldPageSource.readAsStringSync();
    final locationChat = worldLocationChatSource.readAsStringSync();

    expect(locationChat, contains('class WorldLocationChatRouterHost'));
    expect(locationChat, contains('class WorldLocationChatPageCache'));
    expect(worldPage, isNot(contains('class WorldLocationChatRouterHost')));
  });
}
