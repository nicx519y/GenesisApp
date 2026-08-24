import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_sections_library.dart';

void main() {
  testWidgets('events timeline renders network role avatars without intrinsic crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldEventsSection(
            world: WorldDetail.fromJson(const {
              'world_id': 'w', 'name': 'W', 'owner_uid': 'u', 'origin_id': 1,
              'characters': [
                {'char_id': 'c1', 'name': 'Oracle', 'player_uid': '',
                 'avatar': 'https://cdn.example.com/a.png'},
                {'char_id': 'c2', 'name': 'Iris', 'player_uid': 'user_iris',
                 'avatar': 'https://cdn.example.com/b.png'},
              ],
            }),
            ticks: const [
              {
                'tick_id': 't41', 'tick_no': 4, 'sub_tick_no': 1,
                'tick_result': {
                  'narrator': 'A signal reaches the harbor.',
                  'paragraphs': <Object?>[
                    {
                      'location_id': 'loc',
                      'timestamp': 'Day 4, 20:25',
                      'visibility': 'char_only',
                      'visible_to': ['c1', 'c2'],
                      'text': 'Only the visible roles hear the signal.',
                      'clue': 'Follow the light.',
                    },
                  ],
                },
              },
            ],
            initialLoading: false, loadingMore: false, hasMore: false,
            error: null, latestRevision: 0, targetTickNumber: null,
            contentPadding: EdgeInsets.zero, onLoadMore: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    // 角色气泡里的网络头像走 LayoutBuilder,时间线行不能再用
    // IntrinsicHeight ——否则 dry-layout 直接抛异常、整页红屏。
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Oracle'), findsOneWidget);
    expect(find.text('Iris'), findsOneWidget);
  });
}
