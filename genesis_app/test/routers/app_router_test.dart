import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
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
