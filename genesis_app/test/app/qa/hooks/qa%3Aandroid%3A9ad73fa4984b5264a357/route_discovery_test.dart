import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/hooks/qa%253Aandroid%253A9ad73fa4984b5264a357/contract_fixture.dart';

void main() {
  testWidgets('parent snapshot excludes a nested navigator current route', (
    tester,
  ) async {
    final outer = GlobalKey<NavigatorState>(),
        inner = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: outer,
        home: Scaffold(
          body: Navigator(
            key: inner,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => const Text('nested')),
          ),
        ),
      ),
    );
    final routes = currentRoutes(outer.currentState!);
    expect(routes, hasLength(1));
    expect(routes.single.navigator, same(outer.currentState));
    expect(
      currentRoutes(inner.currentState!).single.navigator,
      same(inner.currentState),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'route discovery preserves the tree across cover, restore and removal',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: const Scaffold(body: Text('original')),
        ),
      );
      final nav = key.currentState!;
      final original = currentRoutes(nav).single;
      for (var i = 0; i < 2; i++) {
        final cover = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('cover')),
        );
        nav.push(cover);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(currentRoutes(nav), {cover});
        expect(original.isCurrent, false);
        nav.removeRoute(cover);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(currentRoutes(nav), {original});
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
