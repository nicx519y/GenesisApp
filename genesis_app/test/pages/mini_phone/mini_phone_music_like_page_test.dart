import 'dart:async';
import 'dart:convert';

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
  final requests = <TransportRequest>[];
  Completer<TransportResponse>? write;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/like_status')) {
      return response({
        'file': request.uri.queryParameters['file'],
        'is_liked': liked,
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
      expect(transport.requests.single.uri.queryParameters, {
        'file': '001.mp3',
      });

      transport.write = Completer<TransportResponse>();
      await tester.tap(heart(true));
      await pump(tester);
      expect(heart(false), findsOneWidget);
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
}
