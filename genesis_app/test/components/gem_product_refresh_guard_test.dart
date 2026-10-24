import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/gem_purchase_state.dart';

void main() {
  const loadingKey = ValueKey<String>('gem-products-global-loading');

  testWidgets(
    'loading blocks the whole root overlay and restores interaction',
    (tester) async {
      final loading = ValueNotifier(false);
      addTearDown(loading.dispose);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextButton(
                  key: const ValueKey('outside'),
                  onPressed: () => taps++,
                  child: const Text('Outside'),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: loading,
                  builder: (_, busy, __) => GemProductRefreshGuard(
                    isLoading: busy,
                    child: const Text('Products'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      loading.value = true;
      await tester.pump();
      await tester.pump();
      expect(find.byKey(loadingKey), findsOneWidget);
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('outside'))),
      );
      expect(taps, 0);
      loading.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(loadingKey), findsNothing);
      await tester.tap(find.byKey(const ValueKey('outside')));
      expect(taps, 1);
    },
  );

  testWidgets(
    'simultaneous purchase surfaces share one barrier and clean up on dispose',
    (tester) async {
      final first = ValueNotifier(true);
      final second = ValueNotifier(true);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                for (final value in [first, second])
                  ValueListenableBuilder<bool>(
                    valueListenable: value,
                    builder: (_, busy, __) => GemProductRefreshGuard(
                      isLoading: busy,
                      child: const Text('Products'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(loadingKey), findsOneWidget);
      first.value = false;
      await tester.pump();
      await tester.pump();
      expect(find.byKey(loadingKey), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(find.byKey(loadingKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
