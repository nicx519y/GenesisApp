import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_push_banner.dart';

void main() {
  testWidgets('root banner stays above nested routes and allows page actions', (
    tester,
  ) async {
    late BuildContext pageContext;
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              pageContext = context;
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => presses++,
                    child: const Text('Page action'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    final banner = showGenesisPushBanner(
      context: pageContext,
      title: 'Photo ready',
      message: 'Your photo is saved.',
    );
    var closed = false;
    banner.closed.then((_) => closed = true);
    await tester.pumpAndSettle();

    expect(find.byType(GenesisPushBanner), findsOneWidget);
    expect(find.text('Photo ready'), findsOneWidget);
    expect(find.text('Your photo is saved.'), findsOneWidget);
    expect(ModalRoute.of(pageContext)!.isCurrent, isTrue);
    expect(
      tester.getTopLeft(find.byType(GenesisPushBanner)).dy,
      closeTo(8, 0.01),
    );
    await tester.tap(find.text('Page action'));
    await tester.pump();
    expect(presses, 1);
    expect(closed, isFalse);

    await tester.pump(genesisPushBannerDisplayDuration);
    await tester.pumpAndSettle();
    expect(find.byType(GenesisPushBanner), findsNothing);
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap and session cleanup both release the banner once', (
    tester,
  ) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      ),
    );

    for (final tapToDismiss in [true, false]) {
      final banner = showGenesisPushBanner(
        context: pageContext,
        title: 'Photo failed',
        message: 'Please try again later.',
      );
      var closes = 0;
      banner.closed.then((_) => closes++);
      await tester.pumpAndSettle();
      if (tapToDismiss) {
        await tester.tap(find.text('Photo failed'));
        await tester.pumpAndSettle();
      }
      banner.dismiss();
      banner.dismiss();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(GenesisPushBanner), findsNothing);
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    }
  });
}
