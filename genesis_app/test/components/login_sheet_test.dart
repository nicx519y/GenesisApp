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
        color: GenesisSemanticColors.light().textPrimary,
      ),
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
