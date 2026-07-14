import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/gem_balance_prompt.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
  testWidgets('insufficient balance prompt opens Gem Wallet from root', (
    tester,
  ) async {
    await _pumpPrompt(
      tester,
      const GemBalanceAlert(kind: GemBalanceAlertKind.insufficient),
    );

    expect(find.text(insufficientGemBalancePrompt), findsOneWidget);
    expect(find.text(rechargeGemBalanceAction), findsOneWidget);

    await tester.tap(find.text(rechargeGemBalanceAction));
    await tester.pumpAndSettle();

    expect(find.text('Gem Wallet destination'), findsOneWidget);
  });

  testWidgets('low balance prompt uses low balance copy', (tester) async {
    await _pumpPrompt(
      tester,
      const GemBalanceAlert(kind: GemBalanceAlertKind.low, balance: 10),
    );

    expect(find.text(lowGemBalancePrompt), findsOneWidget);
    expect(find.text(rechargeGemBalanceAction), findsOneWidget);
  });
}

Future<void> _pumpPrompt(WidgetTester tester, GemBalanceAlert alert) async {
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        RouteNames.gemWallet: (_) =>
            const Scaffold(body: Center(child: Text('Gem Wallet destination'))),
      },
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showGemBalancePrompt(context, alert),
            child: const Text('Show prompt'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Show prompt'));
  await tester.pumpAndSettle();
}
