import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Ae902ad40417a12b1d8e2/event_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_sections.dart';
import 'package:genesis_flutter_android/components/world_tick_event_item.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253Ad43c9deee50740096afb/browse_gesture.dart';

void main() {
  for (final sheet in [false, true]) {
    for (final blocked in [false, true]) {
      testWidgets('event browsing with sheet=$sheet blocked=$blocked', (
        tester,
      ) async {
        Widget section(ScrollController? controller) => WorldEventsSection(
          world: _worldDetail(),
          ticks: [
            {
              'tick_id': 'qa-tick',
              'tick_no': 2301,
              'sub_tick_no': 0,
              'status': 50,
              'tick_result': {
                'narrator': tickEventContent('owned-attempt'),
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
          contentPadding: const EdgeInsets.fromLTRB(12, 20, 12, 32),
          onLoadMore: () {},
          scrollController: controller,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: AbsorbPointer(
              absorbing: blocked,
              child: Scaffold(
                body: sheet
                    ? DraggableScrollableSheet(
                        initialChildSize: 0.8,
                        minChildSize: 0.3,
                        maxChildSize: 0.9,
                        snap: true,
                        snapSizes: const [0.3, 0.9],
                        builder: (context, c) => section(c),
                      )
                    : section(null),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final item = tester.element(find.byType(WorldTickEventItem));
        final target = Scrollable.of(item, axis: Axis.vertical);
        BrowseGestureResult? result;
        final op = browseByTouch(target).then((r) => result = r);
        for (var i = 0; i < 200; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await op;
        await tester.pumpAndSettle();
        expect(result!.scrollRequired, isTrue);
        expect(result!.succeeded, !blocked);
        if (!blocked) expect(result!.to, greaterThan(result!.from + 1));
        if (blocked) expect(result!.to, result!.from);
      });
    }
  }
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
