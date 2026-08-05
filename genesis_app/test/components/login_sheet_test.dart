import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';

void main() {
  testWidgets('login sheet inherits the standard panel title style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LoginSheet(onLogin: (_) async => false)),
      ),
    );

    final title = tester.widget<Text>(find.text('Sign in to continue'));
    expect(title.style, GenesisBottomSheetPanel.titleStyle);
  });

  testWidgets('login sheet keeps the previous status bar style', (
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
    GenesisSystemUiChrome.applyDefault();
    await tester.pump();
    calls.clear();

    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();
    final openingStatusBarCalls = calls
        .where((call) => call['statusBarColor'] != null)
        .toList(growable: false);
    expect(
      openingStatusBarCalls.every(
        (call) => call['statusBarColor'] == Colors.white.toARGB32(),
      ),
      isTrue,
    );
    expect(SystemChrome.latestStyle?.statusBarColor, Colors.white);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.idle();

    expect(
      calls.where(
        (call) =>
            call['statusBarColor'] != null &&
            call['statusBarColor'] != Colors.white.toARGB32(),
      ),
      isEmpty,
    );
    expect(SystemChrome.latestStyle?.statusBarColor, Colors.white);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });

  testWidgets('login sheet keeps a transparent page status bar', (
    tester,
  ) async {
    const transparentPageStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );
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
          value: transparentPageStyle,
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
    expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    expect(
      calls.where(
        (call) =>
            call['statusBarColor'] != null &&
            call['statusBarColor'] != Colors.transparent.toARGB32(),
      ),
      isEmpty,
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.idle();

    expect(SystemChrome.latestStyle?.statusBarColor, Colors.transparent);
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
  });
}
