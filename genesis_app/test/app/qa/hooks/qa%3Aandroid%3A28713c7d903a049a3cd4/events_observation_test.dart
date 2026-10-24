import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/components/world_tick_event_item.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';

void main() {
  testWidgets(
    'actual events renderer exposes visible completed round inside a modal route',
    (tester) async {
      late BuildContext base;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              base = context;
              return const Scaffold(body: Text('World route'));
            },
          ),
        ),
      );
      showModalBottomSheet<void>(
        context: base,
        isScrollControlled: true,
        builder: (_) => SizedBox(
          height: 500,
          child: WorldEventsSection(
            world: _worldDetail(),
            ticks: const [
              {
                'tick_id': 'qa-tick',
                'tick_no': 2301,
                'sub_tick_no': 0,
                'status': 50,
                'tick_result': {
                  'narrator': 'Current owned event',
                  'paragraphs': [],
                },
              },
            ],
            initialLoading: false,
            loadingMore: false,
            hasMore: false,
            error: null,
            latestRevision: 1,
            targetTickNumber: 2301,
            contentPadding: EdgeInsets.zero,
            onLoadMore: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panel = tester.element(find.byType(WorldEventsSection));
      final items = elements(
        panel,
      ).where((e) => e.widget is WorldTickEventItem).toList();
      expect(items, hasLength(1));
      expect(visible(items.single), isTrue);
      expect(textElements('Tick 2301', panel), isNotEmpty);
      expect(
        textElements('Tick 2301', tester.element(find.text('World route'))),
        isEmpty,
      );
      expect((panel.widget as WorldEventsSection).targetTickNumber, 2301);
      expect(tester.takeException(), isNull);
    },
  );
}

WorldDetail _worldDetail({
  List<Map<String, dynamic>> characters = const <Map<String, dynamic>>[],
}) {
  return WorldDetail(
    id: 1,
    worldId: 'world_events_test',
    originId: 1,
    ownerUid: 'owner',
    name: 'Events Test',
    tickCount: 4,
    connectCount: 0,
    characterCount: 0,
    playerCount: 0,
    currentTime: '',
    latestTickAt: null,
    latestNarrator: '',
    isProgressing: false,
    relationStatus: 'joined',
    metric: const <String, dynamic>{},
    inviteToken: '',
    createdAt: null,
    updatedAt: null,
    origin: const OriginSummary(
      id: 1,
      oid: 'origin_events_test',
      name: 'Origin',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 0,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    ),
    characters: characters,
    ticks: const <Map<String, dynamic>>[],
    locations: const <Map<String, dynamic>>[],
    characterPositions: const <Map<String, dynamic>>[],
    userPositions: const <Map<String, dynamic>>[],
  );
}
