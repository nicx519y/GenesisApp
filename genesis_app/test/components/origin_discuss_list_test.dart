import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/discuss/origin_discuss_list.dart';

void main() {
  testWidgets(
    'loads first page once with rn 20 and shows two collapsed items',
    (tester) async {
      final requests = <({String oid, int pn, int rn})>[];
      final controller = OriginDiscussListController()
        ..configure(
          oid: 'o_alpha',
          loader: ({required oid, required pn, required rn}) async {
            requests.add((oid: oid, pn: pn, rn: rn));
            return _page(pn: pn, rn: rn, totalAll: 3, contents: _contents(3));
          },
        );

      await controller.loadInitialIfNeeded();
      await controller.loadInitialIfNeeded();
      await tester.pumpWidget(_host(controller));

      expect(requests, hasLength(1));
      expect(requests.single, (oid: 'o_alpha', pn: 1, rn: 20));
      expect(find.text('Discuss 1'), findsOneWidget);
      expect(find.text('Discuss 2'), findsOneWidget);
      expect(find.text('Discuss 3'), findsNothing);
      expect(find.text('View More >'), findsOneWidget);
    },
  );

  testWidgets('hides View More when total_all is not greater than two', (
    tester,
  ) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            _page(pn: pn, rn: rn, totalAll: 2, contents: _contents(2)),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    expect(find.text('Discuss 1'), findsOneWidget);
    expect(find.text('Discuss 2'), findsOneWidget);
    expect(find.text('View More >'), findsNothing);
  });

  testWidgets('first View More expands memory and second loads next page', (
    tester,
  ) async {
    final requests = <({String oid, int pn, int rn})>[];
    final page2 = Completer<OriginDiscussPage>();
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) {
          requests.add((oid: oid, pn: pn, rn: rn));
          if (pn == 2) return page2.future;
          return Future.value(
            _page(pn: pn, rn: rn, totalAll: 5, contents: _contents(3)),
          );
        },
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    await tester.tap(find.byKey(const ValueKey('origin-discuss-view-more')));
    await tester.pump();

    expect(requests, hasLength(1));
    expect(find.text('Discuss 3'), findsOneWidget);
    expect(find.text('View More >'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('origin-discuss-view-more')));
    await tester.pump();

    expect(requests, hasLength(2));
    expect(requests.last, (oid: 'o_alpha', pn: 2, rn: 20));
    expect(
      find.byKey(const ValueKey('origin-discuss-view-more-loading')),
      findsOneWidget,
    );

    page2.complete(
      _page(
        pn: 2,
        rn: 20,
        totalAll: 5,
        startIndex: 4,
        contents: const ['Discuss 4', 'Discuss 5'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Discuss 4'), findsOneWidget);
    expect(find.text('Discuss 5'), findsOneWidget);
    expect(find.text('View More >'), findsNothing);
  });

  testWidgets('refreshFirstPage merges without clearing current items', (
    tester,
  ) async {
    final refresh = Completer<OriginDiscussPage>();
    var callCount = 0;
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) {
          callCount += 1;
          if (callCount == 1) {
            return Future.value(
              _page(
                pn: pn,
                rn: rn,
                totalAll: 4,
                contents: const ['Old 1', 'Old 2', 'Old 3'],
              ),
            );
          }
          return refresh.future;
        },
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));
    expect(find.text('Old 1'), findsOneWidget);

    final refreshFuture = controller.refreshFirstPage();
    await tester.pump();
    expect(find.text('Old 1'), findsOneWidget);
    expect(controller.items.map((item) => item.content), [
      'Old 1',
      'Old 2',
      'Old 3',
    ]);

    refresh.complete(
      OriginDiscussPage(
        items: [_item(99, 'New first page item'), _item(1, 'Updated 1')],
        topTotal: 4,
        totalAll: 4,
        pn: 1,
        rn: 20,
      ),
    );
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(controller.items.map((item) => item.content), [
      'New first page item',
      'Updated 1',
      'Old 2',
      'Old 3',
    ]);
    expect(find.text('New first page item'), findsOneWidget);
    expect(find.text('Updated 1'), findsOneWidget);
  });

  testWidgets('renders item images as 80x80 wrapped thumbnails', (
    tester,
  ) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async {
          return OriginDiscussPage.fromJson({
            'list': [
              {
                'comment': {
                  'discuss_id': 'dis_with_images',
                  'author': {'uid': 'u_1', 'name': 'Shawn'},
                  'content': 'Post with thumbnails',
                  'reply_cnt': 2,
                  'created_at': '2026-02-09T00:00:00Z',
                  'images': [
                    'assets/images/mock_maps/steam_kingdom_isometric.png',
                    {'url': 'https://cdn.example.com/discuss/second.jpg'},
                  ],
                },
                'latest_replies': const <Object?>[],
              },
            ],
            'top_total': 1,
            'total_all': 1,
            'pn': pn,
            'rn': rn,
          });
        },
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    expect(find.text('Post with thumbnails'), findsOneWidget);
    final firstImage = find.byKey(
      const ValueKey(
        'origin-discuss-image-assets/images/mock_maps/steam_kingdom_isometric.png',
      ),
    );
    final secondImage = find.byKey(
      const ValueKey(
        'origin-discuss-image-https://cdn.example.com/discuss/second.jpg',
      ),
    );
    expect(firstImage, findsOneWidget);
    expect(secondImage, findsOneWidget);
    expect(tester.getSize(firstImage), const Size(80, 80));
    expect(tester.getSize(secondImage), const Size(80, 80));
  });

  testWidgets('opens image viewer from thumbnail and closes with back', (
    tester,
  ) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async {
          return OriginDiscussPage.fromJson({
            'list': [
              {
                'comment': {
                  'discuss_id': 'dis_with_images',
                  'author': {'uid': 'u_1', 'name': 'Shawn'},
                  'content': 'Tap image to view',
                  'reply_cnt': 2,
                  'created_at': '2026-02-09T00:00:00Z',
                  'images': [
                    'assets/images/mock_maps/steam_kingdom_isometric.png',
                    'assets/images/mock_maps/location_rail_gate_map.png',
                  ],
                },
                'latest_replies': const <Object?>[],
              },
            ],
            'top_total': 1,
            'total_all': 1,
            'pn': pn,
            'rn': rn,
          });
        },
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    await tester.tap(
      find.byKey(
        const ValueKey(
          'origin-discuss-image-assets/images/mock_maps/steam_kingdom_isometric.png',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-thumbnails')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-thumbnail-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-thumbnail-1')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-image-viewer-thumbnail-0')),
      ),
      const Size(56, 56),
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-image-viewer-thumbnail-1')),
      ),
      const Size(56, 56),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      findsNothing,
    );
  });
}

Widget _host(OriginDiscussListController controller) {
  return MaterialApp(
    home: Scaffold(
      body: OriginDiscussList(controller: controller, showHeader: false),
    ),
  );
}

OriginDiscussPage _page({
  required int pn,
  required int rn,
  required int totalAll,
  int startIndex = 1,
  required List<String> contents,
}) {
  return OriginDiscussPage(
    items: [
      for (final entry in contents.indexed)
        _item(startIndex + entry.$1, entry.$2),
    ],
    topTotal: totalAll,
    totalAll: totalAll,
    pn: pn,
    rn: rn,
  );
}

List<String> _contents(int count) => [
  for (var index = 1; index <= count; index += 1) 'Discuss $index',
];

OriginDiscussListItem _item(int id, String content) {
  return OriginDiscussListItem(
    discussId: 'dis_$id',
    authorName: 'User $id',
    avatar: '',
    content: content,
    replyCount: id,
    createdAt: DateTime(2026, 2, id.clamp(1, 28)),
    seed: 'u_$id',
    latestReplies: const <Map<String, dynamic>>[],
  );
}
