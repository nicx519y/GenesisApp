import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_deletion_events.dart';
import 'package:genesis_flutter_android/pages/world/world_navigation.dart';
import 'package:genesis_flutter_android/pages/world/world_page_result.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
  testWidgets('deleted world notifies the existing My Worlds root route', (
    WidgetTester tester,
  ) async {
    worldDeletionEvents.value = null;
    final navigatorKey = GlobalKey<NavigatorState>();
    var homeBuildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        onGenerateRoute: (settings) {
          if (settings.name == RouteNames.home) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) {
                homeBuildCount += 1;
                return Scaffold(
                  body: ValueListenableBuilder<WorldDeletionEvent?>(
                    valueListenable: worldDeletionEvents,
                    builder: (_, event, _) => Text(
                      'My Worlds $homeBuildCount deleted=${event?.worldId ?? ''}',
                    ),
                  ),
                );
              },
            );
          }
          if (settings.name == RouteNames.world) {
            return MaterialPageRoute<WorldPageResult>(
              settings: settings,
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    const WorldPageResult.deleted(
                      deletedWorldId: 'world_deleted',
                    ),
                  ),
                  child: const Text('Delete world'),
                ),
              ),
            );
          }
          return null;
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openWorldFromMyWorldsRoot(
                navigatorKey.currentState!,
                arguments: const {'wid': 'world_deleted'},
              ),
              child: const Text('Open world'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open world'));
    await tester.pumpAndSettle();
    expect(find.text('Delete world'), findsOneWidget);
    expect(homeBuildCount, 1);

    await tester.tap(find.text('Delete world'));
    await tester.pumpAndSettle();

    expect(find.text('My Worlds 1 deleted=world_deleted'), findsOneWidget);
    expect(homeBuildCount, 1);
    worldDeletionEvents.value = null;
  });
}
