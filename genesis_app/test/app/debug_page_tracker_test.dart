import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug_page_tracker.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

class _RecordingTelemetrySink implements GenesisTelemetrySink {
  final events = <GenesisTelemetryEvent>[];

  @override
  Future<void> captureException(Object error, StackTrace stackTrace) async {}

  @override
  Future<void> record(GenesisTelemetryEvent event) async {
    events.add(event);
  }

  @override
  Future<void> setContext(GenesisTelemetryContext context) async {}

  @override
  Future<void> setUserId(String? uid) async {}
}

void main() {
  late _RecordingTelemetrySink sink;

  setUp(() {
    sink = _RecordingTelemetrySink();
    GenesisTelemetry.setSinkForTesting(sink);
  });

  tearDown(GenesisTelemetry.resetForTesting);

  testWidgets('closing a popup over world does not repeat world_detail', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [genesisRouteObserver],
        initialRoute: RouteNames.home,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => Scaffold(body: Text(settings.name ?? '')),
          );
        },
      ),
    );

    navigatorKey.currentState!.pushNamed(
      RouteNames.world,
      arguments: const {'wid': 'world_1'},
    );
    await tester.pumpAndSettle();

    expect(_worldDetailEvents(sink), hasLength(1));
    expect(_worldDetailEvents(sink).single.data, {
      'action_type': 'pageview',
      'action': 'world_detail',
      'object1': 'world_1',
    });

    final worldContext = navigatorKey.currentState!.overlay!.context;
    showModalBottomSheet<void>(
      context: worldContext,
      builder: (_) => const SizedBox(height: 100),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(_worldDetailEvents(sink), hasLength(1));
  });
}

List<GenesisTelemetryEvent> _worldDetailEvents(_RecordingTelemetrySink sink) {
  return sink.events
      .where(
        (event) =>
            event.category == 'collect.log' &&
            event.data['action'] == 'world_detail',
      )
      .toList(growable: false);
}
