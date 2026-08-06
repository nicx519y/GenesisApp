import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/models/location_tree.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_background_preloader.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/world/world_location_chat_host.dart';

void main() {
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

    expect(cache.isReady('loc_1'), isFalse);
    expect(cache.markReady('loc_1'), isTrue);
    expect(cache.isReady('loc_1'), isTrue);
    expect(cache.markReady('loc_1'), isFalse);
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
              onPanelReady: (_) {},
              isMessageQueueInitializationCovered: (_) => false,
              onCharactersMovedLocationTap: (movement) {
                openedMovement = movement;
              },
              animateTransitions: false,
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

    expect(panels(), hasLength(2));
    expect(panels().where((panel) => panel.renderBackgroundImage), isEmpty);
    final firstState = tester.state(
      find.byKey(
        const ValueKey<String>('world-location-chat-loc_1'),
        skipOffstage: false,
      ),
    );
    final secondState = tester.state(
      find.byKey(
        const ValueKey<String>('world-location-chat-loc_2'),
        skipOffstage: false,
      ),
    );

    rebuildHost(() => cache.activate(first));
    await tester.pump();

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
    expect(
      tester.state(
        find.byKey(
          const ValueKey<String>('world-location-chat-loc_2'),
          skipOffstage: false,
        ),
      ),
      same(secondState),
    );
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
