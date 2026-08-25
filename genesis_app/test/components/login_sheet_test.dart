import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/config/app_flavor_config.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import 'package:genesis_flutter_android/components/login_provider_button.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_semantic_colors.dart';

void main() {
  test('Apple login icon asset is pure white', () async {
    final svg = await rootBundle.loadString(
      'assets/custom-icons/svg/login_apple.svg',
    );

    expect(svg, contains('fill="#FFFFFF"'));
    expect(svg, isNot(contains('fill="#000000"')));
  });

  testWidgets('provider buttons follow the current flavor capability', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginProviderButtons(loggingInProvider: null, onLogin: (_) {}),
        ),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(
      find.text('Continue with Apple'),
      AppFlavorConfig.currentSupportsAppleSignIn
          ? findsOneWidget
          : findsNothing,
    );
  });

  testWidgets('provider buttons can expose Google only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginProviderButtons(
            loggingInProvider: null,
            onLogin: (_) {},
            showApple: false,
          ),
        ),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
  });

  testWidgets('provider icons and left-aligned labels share one axis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: LoginProviderButtons(
              loggingInProvider: null,
              onLogin: (_) {},
              showApple: true,
            ),
          ),
        ),
      ),
    );

    final googleIconSlot = find.byKey(
      const ValueKey<String>('login-provider-icon-slot-google'),
    );
    final appleIconSlot = find.byKey(
      const ValueKey<String>('login-provider-icon-slot-apple'),
    );
    final googleLabel = find.text('Continue with Google');
    final appleLabel = find.text('Continue with Apple');

    expect(
      tester.getCenter(googleIconSlot).dx,
      closeTo(tester.getCenter(appleIconSlot).dx, 0.01),
    );
    expect(
      tester.getTopLeft(googleLabel).dx,
      closeTo(tester.getTopLeft(appleLabel).dx, 0.01),
    );
    expect(tester.widget<Text>(googleLabel).textAlign, TextAlign.left);
    expect(tester.widget<Text>(appleLabel).textAlign, TextAlign.left);
  });

  testWidgets('login sheet inherits the standard panel title style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoginSheet(onLogin: (_) async => false)),
      ),
    );

    final title = tester.widget<Text>(find.text('Sign in to continue'));
    expect(
      title.style,
      GenesisBottomSheetPanel.titleStyle.copyWith(
        color: GenesisSemanticColors.worldoLight().textPrimary,
      ),
    );
  });

  testWidgets('login sheet drops the outline and hugs its content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoginSheet(onLogin: (_) async => false)),
      ),
    );

    final panel = find.byKey(const ValueKey<String>('login-sheet-outline'));
    final material = tester.widget<Material>(
      find.descendant(of: panel, matching: find.byType(Material)).first,
    );
    final shape = material.shape! as RoundedRectangleBorder;

    expect(shape.borderRadius, GenesisBottomSheetPanel.borderRadius);
    expect(shape.side, BorderSide.none);
    expect(
      tester.widget<GenesisBottomSheetPanel>(panel).height,
      isNull,
      reason: 'the sheet is content-sized, not pinned to a fixed height',
    );
    expect(
      find.byKey(const ValueKey<String>('signed-out-signup-bonus')),
      findsNothing,
      reason: 'the sign-up bonus rides the signed-out page only',
    );
  });

  testWidgets('login sheet keeps the global transparent status bar style', (
    tester,
  ) async {
    final calls = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
            calls.add(Map<dynamic, dynamic>.from(call.arguments as Map));
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AnnotatedRegion<SystemUiOverlayStyle>(
          value: kGenesisDefaultSystemUiOverlayStyle,
          child: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => showLoginSheet(
                    context: context,
                    onLogin: (_) async => false,
                  ),
                  child: const Text('Open login'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    calls.clear();

    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();
    final openingStatusBarCalls = calls
        .where((call) => call['statusBarColor'] != null)
        .toList(growable: false);
    expect(
      openingStatusBarCalls.every(
        (call) => call['statusBarColor'] == Colors.transparent.toARGB32(),
      ),
      isTrue,
    );
    expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.idle();

    expect(
      calls.where(
        (call) =>
            call['statusBarColor'] != null &&
            call['statusBarColor'] != Colors.transparent.toARGB32(),
      ),
      isEmpty,
    );
    expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });
}
