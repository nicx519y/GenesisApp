import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';

void main() {
  testWidgets(
    'events pager renders sub ticks for one tick number on one page',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorldEventsSection(
              world: _worldDetail(),
              ticks: const [
                {
                  'tick_id': 'tick_3_1',
                  'tick_no': 3,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'Tick 3 body',
                    'paragraphs': <Object?>[],
                  },
                },
                {
                  'tick_id': 'tick_4_2',
                  'tick_no': 4,
                  'sub_tick_no': 2,
                  'tick_result': {
                    'narrator': 'Tick 4 sub tick 2 body',
                    'paragraphs': <Object?>[],
                  },
                },
                {
                  'tick_id': 'tick_4_1',
                  'tick_no': 4,
                  'sub_tick_no': 1,
                  'tick_result': {
                    'narrator': 'Tick 4 sub tick 1 body',
                    'paragraphs': <Object?>[],
                  },
                },
              ],
              initialLoading: false,
              loadingMore: false,
              hasMore: false,
              error: null,
              latestRevision: 0,
              targetTickNumber: null,
              contentPadding: EdgeInsets.zero,
              onLoadMore: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pager = tester.widget<PageView>(
        find.byKey(const ValueKey<String>('world-events-tick-pager')),
      );
      expect(pager.childrenDelegate.estimatedChildCount, 2);
      expect(find.text('Tick 4-1'), findsOneWidget);
      expect(find.text('Tick 4-2'), findsOneWidget);
      expect(find.text('Tick 4 sub tick 1 body'), findsOneWidget);
      expect(find.text('Tick 4 sub tick 2 body'), findsOneWidget);
    },
  );
}

WorldDetail _worldDetail() {
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
    characters: const <Map<String, dynamic>>[],
    ticks: const <Map<String, dynamic>>[],
    locations: const <Map<String, dynamic>>[],
    characterPositions: const <Map<String, dynamic>>[],
    userPositions: const <Map<String, dynamic>>[],
  );
}
