import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/models/location_tree.dart';
import 'package:genesis_flutter_android/network/models/user_memory_settings.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_background_preloader.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/world/world_location_chat_host.dart';

void main() {
  test(
    'settings cache survives chat clearing and ends with WorldPage cache',
    () {
      final cache = WorldLocationChatPageCache();
      const settings = UserMemorySettings(
        memoryTokens: 48000,
        minMemoryTokens: 8000,
        maxMemoryTokens: 1000000,
        worldId: 'world-1',
        memoryUsedTokens: 6000,
      );
      cache.memoryModelPageCache.storeMemorySettings(settings);

      cache.clear();
      expect(cache.memoryModelPageCache.memorySettings, same(settings));

      cache.dispose();
      expect(cache.memoryModelPageCache.memorySettings, isNull);
    },
  );

  test('markReady reports true only for the first ready notification', () {
    final cache = WorldLocationChatPageCache();
    cache.syncDescriptors(const {
      'loc_1': WorldLocationChatPanelDescriptor(
        locationId: 'loc_1',
        locationName: 'Location',
        backgroundImageUrl: '',
        backgroundPreviewImageUrl: '',
        isLeafLocation: true,
      ),
    });

    cache.activate(cache.descriptorFor('loc_1')!);
    expect(cache.isReady('loc_1'), isFalse);
    expect(cache.markReady('loc_1'), isTrue);
    expect(cache.isReady('loc_1'), isTrue);
    expect(cache.markReady('loc_1'), isFalse);
  });

  WorldLocationChatPanelDescriptor descriptor(String id) =>
      WorldLocationChatPanelDescriptor(
        locationId: id,
        locationName: id,
        backgroundImageUrl: 'https://cdn.example.com/$id.webp',
        backgroundPreviewImageUrl: '',
        isLeafLocation: true,
      );

  test('panels are lazy, bounded by recency, and preserve evicted drafts', () {
    final cache = WorldLocationChatPageCache();
    addTearDown(cache.dispose);
    final descriptors = {for (var i = 0; i < 100; i++) '$i': descriptor('$i')};
    cache.syncDescriptors(descriptors);
    expect(cache.cachedPanelCount, 0);
    for (final id in ['0', '1', '2']) {
      cache.activate(descriptors[id]!);
      cache.markReady(id);
    }
    cache.updateDraftText('1', 'draft with @mention<character-1>');
    cache.activate(descriptors['0']!);
    cache.activate(descriptors['3']!);
    expect(cache.cachedLocationIds, ['2', '0', '3']);
    expect(cache.activeLocationId, '3');
    expect(cache.hasPanel('1'), isFalse);
    expect(cache.isReady('1'), isFalse);
    expect(cache.markReady('1'), isFalse);
    expect(cache.draftTextFor('1'), 'draft with @mention<character-1>');
    cache.syncDescriptors(descriptors);
    expect(cache.cachedLocationIds, ['2', '0', '3']);
    cache.activate(descriptors['1']!);
    expect(cache.cachedLocationIds, ['0', '3', '1']);
    expect(cache.isReady('1'), isFalse);
  });

  test(
    'cover stops queued preview downloads and resumes the current map',
    () async {
      final requested = <String>[];
      final first = Completer<void>();
      final cache = WorldLocationChatPageCache(
        backgroundPreloader: LocationChatBackgroundPreloader(
          maxConcurrent: 1,
          loadFile: (url) {
            requested.add(url);
            return requested.length == 1 ? first.future : Future<void>.value();
          },
        ),
      );
      addTearDown(cache.dispose);
      cache.syncDescriptors({
        for (final id in ['1', '2', '3']) id: descriptor(id),
      });
      cache.preloadBackgroundsForTilemap(['1', '2']);
      expect(requested, hasLength(1));
      cache.setPresentationPaused(true);
      cache.preloadBackgroundsForTilemap(['3']);
      first.complete();
      await Future<void>.delayed(Duration.zero);
      expect(requested, hasLength(1));
      cache.setPresentationPaused(false);
      await Future<void>.delayed(Duration.zero);
      expect(requested, hasLength(2));
      expect(requested.last, contains('/3.webp'));
    },
  );

  test('initial message handoff can be claimed only once', () {
    final cache = WorldLocationChatPageCache();
    final catalog = ChatMentionCatalog(
      locations: const <ChatMentionEntry>[
        ChatMentionEntry(
          id: 'loc_1',
          name: 'Location',
          type: ChatMentionType.location,
        ),
      ],
    );

    cache.queueInitialMessageToSend(
      'loc_1',
      '@Location<loc_1>',
      mentionCatalog: catalog,
    );

    expect(cache.takeInitialMessageToSend('loc_1'), '@Location<loc_1>');
    expect(cache.takeInitialMessageToSend('loc_1'), isEmpty);
    expect(cache.takeInitialMentionCatalog('loc_1'), same(catalog));
    expect(cache.takeInitialMentionCatalog('loc_1'), isNull);
  });

  test('descriptor uses the XL background URL for both CDN sizes', () {
    final descriptor = WorldLocationChatPanelDescriptor.fromNode(
      const LocationTreeNode<Map<String, dynamic>>(
        id: 'loc_1',
        parentId: '',
        value: {
          'location_id': 'loc_1',
          'location_name': 'Location',
          'image': {
            'sm_url': 'https://cdn.example.com/location-sm.webp',
            'xl_url': 'https://cdn.example.com/location-xl.webp',
          },
        },
        depth: 0,
        children: [],
      ),
    );

    expect(
      descriptor.backgroundPreviewImageUrl,
      'https://cdn.example.com/location-xl.webp',
    );
    expect(
      descriptor.backgroundImageUrl,
      'https://cdn.example.com/location-xl.webp',
    );
  });

  test('current Tilemap preloads only matching location XL previews', () async {
    final requestedUrls = <String>[];
    final cache = WorldLocationChatPageCache(
      backgroundPreloader: LocationChatBackgroundPreloader(
        loadFile: (url) async {
          requestedUrls.add(url);
        },
      ),
    );
    cache.syncDescriptors(const {
      'loc_1': WorldLocationChatPanelDescriptor(
        locationId: 'loc_1',
        locationName: 'First',
        backgroundImageUrl: 'https://cdn.example.com/location-1-xl.webp',
        backgroundPreviewImageUrl: 'https://cdn.example.com/location-1-xl.webp',
        isLeafLocation: true,
      ),
      'loc_2': WorldLocationChatPanelDescriptor(
        locationId: 'loc_2',
        locationName: 'Second',
        backgroundImageUrl: 'https://cdn.example.com/location-2-xl.webp',
        backgroundPreviewImageUrl: 'https://cdn.example.com/location-2-xl.webp',
        isLeafLocation: true,
      ),
    });

    cache.preloadBackgroundsForTilemap(const ['loc_2', 'loc_2', 'missing']);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(requestedUrls, [
      'https://cdn.example.com/location-2-xl.webp'
          '?x-oss-process=image/resize,w_180,image/format,webp',
    ]);
    cache.dispose();
  });

  testWidgets('cached world panels render a background only while displayed', (
    tester,
  ) async {
    ChatCharacterMovementVm? openedMovement;
    const first = WorldLocationChatPanelDescriptor(
      locationId: 'loc_1',
      locationName: 'First Location',
      backgroundImageUrl: 'assets/images/map_default/location_default.webp',
      backgroundPreviewImageUrl:
          'assets/images/map_default/location_default.webp',
      isLeafLocation: true,
    );
    const second = WorldLocationChatPanelDescriptor(
      locationId: 'loc_2',
      locationName: 'Second Location',
      backgroundImageUrl: 'assets/images/map_default/location_default.webp',
      backgroundPreviewImageUrl:
          'assets/images/map_default/location_default.webp',
      isLeafLocation: true,
    );
    final cache = WorldLocationChatPageCache();
    cache.syncDescriptors(const {'loc_1': first, 'loc_2': second});
    late StateSetter rebuildHost;
    var overlayDismissedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildHost = setState;
            return WorldLocationChatRouterHost(
              worldId: 'world-1',
              chatroom: null,
              cache: cache,
              onBack: () {},
              onOverlayDismissed: () => overlayDismissedCount += 1,
              onPanelReady: (_) {},
              isMessageQueueInitializationCovered: (_) => false,
              onCharactersMovedLocationTap: (movement) {
                openedMovement = movement;
              },
              animateTransitions: false,
              usePreparedEntry: true,
            );
          },
        ),
      ),
    );
    await tester.pump();

    List<LocationChatPanel> panels() => tester
        .widgetList<LocationChatPanel>(
          find.byType(LocationChatPanel, skipOffstage: false),
        )
        .toList(growable: false);

    expect(panels(), isEmpty);

    rebuildHost(() => cache.activate(first));
    await tester.pump();
    expect(panels(), hasLength(1));
    expect(panels().single.usePreparedEntry, true);
    final firstState = tester.state(
      find.byKey(const ValueKey<String>('world-location-chat-loc_1')),
    );
    expect(cache.isReady('loc_1'), false);
    final firstPanel = find.byKey(
      const ValueKey<String>('world-location-chat-loc_1'),
    );
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: firstPanel, matching: find.byType(Opacity)).first,
          )
          .opacity,
      1,
      reason: 'The actual chat page is visible before a readiness callback',
    );

    expect(
      panels()
          .where((panel) => panel.renderBackgroundImage)
          .map((panel) => panel.locationId),
      ['loc_1'],
    );

    rebuildHost(() => cache.activate(second));
    await tester.pump();

    expect(
      panels()
          .where((panel) => panel.renderBackgroundImage)
          .map((panel) => panel.locationId),
      ['loc_2'],
    );
    expect(
      tester.state(
        find.byKey(
          const ValueKey<String>('world-location-chat-loc_1'),
          skipOffstage: false,
        ),
      ),
      same(firstState),
    );
    expect(panels(), hasLength(2));
    panels()
        .singleWhere((panel) => panel.locationId == 'loc_2')
        .onCharactersMovedLocationTap!(
      const ChatCharacterMovementVm(
        characterId: 'char_1',
        characterName: 'Character',
        toLocationId: 'loc_1',
        toLocationName: 'First Location',
      ),
    );
    expect(openedMovement?.toLocationId, 'loc_1');

    // Reordering an LRU entry must preserve the actual keyed page State.
    rebuildHost(() => cache.activate(first));
    await tester.pump();
    expect(
      tester.state(find.byKey(const ValueKey('world-location-chat-loc_1'))),
      same(firstState),
    );
    final draftInput = find.descendant(
      of: find.byKey(const ValueKey('world-location-chat-loc_1')),
      matching: find.byType(TextField),
    );
    tester.widget<TextField>(draftInput).controller!.text = 'retained draft';
    await tester.pump();
    rebuildHost(() => cache.activate(second));
    await tester.pump();
    rebuildHost(() => cache.activate(first.copyWith(locationId: 'loc_3')));
    await tester.pump();
    rebuildHost(() => cache.activate(first.copyWith(locationId: 'loc_4')));
    await tester.pump();
    expect(panels(), hasLength(3));
    expect(firstState.mounted, isFalse);
    expect(cache.draftTextFor('loc_1'), 'retained draft');
    rebuildHost(() => cache.activate(first));
    await tester.pump();
    expect(panels(), hasLength(3));
    final restored = panels().singleWhere((p) => p.locationId == 'loc_1');
    expect(restored.initialDraftText, 'retained draft');
    expect(
      tester.state(find.byKey(const ValueKey('world-location-chat-loc_1'))),
      isNot(same(firstState)),
    );

    rebuildHost(cache.deactivate);
    await tester.pump();
    await tester.pump();
    expect(overlayDismissedCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
