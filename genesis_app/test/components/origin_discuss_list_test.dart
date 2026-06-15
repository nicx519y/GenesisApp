import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/components/discuss/origin_discuss_list.dart';
import 'package:genesis_flutter_android/components/discuss/story_badge.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:genesis_flutter_android/ui/components/genesis_avatar.dart';

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
      expect(find.byType(Divider), findsNothing);
      expect(find.text('View More >'), findsOneWidget);
    },
  );

  testWidgets('uses 16px spacing between discuss items', (tester) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            _page(pn: pn, rn: rn, totalAll: 2, contents: _contents(2)),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(
      _host(controller, showActions: false, showReplies: false),
    );

    final rows = find.byType(OriginDiscussCommentRow);
    expect(rows, findsNWidgets(2));
    final firstBottom = tester.getBottomLeft(rows.first).dy;
    final secondTop = tester.getTopLeft(rows.last).dy;
    expect(secondTop - firstBottom, closeTo(16, 0.1));
  });

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

  testWidgets('shows only two initial replies per comment', (tester) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [
                _item(
                  1,
                  'Discuss with replies',
                  replyCount: 3,
                  latestReplies: [_reply(1), _reply(2), _reply(3)],
                ),
              ],
              topTotal: 1,
              totalAll: 1,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    expect(find.text('User: Reply 1'), findsOneWidget);
    expect(find.text('User: Reply 2'), findsOneWidget);
    expect(find.text('User: Reply 3'), findsNothing);
    expect(find.text('View all 3 replies'), findsOneWidget);
  });

  testWidgets('hides reply View all when both replies are already visible', (
    tester,
  ) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [
                _item(
                  1,
                  'Discuss with two replies',
                  replyCount: 2,
                  latestReplies: [_reply(1), _reply(2)],
                ),
              ],
              topTotal: 1,
              totalAll: 1,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    expect(find.text('User: Reply 1'), findsOneWidget);
    expect(find.text('User: Reply 2'), findsOneWidget);
    expect(find.text('View all 2 replies'), findsNothing);
  });

  testWidgets('can render preview rows without actions or replies', (
    tester,
  ) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [
                _item(
                  1,
                  'Discuss preview only',
                  latestReplies: [_reply(1), _reply(2)],
                ),
              ],
              topTotal: 1,
              totalAll: 1,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(
      _host(controller, showActions: false, showReplies: false),
    );

    expect(find.text('Discuss preview only'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('origin-discuss-like-dis_1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('origin-discuss-reply-dis_1')),
      findsNothing,
    );
    expect(find.text('User: Reply 1'), findsNothing);
    expect(find.text('View all 2 replies'), findsNothing);
  });

  testWidgets('View all replies replaces cached replies then appends pages', (
    tester,
  ) async {
    final requests = <TransportRequest>[];
    final transport = _FakeTransport((request) {
      requests.add(request);
      if (request.uri.path.endsWith('/discuss/replies')) {
        final page = int.parse(request.uri.queryParameters['pn'] ?? '1');
        final start = page == 1 ? 1 : 21;
        return Future.value(
          _jsonOk({
            'list': [for (var id = start; id < start + 20; id += 1) _reply(id)],
            'total': 45,
            'pn': page,
            'rn': 20,
          }),
        );
      }
      return Future.value(_ok());
    });
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [
                _item(
                  1,
                  'Discuss with many replies',
                  replyCount: 45,
                  latestReplies: [
                    _reply(901, content: 'Cached 1'),
                    _reply(902, content: 'Cached 2'),
                  ],
                ),
              ],
              topTotal: 1,
              totalAll: 1,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(
      _host(controller, services: _servicesWithTransport(transport)),
    );

    expect(find.text('User: Cached 1'), findsOneWidget);
    expect(find.text('View all 45 replies'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('origin-discuss-view-all-replies-dis_1')),
    );
    await tester.pumpAndSettle();

    final firstRequest = requests
        .where((request) => request.uri.path.endsWith('/discuss/replies'))
        .single;
    expect(firstRequest.uri.queryParameters['root_discuss_id'], 'dis_1');
    expect(firstRequest.uri.queryParameters['pn'], '1');
    expect(firstRequest.uri.queryParameters['rn'], '20');
    expect(find.text('User: Cached 1'), findsNothing);
    expect(find.text('User: Reply 1'), findsOneWidget);
    expect(find.text('User: Reply 20'), findsOneWidget);
    expect(find.text('View all 25 replies'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('origin-discuss-view-all-replies-dis_1')),
    );
    await tester.pumpAndSettle();

    final replyRequests = requests
        .where((request) => request.uri.path.endsWith('/discuss/replies'))
        .toList(growable: false);
    expect(replyRequests, hasLength(2));
    expect(replyRequests.last.uri.queryParameters['pn'], '2');
    expect(find.text('User: Reply 21'), findsOneWidget);
    expect(find.text('User: Reply 40'), findsOneWidget);
    expect(find.text('View all 5 replies'), findsOneWidget);
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

  testWidgets('renders network avatars with CachedNetworkImage', (
    tester,
  ) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async {
          return OriginDiscussPage(
            items: [
              _item(
                1,
                'Discuss with avatar',
                avatar: 'https://cdn.example.com/users/u_1.png',
              ),
            ],
            topTotal: 1,
            totalAll: 1,
            pn: pn,
            rn: rn,
          );
        },
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    final avatar = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage).first,
    );
    expect(avatar.imageUrl, 'https://cdn.example.com/users/u_1.png');
  });

  testWidgets('renders discuss author name with subtle compact style', (
    tester,
  ) async {
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async {
          return OriginDiscussPage(
            items: [_item(1, 'Discuss with styled author', storyCount: 124)],
            topTotal: 1,
            totalAll: 1,
            pn: pn,
            rn: rn,
          );
        },
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    final author = tester.widget<Text>(find.text('User 1'));
    expect(author.style?.fontSize, 12);
    expect(author.style?.fontWeight, FontWeight.w500);
    expect(author.style?.color, const Color(0xFF888888));
    final authorCenter = tester.getCenter(find.text('User 1'));
    final badgeCenter = tester.getCenter(find.byType(DiscussStoryBadge));
    expect((authorCenter.dy - badgeCenter.dy).abs(), lessThan(1));
    final metaBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('origin-discuss-meta-dis_1')))
        .dy;
    final contentTop = tester
        .getTopLeft(find.text('Discuss with styled author'))
        .dy;
    expect(contentTop - metaBottom, closeTo(4, 0.1));
  });

  testWidgets('renders compact avatars and today time without date', (
    tester,
  ) async {
    final today = DateTime.now();
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async {
          return OriginDiscussPage(
            items: [
              _item(
                1,
                'Discuss today',
                authorUid: 'u_today',
                createdAt: DateTime(today.year, today.month, today.day, 9, 7),
              ),
            ],
            topTotal: 1,
            totalAll: 1,
            pn: pn,
            rn: rn,
          );
        },
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(_host(controller));

    expect(
      tester.getSize(
        find.byKey(const ValueKey('origin-discuss-avatar-u_today')),
      ),
      const Size(36, 36),
    );
    final avatar = tester.widget<GenesisAvatar>(
      find.descendant(
        of: find.byKey(const ValueKey('origin-discuss-avatar-u_today')),
        matching: find.byType(GenesisAvatar),
      ),
    );
    expect(avatar.borderRadius, 8);
    expect(find.text('09:07'), findsOneWidget);
    expect(find.text('${today.month}-${today.day} 09:07'), findsNothing);
    expect(
      tester.getTopRight(find.text('09:07')).dx,
      greaterThan(tester.getTopRight(find.byType(DiscussStoryBadge)).dx),
    );
    final rowRight = tester
        .getTopRight(find.byKey(const ValueKey('origin-discuss-meta-dis_1')))
        .dx;
    final timeRight = tester.getTopRight(find.text('09:07')).dx;
    expect(rowRight - timeRight, lessThan(8));
  });

  testWidgets('renders item images as 48dp horizontal thumbnails', (
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
    expect(tester.getSize(firstImage), const Size(48, 48));
    expect(tester.getSize(secondImage), const Size(48, 48));
  });

  testWidgets('thumbnail tap delegates to discuss item navigation', (
    tester,
  ) async {
    OriginDiscussListItem? tappedItem;
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
    await tester.pumpWidget(
      _host(
        controller,
        onItemReplyTap: (item) {
          tappedItem = item;
        },
      ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey(
          'origin-discuss-image-assets/images/mock_maps/steam_kingdom_isometric.png',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tappedItem?.discussId, 'dis_with_images');
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      findsNothing,
    );
  });

  testWidgets('thumbnail tap opens image viewer when configured', (
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
                  'content': 'Tap image to preview',
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
    await tester.pumpWidget(_host(controller, imageTapOpensViewer: true));

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
  });

  testWidgets('avatar tap pushes user page and discuss meta hides WID', (
    tester,
  ) async {
    final pushed = <RouteSettings>[];
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async {
          return OriginDiscussPage.fromJson({
            'list': [
              {
                'comment': {
                  'discuss_id': 'dis_route',
                  'biz_id': 'o_alpha',
                  'world_id': 'w_alpha',
                  'author': {'uid': 'u_alpha', 'name': 'Ada'},
                  'content': 'Route me',
                  'reply_cnt': 0,
                  'created_at': '2026-02-09T00:00:00Z',
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
    await tester.pumpWidget(
      _host(
        controller,
        pushed: pushed,
        services: _servicesWithTransport(
          _FakeTransport((request) {
            if (request.uri.path.endsWith('/world/origin_progress')) {
              return Future.value(
                _jsonOk({'world_id': 'w_alpha', 'tick_cnt': 8}),
              );
            }
            return Future.value(_ok());
          }),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('origin-discuss-avatar-u_alpha')),
    );
    await tester.pumpAndSettle();

    expect(pushed.last.name, RouteNames.userInfo);
    expect(pushed.last.arguments, {'uid': 'u_alpha'});
    expect(find.text('WID: w_alpha'), findsNothing);
    expect(
      find.byKey(const ValueKey('origin-discuss-world-w_alpha')),
      findsNothing,
    );
  });

  testWidgets('loadOriginDiscussPage does not request origin progress', (
    tester,
  ) async {
    final transport = _FakeTransport((request) {
      if (request.uri.path.endsWith('/discuss/list')) {
        return Future.value(
          _jsonOk({
            'list': [
              {
                'comment': {
                  'discuss_id': 'dis_progress',
                  'biz_id': 'ori_alpha',
                  'author': {'uid': 'u_alpha', 'name': 'Ada'},
                  'content': 'Progress me',
                  'reply_cnt': 0,
                  'created_at': '2026-02-09T00:00:00Z',
                },
                'latest_replies': const <Object?>[],
              },
            ],
            'top_total': 1,
            'total_all': 1,
            'pn': 1,
            'rn': 20,
          }),
        );
      }
      if (request.uri.path.endsWith('/world/origin_progress')) {
        return Future.value(
          _jsonOk({'world_id': 'w_progress', 'tick_cnt': 12}),
        );
      }
      return Future.value(_ok());
    });
    final pageCompleter = Completer<OriginDiscussPage>();

    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  pageCompleter.complete(
                    await loadOriginDiscussPage(context, 'ori_alpha'),
                  );
                },
                child: const Text('load'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('load'));
    await tester.pumpAndSettle();

    final page = await pageCompleter.future;
    expect(page.items.single.worldId, isEmpty);
    expect(page.items.single.storyCount, 0);
    final progressRequest = transport.requests.where(
      (request) => request.uri.path.endsWith('/world/origin_progress'),
    );
    expect(progressRequest, isEmpty);
  });

  testWidgets('visible discuss row loads origin progress once', (tester) async {
    final transport = _FakeTransport((request) {
      if (request.uri.path.endsWith('/world/origin_progress')) {
        return Future.value(
          _jsonOk({'world_id': 'w_progress', 'tick_cnt': 12}),
        );
      }
      return Future.value(_ok());
    });
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'ori_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [
                _item(
                  1,
                  'Progress me',
                  authorUid: 'u_alpha',
                  bizId: 'ori_alpha',
                ),
              ],
              topTotal: 1,
              totalAll: 1,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(
      _host(controller, services: _servicesWithTransport(transport)),
    );
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('WID: w_progress'), findsNothing);
    expect(
      find.byKey(const ValueKey('origin-discuss-world-w_progress')),
      findsNothing,
    );
    final progressRequest = transport.requests
        .where((request) => request.uri.path.endsWith('/world/origin_progress'))
        .single;
    expect(progressRequest.uri.queryParameters['uid'], 'u_alpha');
    expect(progressRequest.uri.queryParameters['origin_id'], 'ori_alpha');
  });

  test(
    'progress result cache hydrates later loaded matching comments',
    () async {
      var progressRequests = 0;
      final controller = OriginDiscussListController()
        ..configure(
          oid: 'ori_alpha',
          loader: ({required oid, required pn, required rn}) async =>
              OriginDiscussPage(
                items: [
                  _item(
                    pn,
                    'Progress page $pn',
                    authorUid: 'u_alpha',
                    bizId: 'ori_alpha',
                  ),
                ],
                topTotal: 2,
                totalAll: 2,
                pn: pn,
                rn: rn,
              ),
        );

      await controller.loadInitialIfNeeded();
      await controller.loadProgressForItem(
        item: controller.items.single,
        loader: ({required uid, required originId}) async {
          progressRequests += 1;
          return {'world_id': 'w_cached', 'tick_cnt': 88};
        },
      );

      expect(controller.items.single.storyCount, 88);
      expect(controller.items.single.worldId, 'w_cached');

      await controller.loadNextPage();

      expect(controller.items, hasLength(2));
      expect(controller.items.map((item) => item.storyCount), everyElement(88));
      expect(
        controller.items.map((item) => item.worldId),
        everyElement('w_cached'),
      );

      await controller.loadProgressForItem(
        item: controller.items.last,
        loader: ({required uid, required originId}) async {
          progressRequests += 1;
          return {'world_id': 'w_should_not_request', 'tick_cnt': 1};
        },
      );

      expect(progressRequests, 1);
      expect(controller.items.last.storyCount, 88);
      expect(controller.items.last.worldId, 'w_cached');
    },
  );

  testWidgets('offscreen discuss row waits until near viewport for progress', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);

    final transport = _FakeTransport((request) {
      if (request.uri.path.endsWith('/world/origin_progress')) {
        return Future.value(_jsonOk({'world_id': 'w_late', 'tick_cnt': 34}));
      }
      return Future.value(_ok());
    });
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'ori_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [
                _item(1, 'Top item'),
                _item(
                  2,
                  'Late progress',
                  authorUid: 'u_late',
                  bizId: 'ori_alpha',
                ),
              ],
              topTotal: 2,
              totalAll: 2,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(
      AppServicesScope(
        services: _servicesWithTransport(transport),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 1400),
                  OriginDiscussList(controller: controller, showHeader: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      transport.requests.where(
        (request) => request.uri.path.endsWith('/world/origin_progress'),
      ),
      isEmpty,
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.text('34'), findsOneWidget);
    expect(find.text('WID: w_late'), findsNothing);
    expect(
      find.byKey(const ValueKey('origin-discuss-world-w_late')),
      findsNothing,
    );
    final progressRequest = transport.requests
        .where((request) => request.uri.path.endsWith('/world/origin_progress'))
        .single;
    expect(progressRequest.uri.queryParameters['uid'], 'u_late');
    expect(progressRequest.uri.queryParameters['origin_id'], 'ori_alpha');
  });

  testWidgets('like tap is optimistic and locked until request completes', (
    tester,
  ) async {
    final likeResponse = Completer<TransportResponse>();
    final transport = _FakeTransport((request) {
      if (request.uri.path.endsWith('/discuss/like')) {
        return likeResponse.future;
      }
      return Future.value(_ok());
    });
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [_item(1, 'Like me', likeCount: 3)],
              topTotal: 1,
              totalAll: 1,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(
      _host(controller, services: _servicesWithTransport(transport)),
    );

    final likeButton = find.byKey(const ValueKey('origin-discuss-like-dis_1'));
    await tester.tap(likeButton);
    await tester.pump();

    expect(controller.items.single.isLiked, isTrue);
    expect(controller.items.single.likeCount, 4);
    expect(controller.isLikePending('dis_1'), isTrue);

    await tester.tap(likeButton);
    await tester.pump();

    expect(
      transport.requests.where(
        (request) => request.uri.path.endsWith('/discuss/like'),
      ),
      hasLength(1),
    );

    likeResponse.complete(_ok());
    await tester.pumpAndSettle();

    expect(controller.items.single.isLiked, isTrue);
    expect(controller.items.single.likeCount, 4);
    expect(controller.isLikePending('dis_1'), isFalse);
  });

  testWidgets('failed like request rolls back optimistic state', (
    tester,
  ) async {
    final transport = _FakeTransport((request) {
      if (request.uri.path.endsWith('/discuss/like')) {
        return Future.value(
          const TransportResponse(
            statusCode: 500,
            headers: {'content-type': 'application/json'},
            body: '{"err_no":1,"err_msg":"fail"}',
          ),
        );
      }
      return Future.value(_ok());
    });
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [_item(1, 'Like me', likeCount: 3)],
              topTotal: 1,
              totalAll: 1,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(
      _host(controller, services: _servicesWithTransport(transport)),
    );

    await tester.tap(find.byKey(const ValueKey('origin-discuss-like-dis_1')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(controller.items.single.isLiked, isFalse);
    expect(controller.items.single.likeCount, 3);
    expect(controller.isLikePending('dis_1'), isFalse);
  });

  testWidgets('reply send inserts reply only after successful request', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);

    final replyResponse = Completer<TransportResponse>();
    final transport = _FakeTransport((request) {
      if (request.uri.path.endsWith('/discuss/post')) {
        return replyResponse.future;
      }
      return Future.value(_ok());
    });
    final controller = OriginDiscussListController()
      ..configure(
        oid: 'o_alpha',
        loader: ({required oid, required pn, required rn}) async =>
            OriginDiscussPage(
              items: [_item(1, 'Reply to me', bizId: 'o_alpha', replyCount: 2)],
              topTotal: 1,
              totalAll: 1,
              pn: pn,
              rn: rn,
            ),
      );

    await controller.loadInitialIfNeeded();
    await tester.pumpWidget(
      _host(controller, services: _servicesWithTransport(transport)),
    );

    await tester.tap(find.byKey(const ValueKey('origin-discuss-reply-dis_1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Write a reply').last,
      'reply now',
    );
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();

    expect(controller.items.single.replyCount, 2);
    expect(
      transport.requests.where(
        (request) => request.uri.path.endsWith('/discuss/post'),
      ),
      hasLength(1),
    );

    replyResponse.complete(
      const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"discuss_id":"dis_reply_new","root_discuss_id":"dis_1","level":2}}',
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.items.single.replyCount, 3);
    expect(
      controller.items.single.latestReplies.first['discuss_id'],
      'dis_reply_new',
    );
    expect(controller.items.single.latestReplies.first['content'], 'reply now');
    expect(
      transport.requests.where(
        (request) => request.uri.path.endsWith('/discuss/replies'),
      ),
      isEmpty,
    );
  });
}

Widget _host(
  OriginDiscussListController controller, {
  AppServices? services,
  List<RouteSettings>? pushed,
  bool showActions = true,
  bool showReplies = true,
  bool imageTapOpensViewer = false,
  OriginDiscussItemTap? onItemReplyTap,
}) {
  final app = MaterialApp(
    onGenerateRoute: (settings) {
      if (settings.name != '/') pushed?.add(settings);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(
          body: SingleChildScrollView(
            child: OriginDiscussList(
              controller: controller,
              showHeader: false,
              showActions: showActions,
              showReplies: showReplies,
              imageTapOpensViewer: imageTapOpensViewer,
              onItemReplyTap: onItemReplyTap,
            ),
          ),
        ),
      );
    },
  );
  if (services == null) return app;
  return AppServicesScope(services: services, child: app);
}

