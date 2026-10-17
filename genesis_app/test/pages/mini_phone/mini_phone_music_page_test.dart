import 'dart:convert';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import '../../support/mini_phone_music_services.dart';
import 'package:genesis_flutter_android/network/models/music.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';

class _UnavailableMusicTransport implements HttpTransport {
  int requests = 0;
  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests++;
    return TransportResponse(
      statusCode: 200,
      headers: const {},
      body: jsonEncode({
        'err_no': 5001,
        'err_msg': 'Music unavailable',
        'data': {},
      }),
    );
  }
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );
  tearDown(
    () => VisibilityDetectorController.instance.updateInterval = const Duration(
      milliseconds: 500,
    ),
  );
  testWidgets(
    'music screen renders catalogue metadata without fixture counts or duration',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = GenesisApi(
        useMock: false,
        apiClient: ApiClient(
          baseUrl: 'https://api.example/api/',
          transport: LocalMockGenesisTransport.instance,
          defaultHeaders: {'Authorization': 'Bearer test-music-session'},
        ),
      );
      Widget host(Widget page) => AppServicesScope(
        services: musicTestServices(api),
        child: MaterialApp(home: page),
      );
      final phone = MiniPhoneSession();
      addTearDown(phone.dispose);
      await phone.music.loadCatalog(
        () async => const MusicCatalog(
          preUrl: 'https://cdn.example/music/',
          tracks: [
            MusicTrack(
              file: '001.mp3',
              audioUrl: 'https://cdn.example/music/001.mp3',
              sourceWorldoId: 'o_test',
              sourceWorldoName: 'My Hero Academia',
              artist: 'Katsuki Bakugo',
              title: 'Number One Lungs',
              coverUrl: 'assets/mini_phone/loc_1_1_1.jpg',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        host(
          MiniPhonePage(session: phone, initialScreen: MiniPhoneScreen.music),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Number One Lungs'), findsOneWidget);
      expect(find.text('Katsuki Bakugo'), findsOneWidget);
      expect(find.text('From #My Hero Academia'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
      expect(find.text('128'), findsNothing);
      expect(find.text('A Midnight Waltz'), findsNothing);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      phone.music.activated = true;
      addTearDown(() => phone.music.activated = false);
      await tester.pumpWidget(host(MiniPhonePage(session: phone)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final homeCard = find.byKey(const ValueKey('mini-phone-home-music'));
      expect(homeCard, findsOneWidget);
      expect(
        find.descendant(of: homeCard, matching: find.text('Number One Lungs')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: homeCard, matching: find.text('Katsuki Bakugo')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Slider>(
              find.descendant(of: homeCard, matching: find.byType(Slider)),
            )
            .onChanged,
        isNull,
      );
      expect(find.text('A Midnight Waltz'), findsNothing);
      await tester.tap(
        find.descendant(of: homeCard, matching: find.text('Number One Lungs')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('From #My Hero Academia'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'music catalog failure uses Toast and pull refresh without an error panel',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final transport = _UnavailableMusicTransport();
      final api = GenesisApi(
        useMock: false,
        apiClient: ApiClient(
          baseUrl: 'https://api.example/api/',
          transport: transport,
          defaultHeaders: {'Authorization': 'Bearer test-music-session'},
        ),
      );
      final phone = MiniPhoneSession();
      addTearDown(phone.dispose);
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
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      const error = 'Unable to load music. Please retry.';
      expect(find.text(error), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(
        find.descendant(of: find.byType(ListView), matching: find.text(error)),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(error), findsNothing);
      final before = transport.requests;
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(transport.requests, greaterThan(before));
      expect(find.text(error), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
