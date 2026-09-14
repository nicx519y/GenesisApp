import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import 'package:genesis_flutter_android/components/common/genesis_bottom_sheet_panel.dart';
import 'package:genesis_flutter_android/pages/me/developer_forced_login_preview.dart';
import 'package:genesis_flutter_android/ui/components/genesis_dark_close_button.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  Future<void> open(WidgetTester tester, ValueChanged<bool?> onResult) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: GenesisTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    onResult(await showDeveloperForcedLoginPreview(context)),
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

  testWidgets('mandatory login stays locked and developer exit closes it', (
    tester,
  ) async {
    bool? result;
    await open(tester, (value) => result = value);
    expect(
      tester.widget<LoginSheet>(find.byType(LoginSheet)).isDismissible,
      isFalse,
    );
    expect(find.byType(GenesisDarkCloseButton), findsNothing);
    final panel = tester.getRect(find.byType(GenesisBottomSheetPanel));
    final close = tester.getRect(
      find.byKey(const ValueKey('forced-login-preview-close')),
    );
    expect(panel.top - close.bottom, 12);
    expect(panel.right - close.right, 16);
    await tester.tapAt(const Offset(10, 260));
    await tester.binding.handlePopRoute();
    await tester.drag(find.text('Sign up to continue'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(find.byType(LoginSheet), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('forced-login-preview-close')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(LoginSheet), findsNothing);
    expect(find.text('Open preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider simulates successful login without services', (
    tester,
  ) async {
    bool? result;
    await open(tester, (value) => result = value);
    await tester.tap(find.text('Continue with Google'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(LoginSheet), findsNothing);
    expect(find.text('Open preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'closing during simulated login leaves the underlying page intact',
    (tester) async {
      bool? result;
      await open(tester, (value) => result = value);
      await tester.tap(find.text('Continue with Google'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(
        find.byKey(const ValueKey('forced-login-preview-close')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(result, isFalse);
      expect(find.byType(LoginSheet), findsNothing);
      expect(find.text('Open preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