AppServices _servicesWithTransport(_FakeTransport transport) {
  final base = ServiceRegistry.build(config: const AppConfig(useMock: true));
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8080/api/',
    defaultHeaders: const {
      'content-type': 'application/json',
      'accept': 'application/json',
    },
    transport: transport,
    responseProcessor: (response) =>
        ApiClient.defaultResponseProcessor(response),
  );
  final healthClient = ApiClient(
    baseUrl: 'http://localhost:8080/',
    defaultHeaders: const {'accept': 'application/json'},
    transport: transport,
    responseProcessor: (response) =>
        ApiClient.defaultResponseProcessor(response),
  );
  final sessionStore = MemoryUserSessionStore();
  unawaited(sessionStore.saveUid('u_test'));
  unawaited(sessionStore.saveAuthToken('test-token'));
  return AppServices(
    config: base.config,
    platformConfig: base.platformConfig,
    deviceId: base.deviceId,
    sessionStore: sessionStore,
    identityAuth: base.identityAuth,
    backendAuth: base.backendAuth,
    api: GenesisApi(
      apiClient: apiClient,
      healthClient: healthClient,
      sessionStore: sessionStore,
    ),
    chatroom: base.chatroom,
    chatroomMessages: MemoryChatroomMessageStorage(),
    directMessageConversations: base.directMessageConversations,
    directMessageMessages: base.directMessageMessages,
  );
}

