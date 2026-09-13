import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_sheet.dart';
import 'package:genesis_flutter_android/pages/me/developer_personalization_preview.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

const formTitle = 'Personalize Your Worldo Experience';
Finder control(String name) => find.byKey(ValueKey('personalization-$name'));

void main() {
  testWidgets(
    'developer menu opens distinct states and can close locked form',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: GenesisTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDeveloperPersonalizationPreview(
                  context,
                  PersonalizationPreviewScenario.newUser,
                ),
                child: const Text('Open developer preview'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open developer preview'));
      await tester.pumpAndSettle();
      expect(control('sign-in'), findsOneWidget);
      final panel = tester.getRect(find.byType(GenesisBottomSheetPanel));
      final header = tester.getRect(control('header'));
      final body = tester.getRect(control('body'));
      final titleStyle = tester.widget<Text>(control('header-title')).style;
      expect(header.height, 68);
      expect(body.top, header.bottom);
      expect(titleStyle?.fontSize, 18);
      void expectSameHeader() {
        expect(tester.getRect(control('header')), header);
        expect(tester.getRect(control('body')), body);
        expect(tester.widget<Text>(control('header-title')).style, titleStyle);
        expect(
          tester.getRect(control('header-title')).center.dy,
          closeTo(header.center.dy, .01),
        );
      }

      Future<void> choose(String scenario) async {
        await tester.tap(
          find.byKey(const ValueKey('onboarding-preview-options')),
        );
        await tester.pumpAndSettle();
        final item = find.byKey(ValueKey('onboarding-scenario-$scenario'));
        await tester.ensureVisible(item);
        await tester.tap(item);
        await tester.pumpAndSettle();
      }

      await choose('signedInEmpty');
      expect(find.text(formTitle), findsOneWidget);
      expect(control('sign-in'), findsNothing);
      expect(
        tester.widget<GenesisPrimaryButton>(control('continue')).onPressed,
        isNull,
      );
      expect(tester.getRect(find.byType(GenesisBottomSheetPanel)), panel);
      expectSameHeader();
      await choose('signInComplete');
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text(formTitle), findsNothing);
      expect(tester.getRect(find.byType(GenesisBottomSheetPanel)), panel);
      expectSameHeader();
      await choose('subscription');
      expect(find.text('Skip'), findsOneWidget);
      expect(control('subscription-icon'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('pro-benefits-card'))).top,
        tester.getRect(control('body')).top,
      );
      expect(find.text('Buy Gems'), findsNothing);
      expect(tester.getRect(find.byType(GenesisBottomSheetPanel)), panel);
      expectSameHeader();
      await choose('newUser');
      expect(control('sign-in'), findsOneWidget);
      await choose('close');
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(find.text('Open developer preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Developer close removes preview underneath another route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: GenesisTheme.dark(),
        home: const Scaffold(body: Text('Underlying page')),
      ),
    );
    final preview = showDeveloperPersonalizationPreview(
      navigatorKey.currentContext!,
      PersonalizationPreviewScenario.newUser,
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDeveloperPersonalizationPreview(
              context,
              PersonalizationPreviewScenario.close,
            ),
            child: const Text('Developer Close sheet'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(PersonalizationSheet, skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.text('Developer Close sheet'));
    await tester.pumpAndSettle();
    await preview;
    expect(
      find.byType(PersonalizationSheet, skipOffstage: false),
      findsNothing,
    );
    expect(find.text('Developer Close sheet'), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Underlying page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  Future<void> open(
    WidgetTester tester, {
    PersonalizationProfile? account = const PersonalizationProfile(),
    bool fail = false,
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPersonalizationSheet(
                  context: context,
                  onSignIn: (_) async {
                    if (fail) throw StateError('Preview failure');
                    return account;
                  },
                  subscriptionBuilder: (_) => ProSubscriptionContent(
                    topSpacing: 0,
                    horizontalInset: 0,
                    productsLoader: loadPersonalizationPreviewCatalog,
                    purchaseHandler: (_) async {},
                  ),
                ),
                child: const Text('Open preview'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String name) async {
    await tester.ensureVisible(control(name));
    await tester.tap(control(name));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester) =>
      tester.widget<GenesisPrimaryButton>(control('continue')).onPressed !=
      null;
  Future<void> login(WidgetTester tester) async {
    await tap(tester, 'sign-in');
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('UPDATE_PERSONALIZATION_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find
          .ancestor(
            of: find.byType(PersonalizationSheet),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'docs/design/personalization-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'required choices, locked dismissal and fixed height across all steps',
    (tester) async {
      final font = FontLoader('Inter')
        ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      await open(tester);
      final panel = tester.getRect(find.byType(GenesisBottomSheetPanel));
      final header = tester.getRect(control('header'));
      final body = tester.getRect(control('body'));
      final titleStyle = tester.widget<Text>(control('header-title')).style;
      expect(header.height, 68);
      expect(body.top, header.bottom);
      expect(titleStyle?.fontSize, 18);
      void expectSameHeader() {
        expect(tester.getRect(control('header')), header);
        expect(tester.getRect(control('body')), body);
        expect(tester.widget<Text>(control('header-title')).style, titleStyle);
        expect(
          tester.getRect(control('header-title')).center.dy,
          closeTo(header.center.dy, .01),
        );
      }

      expectSameHeader();
      expect(enabled(tester), isFalse);
      await tester.tapAt(const Offset(10, 20));
      await tester.binding.handlePopRoute();
      await tester.drag(find.text(formTitle), const Offset(0, 250));
      await tester.pumpAndSettle();
      expect(find.text(formTitle), findsOneWidget);
      await capture(tester, 'empty');
      await tap(tester, 'Female');
      expect(enabled(tester), isFalse);
      await tap(tester, '25-34');
      expect(enabled(tester), isTrue);
      final continueRect = tester.getRect(control('continue'));
      expect(continueRect.left - panel.left, 16);
      expect(panel.right - continueRect.right, 16);
      await capture(tester, 'selected');
      await tap(tester, 'sign-in');
      expect(tester.getRect(find.byType(GenesisBottomSheetPanel)), panel);
      expectSameHeader();
      await capture(tester, 'login');
      await tap(tester, 'back');
      expect(enabled(tester), isTrue);
      await tap(tester, 'continue');
      expect(tester.getRect(find.byType(GenesisBottomSheetPanel)), panel);
      expectSameHeader();
      expect(find.text('Buy Gems'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
      expect(control('subscription-icon'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('pro-benefits-card'))).top,
        tester.getRect(control('body')).top,
      );
      for (final key in ['pro-benefits-card', 'pro-subscribe-button']) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.left - panel.left, 16);
        expect(panel.right - rect.right, 16);
      }
      await capture(tester, 'subscription');
      await tap(tester, 'skip');
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('complete account closes without subscription', (tester) async {
    await open(
      tester,
      account: const PersonalizationProfile(
        gender: PersonalizationGender.nonBinary,
        age: PersonalizationAge.age45plus,
      ),
    );
    await login(tester);
    expect(find.byType(PersonalizationSheet), findsNothing);
    expect(find.byType(ProSubscriptionContent), findsNothing);
  });
  testWidgets('unfilled account hides login link and preserves local draft', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'Female');
    await tap(tester, '35-44');
    await login(tester);
    expect(find.text('Complete your profile to continue.'), findsOneWidget);
    expect(control('sign-in'), findsNothing);
    expect(enabled(tester), isTrue);
    await tap(tester, 'continue');
    expect(find.text('Skip'), findsOneWidget);
  });
  testWidgets('empty account requires both fields', (tester) async {
    await open(tester);
    await login(tester);
    expect(find.text(formTitle), findsOneWidget);
    expect(enabled(tester), isFalse);
    await tap(tester, 'Male');
    expect(enabled(tester), isFalse);
  });
  for (final fail in [false, true]) {
    testWidgets('canceled or failed login keeps sheet open: fail=$fail', (
      tester,
    ) async {
      await open(tester, account: null, fail: fail);
      await login(tester);
      expect(control('back'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(formTitle), findsOneWidget);
    });
  }
  testWidgets('small screen with large text keeps form scrollable', (
    tester,
  ) async {
    await open(tester, size: const Size(320, 568), scale: 1.5);
    await tap(tester, 'Non_binary');
    await tap(tester, '45+');
    await tester.ensureVisible(control('continue'));
    await tester.pumpAndSettle();
    expect(enabled(tester), isTrue);
    await tap(tester, 'continue');
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
