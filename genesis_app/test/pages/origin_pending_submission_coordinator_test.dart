import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/genesis_navigator.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_pending_submission_coordinator.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_pending_submission_store.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OriginPendingSubmissionCoordinator.instance.resetForTesting();
  });

  tearDown(() {
    OriginPendingSubmissionCoordinator.instance.resetForTesting();
  });

  test(
    'expired create pending uses created exit and clears saved draft',
    () async {
      final outcomes = <OriginPendingSubmissionOutcome>[];
      final removeListener = OriginPendingSubmissionCoordinator.instance
          .addCreateOutcomeListener(outcomes.add);
      addTearDown(removeListener);
      final draft = CreateOriginDraft.empty().copyWith(
        basics: const BasicsDraft(
          originName: 'Draft Worldo',
          worldView: 'Still editable after timeout.',
          worldLogic: 'Creation did not finish.',
        ),
        basicsSaved: true,
      );
      await CreateOriginDraftStore.saveFinal(draft);
      await OriginPendingSubmissionStore.saveCreating('o_timeout_1');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'creating_origin_started_at',
        DateTime.now()
            .toUtc()
            .subtract(OriginPendingSubmissionStore.timeout)
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      );

      await OriginPendingSubmissionCoordinator.instance.ensureCreatingPolling(
        loadOriginInfo: (_) =>
            fail('Expired pending should not poll origin info'),
      );

      expect(await OriginPendingSubmissionStore.loadCreating(), isNull);
      final clearedDraft = await CreateOriginDraftStore.loadFinal();
      expect(clearedDraft.hasAllSectionsSaved, isFalse);
      expect(clearedDraft.basics.originName, isEmpty);
      expect(outcomes, hasLength(1));
      expect(outcomes.single.completed, isTrue);
      expect(outcomes.single.originId, 'o_timeout_1');
    },
  );

  testWidgets('expired create pending shows created exit and opens origin', (
    WidgetTester tester,
  ) async {
    await OriginPendingSubmissionStore.saveCreating('o_timeout_1');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'creating_origin_started_at',
      DateTime.now()
          .toUtc()
          .subtract(OriginPendingSubmissionStore.timeout)
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: genesisNavigatorKey,
        onGenerateRoute: (settings) {
          if (settings.name == RouteNames.home) {
            final args = settings.arguments as Map?;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  Scaffold(body: Text('home_tab=${args?['home_tab']}')),
            );
          }
          if (settings.name == RouteNames.originWorld) {
            final args = settings.arguments as Map?;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  Scaffold(body: Text('origin_oid=${args?['oid']}')),
            );
          }
          return null;
        },
        home: const Scaffold(body: Text('start')),
      ),
    );

    final polling = OriginPendingSubmissionCoordinator.instance
        .ensureCreatingPolling(
          loadOriginInfo: (_) =>
              fail('Expired pending should not poll origin info'),
        );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Worldo creation timed out'), findsNothing);
    expect(
      _richTextWithPlainText('Worldo #o_timeout_1 created!'),
      findsOneWidget,
    );

    await tester.tap(find.text('View'));
    await tester.pump();
    await tester.pump();
    await polling;
    await tester.pump();
    await tester.pump();
    expect(find.text('origin_oid=o_timeout_1'), findsOneWidget);
  });

  test('expired publish pending still times out', () async {
    final outcomes = <OriginPendingSubmissionOutcome>[];
    final removeListener = OriginPendingSubmissionCoordinator.instance
        .addPublishOutcomeListener(outcomes.add);
    addTearDown(removeListener);
    await OriginPendingSubmissionStore.savePublishing('o_publish_timeout_1');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'publishing_origin_started_at',
      DateTime.now()
          .toUtc()
          .subtract(OriginPendingSubmissionStore.timeout)
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    );

    await OriginPendingSubmissionCoordinator.instance.ensurePublishingPolling(
      loadOriginInfo: (_) =>
          fail('Expired pending should not poll origin info'),
    );

    expect(await OriginPendingSubmissionStore.loadPublishing(), isNull);
    expect(outcomes, hasLength(1));
    expect(outcomes.single.completed, isFalse);
    expect(outcomes.single.originId, 'o_publish_timeout_1');
  });

  for (final entry in const <(String, OriginPendingSubmissionKind)>[
    ('create', OriginPendingSubmissionKind.create),
    ('publish', OriginPendingSubmissionKind.publish),
  ]) {
    testWidgets('${entry.$1} success View keeps Home My Worlds under origin', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: genesisNavigatorKey,
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case RouteNames.home:
                final args = settings.arguments as Map?;
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) =>
                      Scaffold(body: Text('home_tab=${args?['home_tab']}')),
                );
              case RouteNames.originWorld:
                final args = settings.arguments as Map?;
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (_) =>
                      Scaffold(body: Text('origin_oid=${args?['oid']}')),
                );
            }
            return null;
          },
          home: const Scaffold(body: Text('start')),
        ),
      );

      final coordinator = OriginPendingSubmissionCoordinator.instance;
      Future<Map<String, dynamic>> loadOriginInfo(String _) async {
        return const <String, dynamic>{
          'info': {
            'origin_id': 'o_done_1',
            'origin_name': 'Done Worldo',
            'status': 10,
          },
        };
      }

      switch (entry.$2) {
        case OriginPendingSubmissionKind.create:
          unawaited(
            coordinator.startCreating(
              originId: 'o_done_1',
              loadOriginInfo: loadOriginInfo,
            ),
          );
        case OriginPendingSubmissionKind.publish:
          unawaited(
            coordinator.startPublishing(
              originId: 'o_done_1',
              loadOriginInfo: loadOriginInfo,
            ),
          );
      }

      await tester.pumpAndSettle();
      final successVerb = entry.$2 == OriginPendingSubmissionKind.create
          ? 'created'
          : 'published';
      expect(
        _richTextWithPlainText('Worldo #Done Worldo $successVerb!'),
        findsOneWidget,
      );

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text('origin_oid=o_done_1'), findsOneWidget);

      await genesisNavigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('home_tab=my_world'), findsOneWidget);
    });
  }
}

Finder _richTextWithPlainText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );
}
