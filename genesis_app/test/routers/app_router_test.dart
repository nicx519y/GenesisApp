import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_page_result.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
  test('world route returns a typed delete result', () {
    final route = AppRouter.onGenerateRoute(
      const RouteSettings(
        name: RouteNames.world,
        arguments: <String, Object?>{'wid': 'w_test'},
      ),
    );

    expect(route, isA<MaterialPageRoute<WorldPageResult>>());
  });

  testWidgets('page not found route shows text without retry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: RouteNames.pageNotFound,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    expect(find.text('Page not found.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('unknown route falls back to page not found', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/missing',
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );

    expect(find.text('Page not found.'), findsOneWidget);
  });

  testWidgets('location chat route fades during iOS transitions', (
    WidgetTester tester,
  ) async {
    final route =
        AppRouter.onGenerateRoute(
              const RouteSettings(name: RouteNames.locationChat),
            )
            as PageRoute<dynamic>;

    expect(route.opaque, isFalse);
    expect(route, isA<CupertinoRouteTransitionMixin<dynamic>>());

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) {
            return route.buildTransitions(
              context,
              const AlwaysStoppedAnimation<double>(0.5),
              const AlwaysStoppedAnimation<double>(0),
              const SizedBox.shrink(),
            );
          },
        ),
      ),
    );

    final fade = tester.widget<FadeTransition>(find.byType(FadeTransition));
    expect(fade.opacity.value, greaterThan(0));
    expect(fade.opacity.value, lessThan(1));
  });
}