class _FakeTransport implements HttpTransport {
  _FakeTransport(this.handler);

  final Future<TransportResponse> Function(TransportRequest request) handler;
  final List<TransportRequest> requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) {
    requests.add(request);
    return handler(request);
  }
}

TransportResponse _ok([Map<String, dynamic> data = const <String, dynamic>{}]) {
  return _jsonOk(data);
}

TransportResponse _jsonOk(Map<String, dynamic> data) {
  return TransportResponse(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    body: jsonEncode({'err_no': 0, 'err_msg': 'succ', 'data': data}),
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

OriginDiscussListItem _item(
  int id,
  String content, {
  String avatar = '',
  String bizId = '',
  String worldId = '',
  String authorUid = '',
  int storyCount = 0,
  int? replyCount,
  int likeCount = 0,
  bool isLiked = false,
  DateTime? createdAt,
  List<Map<String, dynamic>> latestReplies = const <Map<String, dynamic>>[],
}) {
  return OriginDiscussListItem(
    discussId: 'dis_$id',
    bizId: bizId,
    worldId: worldId,
    authorUid: authorUid,
    authorName: 'User $id',
    avatar: avatar,
    content: content,
    storyCount: storyCount,
    replyCount: replyCount ?? id,
    likeCount: likeCount,
    isLiked: isLiked,
    createdAt: createdAt ?? DateTime(2026, 2, id.clamp(1, 28)),
    seed: 'u_$id',
    latestReplies: latestReplies,
  );
}

Map<String, dynamic> _reply(int id, {String? content}) {
  return {
    'discuss_id': 'reply_$id',
    'author': {'uid': 'u_reply_$id', 'name': 'User'},
    'content': content ?? 'Reply $id',
    'images': const <String>[],
    'root_discuss_id': 'dis_1',
    'parent_discuss_id': 'dis_1',
    'level': 2,
    'reply_cnt': 0,
    'like_cnt': 0,
    'is_liked': false,
    'created_at': '2026-02-09T00:00:00Z',
  };
}
