import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/components/login_provider_button.dart';
import 'package:genesis_flutter_android/components/me/signed_out_me_view.dart';
import 'package:genesis_flutter_android/pages/me/force_login_page.dart';
import 'package:genesis_flutter_android/ui/components/genesis_bottom_navigation.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

class _Sink implements GenesisTelemetrySink {
  final events = <GenesisTelemetryEvent>[];
  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    events.add(event);
  }

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}
  @override
  Future<void> setContext(GenesisTelemetryContext context) async {}
  @override
  Future<void> setUserId(String? uid) async {}
}

void main() {
  tearDown(GenesisTelemetry.resetForTesting);
  testWidgets(
    'force login lifts actions by tab height and keeps legal text fixed',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget app(Widget body) =>
          MaterialApp(theme: GenesisTheme.dark(), home: body);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SignedOutMeView(loggingInProvider: null, onLogin: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final promo = find.byKey(const ValueKey('signed-out-gems-promo'));
      final buttons = find.byKey(const ValueKey('signed-out-login-buttons'));
      final legal = find.byType(LoginLegalText);
      final promoY = tester.getTopLeft(promo).dy;
      final buttonsY = tester.getTopLeft(buttons).dy;
      final legalY = tester.getTopLeft(legal).dy;
      final logoY = tester
          .getTopLeft(find.byKey(const Key('signed_out_worldo_logo')))
          .dy;
      await tester.pumpWidget(app(const ForceLoginPage()));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(promo).dy,
        closeTo(promoY - GenesisBottomNavigation.defaultHeight, 0.01),
      );
      expect(
        tester.getTopLeft(buttons).dy,
        closeTo(buttonsY - GenesisBottomNavigation.defaultHeight, 0.01),
      );
      expect(tester.getTopLeft(legal).dy, closeTo(legalY, 0.01));
      expect(
        tester.getTopLeft(find.byKey(const Key('signed_out_worldo_logo'))).dy,
        closeTo(logoY, 0.01),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'force login pageview occurs once per opening, never on rebuild',
    (tester) async {
      final sink = _Sink();
      GenesisTelemetry.setSinkForTesting(sink);
      Widget app() =>
          MaterialApp(theme: GenesisTheme.dark(), home: const ForceLoginPage());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      List<GenesisTelemetryEvent> views() => sink.events
          .where((e) => e.category == 'collect.log' && e.name == 'force_login')
          .toList();
      expect(views(), hasLength(1));
      expect(views().single.data, {
        'action_type': 'pageview',
        'action': 'force_login',
      });
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(views(), hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(views(), hasLength(2));
    },
  );
}
