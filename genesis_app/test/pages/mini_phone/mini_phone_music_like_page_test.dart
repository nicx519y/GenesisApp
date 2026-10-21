import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import '../../support/mini_phone_music_services.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/music/mini_phone_music_like_button.dart';
import 'package:genesis_flutter_android/pages/mini_phone/shared/mini_phone_ui.dart';
import 'package:genesis_flutter_android/utils/stat_count_formatter.dart';

TransportResponse response(
  Object data, {
  int code = 0,
  String message = 'succ',
}) => TransportResponse(
  statusCode: 200,
  headers: const {},
  body: jsonEncode({'err_no': code, 'err_msg': message, 'data': data}),
);

class _MusicTransport implements HttpTransport {
  bool liked = true;
  int count = 1;
  final requests = <TransportRequest>[];
  Completer<TransportResponse>? write;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/music/list')) {
      return response({
        'pre_url': 'https://cdn.example/',
        'list': [
          {
            'file': '001.mp3',
            'source_worldo_id': 'o_test',
            'source_worldo_name': 'Worldo',
            'artist': 'Artist',
            'title': 'Track',
            'cover_url': 'https://cdn.example/cover.jpg',
            'like_cnt': count,
            'is_liked': liked,
          },
        ],
      });
    }
    return write!.future;
  }
}

