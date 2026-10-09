import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/version/force_upgrade_gate.dart';
import 'package:genesis_flutter_android/network/models/app_version_check.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';

void main() {
  testWidgets('upgrade fallback copy uses localized messages', (tester) async {
    final response = AppVersionCheckResponse.fromJson({
      'latest_version_name': '2.3.4',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: ForceUpgradePage(
          response: response,
          onUpdate: () {},
          hasCheckError: true,
        ),
      ),
    );

    expect(find.text('Update required'), findsOneWidget);
    expect(
      find.text(
        'Please update to the latest version to continue using Worldo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Version 2.3.4'), findsOneWidget);
    expect(
      find.text('Unable to refresh update status. Please update to continue.'),
      findsOneWidget,
    );
  });

  for (final preview in [false, true]) {
    testWidgets(
      'upgrade page dark surface and return policy preview=$preview',
      (tester) async {
        var updates = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ForceUpgradePage(
                      response: AppVersionCheckResponse.none,
                      preview: preview,
                      onUpdate: () => updates++,
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          GenesisColors.darkBackground,
        );
        if (preview) {
          expect(
            tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
            GenesisColors.darkBackground,
          );
          expect(
            tester.widget<Icon>(find.byIcon(Icons.arrow_back_ios_new)).color,
            GenesisColors.darkTextPrimary,
          );
        }
        await tester.tap(find.text('Update now'));
        expect(updates, 1);
        final context = tester.element(find.byType(ForceUpgradePage));
        await Navigator.of(context).maybePop();
        await tester.pumpAndSettle();
        expect(
          find.byType(ForceUpgradePage),
          preview ? findsNothing : findsOneWidget,
        );
      },
    );
  }
}
