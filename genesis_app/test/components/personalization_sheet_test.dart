import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/components/gems/purchase_options_sheet.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_sheet.dart';
import 'package:genesis_flutter_android/icons/custom_icon_assets.dart';
import 'package:genesis_flutter_android/pages/me/developer_personalization_preview.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

const formTitle = 'Personalize Your Worldo Experience';
Finder control(String name) => find.byKey(ValueKey('personalization-$name'));

void main() {
  testWidgets(
    'onboarding preview shares the purchase sheet layout and has both tiers',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: GenesisTheme.dark(),
          home: const Scaffold(),
        ),
      );
      final preview = showDeveloperPersonalizationPreview(
        navigatorKey.currentContext!,
        PersonalizationPreviewScenario.subscription,
      );
      await tester.pumpAndSettle();

      final cards = find.byKey(const ValueKey('membership-subscription-pages'));
      final button = find.byKey(const ValueKey('pro-subscribe-button'));
      List<Rect> layout() => [
        for (final finder in [
          find.byType(GenesisBottomSheetPanel),
          find.byType(GenesisActionSheetHeader),
          cards,
          button,
          find.text('Privacy Policy'),
        ])
          tester.getRect(finder),
      ];
      void expectHeader(String title, String icon) {
        expect(
          find.descendant(of: control('header'), matching: find.text(title)),
          findsOneWidget,
        );
        final crown = tester.widget<SvgPicture>(control('subscription-icon'));
        expect((crown.bytesLoader as SvgAssetLoader).assetName, icon);
      }

      expectHeader('Worldo Premium', proCrownGoldIconAsset);
      final previewLayout = layout();
      expect(previewLayout.first.height, closeTo(844 * .8, .01));
      expect(previewLayout[1].height, 68);
      expect(button.hitTestable(), findsOneWidget);
      expect(
        tester.widget<GenesisPrimaryButton>(button).label,
        r'Yearly: $59.99',
      );

      await tester.drag(cards, const Offset(-160, 0));
      await tester.pumpAndSettle();
      expectHeader('Worldo Deluxe', proCrownDeluxeIconAsset);
      expect(
        find.text('Up to 18,000 Gems Monthly', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(r'$44.90'), findsOneWidget);
      expect(
        tester.widget<GenesisPrimaryButton>(button).label,
        r'Yearly: $449',
      );
      expect(find.text('Skip'), findsOneWidget);

      await tester.drag(cards, const Offset(160, 0));
      await tester.pumpAndSettle();
      expectHeader('Worldo Premium', proCrownGoldIconAsset);
      expect(
        tester.widget<GenesisPrimaryButton>(button).label,
        r'Yearly: $59.99',
      );

      await tester.tap(control('skip'));
      await tester.pumpAndSettle();
      await preview;

      final standard = showGenesisModalBottomSheet<void>(
        context: navigatorKey.currentContext!,
        isScrollControlled: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: PurchaseSheetPanel.heightFactor,
          alignment: Alignment.bottomCenter,
          child: PurchaseOptionsSheet(
            initialTab: PurchaseSheetTab.subscription,
            membershipProductsLoader: loadPersonalizationPreviewCatalog,
            gemsBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(layout(), previewLayout);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await standard;
      expect(tester.takeException(), isNull);
    },
  );

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
      expect(
        tester.getRect(control('sign-in')).bottom,
        closeTo(panel.bottom, .01),
      );
      final options = tester.getRect(
        find.byKey(const ValueKey('onboarding-preview-options')),
      );
      expect(panel.top - options.bottom, 12);
      expect(panel.right - options.right, 16);
      final header = tester.getRect(control('header'));
      final body = tester.getRect(control('body'));
      final titleStyle = tester.widget<Text>(control('header-title')).style;
      expect(header.height, 68);
      expect(body.top, header.bottom);
      expect(titleStyle?.fontSize, 18);
      void expectSameHeader() {
        final current = tester.getRect(control('header'));
        expect(current.height, header.height);
        expect(tester.getRect(control('body')).top, current.bottom);
        expect(tester.widget<Text>(control('header-title')).style, titleStyle);
        expect(
          tester.getRect(control('header-title')).center.dy,
          closeTo(current.center.dy, .01),
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
      expect(
        tester.getRect(control('continue')).bottom,
        closeTo(panel.bottom, .01),
      );
      expectSameHeader();
      await choose('signInComplete');
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text(formTitle), findsNothing);
      expect(tester.getRect(find.byType(GenesisBottomSheetPanel)).height, 600);
      expectSameHeader();
      await choose('subscription');
      expect(find.text('Skip'), findsOneWidget);
      expect(control('subscription-icon'), findsOneWidget);
      expect(tester.getRect(control('header')).height, header.height);
      expect(find.text('Buy Gems'), findsNothing);
      expect(
        tester.getRect(find.byType(GenesisBottomSheetPanel)).height,
        closeTo(844 * .8, .01),
      );
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
    double safeTop = 47,
    double safeBottom = 34,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.viewPadding = FakeViewPadding(top: safeTop, bottom: safeBottom);
    tester.view.padding = FakeViewPadding(top: safeTop, bottom: safeBottom);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark().copyWith(platform: platform),
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
                  form: personalizationPreviewForm,
                  onSubmit: (_) async => PersonalizationNextStep.subscription,
                  context: context,
                  onSignIn: (_) async {
                    if (fail) throw StateError('Preview failure');
                    return account;
                  },
                  subscriptionBuilder: (_) =>
                      ProSubscriptionContent.purchaseSheet(
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
    await Scrollable.ensureVisible(
      tester.element(control(name)),
      alignment: .5,
    );
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

  testWidgets('required choices and locked dismissal across onboarding steps', (
    tester,
  ) async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await open(tester);
    final panel = tester.getRect(find.byType(GenesisBottomSheetPanel));
    expect(panel.height, lessThan(600));
    expect(panel.bottom, 844);
    expect(
      panel.bottom - tester.getRect(control('sign-in')).bottom,
      closeTo(34, .01),
    );
    final header = tester.getRect(control('header'));
    final body = tester.getRect(control('body'));
    final titleStyle = tester.widget<Text>(control('header-title')).style;
    expect(header.height, 68);
    expect(body.top, header.bottom);
    expect(titleStyle?.fontSize, 18);
    void expectSameHeader() {
      final current = tester.getRect(control('header'));
      expect(current.height, header.height);
      expect(tester.getRect(control('body')).top, current.bottom);
      expect(tester.widget<Text>(control('header-title')).style, titleStyle);
      expect(
        tester.getRect(control('header-title')).center.dy,
        closeTo(current.center.dy, .01),
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
    await tap(tester, 'continue');
    expect(find.text('Please select your gender and age.'), findsOneWidget);
    expect(find.text(formTitle), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, 'Female');
    expect(enabled(tester), isFalse);
    await tap(tester, 'continue');
    expect(find.text('Please select your age.'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
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
    expect(tester.getRect(find.byType(GenesisBottomSheetPanel)), panel);
    expect(enabled(tester), isTrue);
    final animatedSheet = find.byType(PersonalizationSheet);
    await tester.tap(control('continue'));
    await tester.pump();
    expect(tester.getRect(animatedSheet), panel);
    await tester.pump(const Duration(milliseconds: 120));
    final expanding = tester.getRect(animatedSheet);
    expect(expanding.bottom, panel.bottom);
    expect(expanding.height, greaterThan(panel.height));
    expect(expanding.height, lessThan(844 * .8));
    expect(tester.getRect(control('header')).top, expanding.top);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(GenesisBottomSheetPanel)).height,
      closeTo(844 * .8, .01),
    );
    expect(tester.getRect(control('header')).height, header.height);
    expect(find.text('Buy Gems'), findsNothing);
    expect(find.text('Skip'), findsOneWidget);
    expect(control('subscription-icon'), findsOneWidget);
    expect(
      tester
          .getRect(find.byKey(const ValueKey('membership-subscription-pages')))
          .top,
      closeTo(tester.getRect(control('body')).top, .01),
    );
    final button = find.byKey(const ValueKey('pro-subscribe-button'));
    final rect = tester.getRect(button);
    expect(rect.left - panel.left, 16);
    expect(panel.right - rect.right, 16);
    expect(button.hitTestable(), findsOneWidget);
    await capture(tester, 'subscription');
    await tap(tester, 'skip');
    expect(find.byType(PersonalizationSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('onboarding only allows explicit dismissal on $platform', (
      tester,
    ) async {
      await open(tester, platform: platform);

      Future<void> expectDismissalBlocked() async {
        final panel = tester.getRect(find.byType(GenesisBottomSheetPanel));
        await tester.dragFrom(Offset(1, panel.top + 100), const Offset(300, 0));
        await tester.pumpAndSettle();
        expect(find.byType(PersonalizationSheet), findsOneWidget);
        await tester.dragFrom(
          tester.getCenter(control('header')),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();
        expect(find.byType(PersonalizationSheet), findsOneWidget);
        await tester.tapAt(const Offset(10, 100));
        await tester.pumpAndSettle();
        expect(find.byType(PersonalizationSheet), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(PersonalizationSheet), findsOneWidget);
        expect(tester.getRect(find.byType(GenesisBottomSheetPanel)), panel);
      }

      await expectDismissalBlocked();
      await tap(tester, 'Female');
      await tap(tester, '25-34');
      await tap(tester, 'continue');
      expect(control('skip'), findsOneWidget);
      await expectDismissalBlocked();
      await tap(tester, 'skip');
      expect(find.byType(PersonalizationSheet), findsNothing);
      expect(find.text('Open preview'), findsOneWidget);
    });
  }

  testWidgets('complete account closes without subscription', (tester) async {
    await open(
      tester,
      account: const PersonalizationProfile(
        gender: 'Non_binary',
        age: '45+',
        completed: true,
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
    await tap(tester, '18-24');
    expect(enabled(tester), isFalse);
    await tap(tester, 'continue');
    expect(find.text('Please select your gender.'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tap(tester, 'Male');
    expect(enabled(tester), isTrue);
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
    await open(
      tester,
      size: const Size(320, 500),
      scale: 1.5,
      safeTop: 20,
      safeBottom: 24,
    );
    final scroll = Scrollable.of(tester.element(control('continue'))).position;
    expect(scroll.maxScrollExtent, greaterThan(0));
    final sheet = find.byType(PersonalizationSheet);
    final form = tester.getRect(sheet);
    await tap(tester, 'sign-in');
    expect(tester.getRect(sheet), form);
    await tap(tester, 'back');
    await tap(tester, 'Non_binary');
    await tap(tester, '45+');
    await tester.ensureVisible(control('continue'));
    await tester.pumpAndSettle();
    expect(enabled(tester), isTrue);
    await tester.tap(control('continue'));
    await tester.pump();
    expect(tester.getRect(sheet), form);
    await tester.pump(const Duration(milliseconds: 120));
    final contracting = tester.getRect(sheet);
    expect(contracting.bottom, 500);
    expect(contracting.height, lessThan(form.height));
    expect(contracting.height, greaterThan(400));
    await tester.pumpAndSettle();
    expect(tester.getSize(sheet).height, 400);
    expect(find.text('Skip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