Finder heart(bool liked) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.label == '${liked ? 'Unlike' : 'Like'} Track',
);
Future<void> pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  tearDown(
    () => VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    ),
  );

  testWidgets(
    'player fetches server status, updates before POST completes, rolls back, and displays err_msg',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final phone = MiniPhoneSession();
      addTearDown(phone.dispose);
      await phone.music.loadCatalog(
        () async => const MusicCatalog(
          preUrl: 'https://cdn.example/',
          tracks: [
            MusicTrack(
              likeCount: 0,
              isLiked: false,
              file: '001.mp3',
              audioUrl: 'https://cdn.example/001.mp3',
              sourceWorldoId: 'o_test',
              sourceWorldoName: 'Worldo',
              artist: 'Artist',
              title: 'Track',
              coverUrl: 'assets/mini_phone/loc_1_1_1.jpg',
            ),
          ],
        ),
      );
      final transport = _MusicTransport();
      final api = GenesisApi(
        useMock: false,
        apiClient: ApiClient(
          baseUrl: 'https://api.example/api/',
          transport: transport,
        ),
      );
      await tester.pumpWidget(
        AppServicesScope(
          services: musicTestServices(api),
          child: MaterialApp(
            home: MiniPhonePage(
              session: phone,
              initialScreen: MiniPhoneScreen.music,
            ),
          ),
        ),
      );
      await pump(tester);
      expect(heart(true), findsOneWidget);
      expect(transport.requests.single.uri.path, '/api/v1/music/list');
      expect(transport.requests.single.uri.queryParameters, isEmpty);
      expect(phone.music.likes.likeCount('001.mp3'), 1);
      expect(find.text('1'), findsOneWidget);

      transport.write = Completer<TransportResponse>();
      await tester.tap(heart(true));
      await pump(tester);
      expect(heart(false), findsOneWidget);
      expect(find.byKey(const ValueKey('mini-music-like-count')), findsNothing);
      expect(phone.music.likes.likeCount('001.mp3'), 0);
      expect(transport.requests.last.uri.path, '/api/v1/music/unlike');
      expect(jsonDecode(utf8.decode(transport.requests.last.bodyBytes!)), {
        'file': '001.mp3',
      });
      transport.write!.complete(
        response({}, code: 5001, message: '取消点赞失败，请重试'),
      );
      await pump(tester);
      expect(heart(true), findsOneWidget);
      expect(find.text('取消点赞失败，请重试'), findsOneWidget);
      expect(phone.music.likes.likeCount('001.mp3'), 1);
      await tester.pump(const Duration(seconds: 3));

      transport.write = Completer<TransportResponse>();
      await tester.tap(heart(true));
      await pump(tester);
      expect(heart(false), findsOneWidget);
      transport.write!.complete(response({}));
      await pump(tester);
      expect(heart(false), findsOneWidget);

      transport.write = Completer<TransportResponse>();
      await tester.tap(heart(false));
      await pump(tester);
      expect(heart(true), findsOneWidget);
      expect(transport.requests.last.uri.path, '/api/v1/music/like');
      transport.write!.complete(response({}, code: 5001, message: '点赞失败，请重试'));
      await pump(tester);
      expect(heart(false), findsOneWidget);
      expect(find.text('点赞失败，请重试'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Home and player share optimistic counts and failures; Home like does not open',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = _MusicTransport();
      final api = GenesisApi(
        useMock: false,
        apiClient: ApiClient(
          baseUrl: 'https://api.example/api/',
          transport: transport,
        ),
      );
      final phone = MiniPhoneSession();
      addTearDown(phone.dispose);
      await phone.music.loadCatalog(api.fetchMusicCatalog);
      var opened = 0;
      await tester.pumpWidget(
        AppServicesScope(
          services: musicTestServices(api),
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Column(
                  children: [
                    Expanded(child: MiniPhoneMusicPlayer(music: phone.music)),
                    MiniPhoneHomeMusicCard(
                      music: phone.music,
                      onOpen: () => opened++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await pump(tester);
      expect(find.byType(MiniMusicLikeButton), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('mini-music-like-count')),
        findsNWidgets(2),
      );
      final home = find.byType(MiniPhoneHomeMusicCard);
      final homeLike = find.descendant(
        of: home,
        matching: find.byType(MiniMusicLikeButton),
      );
      final sizes = tester.getSize(homeLike);
      final homeIcon = tester.widget<MiniIcon>(
        find.descendant(of: homeLike, matching: find.byType(MiniIcon)),
      );
      expect(homeIcon.size, 28);
      expect(sizes.height, greaterThanOrEqualTo(48));
      for (final button in find.byType(MiniMusicLikeButton).evaluate()) {
        final target = find.byElementPredicate((element) => element == button);
        final icon = find.descendant(
          of: target,
          matching: find.byType(MiniIcon),
        );
        final count = find.descendant(
          of: target,
          matching: find.byKey(const ValueKey('mini-music-like-count')),
        );
        expect(tester.getRect(icon).overlaps(tester.getRect(count)), isTrue);
        expect(
          tester.getRect(target).right - tester.getRect(count).right,
          closeTo(16 * tester.getRect(icon).width / 28, 3),
        );
      }
      transport.write = Completer<TransportResponse>();
      await tester.tap(homeLike);
      await pump(tester);
      expect(opened, 0);
      expect(find.byKey(const ValueKey('mini-music-like-count')), findsNothing);
      expect(phone.music.likes.likeCount('001.mp3'), 0);
      expect(tester.getSize(homeLike), sizes);
      transport.write!.complete(response({}, code: 5001, message: 'Rejected'));
      await pump(tester);
      expect(
        find.byKey(const ValueKey('mini-music-like-count')),
        findsNWidgets(2),
      );
      expect(phone.music.likes.likeCount('001.mp3'), 1);
      expect(find.text('Rejected'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      transport.write = Completer<TransportResponse>();
      await tester.tap(homeLike);
      await pump(tester);
      transport.write!.complete(response({}));
      await pump(tester);
      expect(phone.music.likes.likeCount('001.mp3'), 0);
      expect(find.byKey(const ValueKey('mini-music-like-count')), findsNothing);
      await tester.tap(find.descendant(of: home, matching: find.text('Track')));
      expect(opened, 1);
      expect(
        transport.requests.where((r) => r.uri.path.endsWith('/like_status')),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'badge uses the shared comment formatter and full count semantics',
    (tester) async {
      final transport = _MusicTransport();
      final api = GenesisApi(
        useMock: false,
        apiClient: ApiClient(
          baseUrl: 'https://api.example/api/',
          transport: transport,
        ),
      );
      final phone = MiniPhoneSession();
      addTearDown(phone.dispose);
      await phone.music.loadCatalog(api.fetchMusicCatalog);
      await tester.pumpWidget(
        AppServicesScope(
          services: musicTestServices(api),
          child: MaterialApp(
            home: Scaffold(
              body: MiniMusicLikeButton(
                music: phone.music,
                track: phone.music.track!,
              ),
            ),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      for (final count in [
        0,
        1,
        999,
        1000,
        1234,
        10000,
        999999,
        1000000,
        1234567890,
        1234567890123,
        9223372036854775807,
      ]) {
        transport.count = count;
        await phone.music.refreshLikes(api.fetchMusicCatalog);
        await tester.pump();
        final badge = find.byKey(const ValueKey('mini-music-like-count'));
        if (count == 0) {
          expect(badge, findsNothing);
          expect(
            tester.getRect(find.byType(MiniIcon)).right,
            closeTo(
              tester.getRect(find.byType(MiniMusicLikeButton)).right - 16,
              .1,
            ),
          );
        } else {
          expect(tester.widget<Text>(badge).data, formatStatCount(count));
          expect(
            tester
                .getRect(find.byType(MiniIcon))
                .overlaps(tester.getRect(badge)),
            isTrue,
          );
          expect(
            tester.getRect(find.byType(MiniMusicLikeButton)).right -
                tester.getRect(badge).right,
            closeTo(16, 3),
          );
        }
        expect(
          tester.getSemantics(find.byType(MiniMusicLikeButton)).value,
          '$count',
        );
        expect(
          tester
              .getSemantics(find.byType(MiniMusicLikeButton))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
