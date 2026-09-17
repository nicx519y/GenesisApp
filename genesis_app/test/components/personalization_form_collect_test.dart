import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/config/app_global_config.dart';
import 'package:genesis_flutter_android/app/onboarding/personalization_store.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_gate.dart';
import 'package:genesis_flutter_android/components/onboarding/personalization_sheet.dart';
import 'package:genesis_flutter_android/pages/me/developer_personalization_preview.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

import '../support/personalization_fixtures.dart';

void main() {
  late MemoryCollectEventStore store;
  setUp(() {
    GenesisTelemetry.resetForTesting();
    SharedPreferences.setMockInitialValues({});
    store = MemoryCollectEventStore();
    GenesisTelemetry.setCollectUploaderForTesting(
      CollectTelemetryUploader(store: store)..configure(enabled: true),
    );
  });
  tearDown(GenesisTelemetry.resetForTesting);

  List<CollectEvent> events([String action = 'personalization_form_show']) =>
      store.eventsForTesting.where((event) => event.action == action).toList();

  Widget sheet({
    Key? key,
    PersonalizationStep step = PersonalizationStep.form,
    bool requiresSignIn = false,
    bool trackFormEvents = true,
  }) => PersonalizationSheet(
    key: key,
    form: personalizationData(genders: 2, ages: 2).form,
    initialStep: step,
    requiresSignIn: requiresSignIn,
    trackFormEvents: trackFormEvents,
    onSubmit: (_) async => PersonalizationNextStep.subscription,
    onSignIn: (_) async => const PersonalizationProfile(),
    subscriptionBuilder: (_) => const Text('Subscription'),
  );

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    GlobalKey<NavigatorState>? navigatorKey,
    TransitionBuilder? builder,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: builder,
        theme: GenesisTheme.dark(),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
  }

  Future<void> mountGate(
    WidgetTester tester,
    Future<PersonalizationProfile> Function(PersonalizationProfile) save,
  ) async {
    final personalization = PersonalizationStore(
      readLoginUid: () async => null,
      load: () async => personalizationData(genders: 2, ages: 2),
      save: save,
    );
    final config = ValueNotifier(
      const AppGlobalConfig(showPersonalizationForm: true),
    );
    final navigator = GlobalKey<NavigatorState>();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      personalization.dispose();
      config.dispose();
    });
    await mount(
      tester,
      const Text('Home'),
      navigatorKey: navigator,
      builder: (_, child) => PersonalizationGate(
        store: personalization,
        appConfig: config,
        navigatorKey: navigator,
        subscriptionBuilder: (_) => const Text('Subscription'),
        child: child!,
      ),
    );
  }

  Future<void> selectBoth(WidgetTester tester) async {
    for (final field in ['g0', 'a0']) {
      await tester.tap(find.byKey(ValueKey('personalization-$field')));
      await tester.pumpAndSettle();
    }
  }

  for (final succeeds in [true, false]) {
    testWidgets('Continue reports save result once: success=$succeeds', (
      tester,
    ) async {
      final saved = Completer<PersonalizationProfile>();
      var saves = 0;
      await mountGate(tester, (_) {
        saves++;
        return saved.future;
      });
      await selectBoth(tester);
      final button = find.byKey(const ValueKey('personalization-continue'));
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(saves, 1);
      expect(events('personalization_continue_click'), isEmpty);
      expect(events('personalization_sign_in_click'), isEmpty);
      if (succeeds) {
        saved.complete(
          const PersonalizationProfile(
            gender: 'g0',
            age: 'a0',
            completed: true,
          ),
        );
      } else {
        saved.completeError(StateError('save rejected'));
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await GenesisTelemetry.waitForCollectWritesForTesting();
      final result = events('personalization_continue_click').single;
      expect(result.actionType, 'event');
      expect(result.object1, succeeds ? 'success' : 'failed');
      expect([
        result.object2,
        result.object3,
        result.object4,
        result.extData,
      ], everyElement(''));
    });
  }

  testWidgets('incomplete form does not report an unattempted save', (
    tester,
  ) async {
    var saves = 0;
    await mountGate(tester, (profile) async {
      saves++;
      return profile;
    });
    await tester.tap(find.byKey(const ValueKey('personalization-continue')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(saves, 0);
    expect(events('personalization_continue_click'), isEmpty);
  });

  testWidgets('visible form queues exact empty-object event only once', (
    tester,
  ) async {
    await mount(tester, sheet());
    final event = events().single;
    expect(event.actionType, 'pageview');
    expect(event.object1, '');
    expect(event.object2, '');
    expect(event.object3, '');
    expect(event.object4, '');
    expect(event.extData, '');

    await tester.tap(find.byKey(const ValueKey('personalization-g0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('personalization-sign-in')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('personalization-continue')),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(events(), hasLength(1));
  });

  testWidgets('offstage form waits for its first painted frame', (
    tester,
  ) async {
    final hidden = ValueNotifier(true);
    addTearDown(hidden.dispose);
    await mount(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: hidden,
        child: sheet(),
        builder: (_, value, child) => Offstage(offstage: value, child: child),
      ),
    );
    expect(events(), isEmpty);
    hidden.value = false;
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(events(), hasLength(1));
  });

  testWidgets('required login does not count until form appears', (
    tester,
  ) async {
    await mount(tester, sheet(requiresSignIn: true));
    expect(events(), isEmpty);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(events(), hasLength(1));
    expect(events('personalization_sign_in_click'), isEmpty);
  });

  testWidgets('form Sign in still works without recording a click event', (
    tester,
  ) async {
    await mount(tester, sheet());
    for (var count = 1; count <= 2; count++) {
      await tester.tap(find.byKey(const ValueKey('personalization-sign-in')));
      await tester.pumpAndSettle();
      await GenesisTelemetry.waitForCollectWritesForTesting();
      expect(events('personalization_sign_in_click'), isEmpty);
      if (count == 1) {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text('Continue with Google'));
      }
      await tester.pumpAndSettle();
    }
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(events('personalization_sign_in_click'), isEmpty);
    expect(events(), hasLength(1));
  });

  testWidgets('inactive form waits until the app resumes', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await mount(tester, sheet());
    expect(events(), isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(events(), hasLength(1));
  });

  testWidgets('subscription step does not count as a form exposure', (
    tester,
  ) async {
    await mount(tester, sheet(step: PersonalizationStep.subscription));
    expect(events(), isEmpty);
    expect(events('personalization_skip_click'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(events('personalization_skip_click'), isEmpty);
  });

  for (final track in [true, false]) {
    testWidgets('subscription Skip closes and records once: track=$track', (
      tester,
    ) async {
      await mount(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => sheet(
                step: PersonalizationStep.subscription,
                trackFormEvents: track,
              ),
            ),
            child: const Text('Open subscription'),
          ),
        ),
      );
      await tester.tap(find.text('Open subscription'));
      await tester.pumpAndSettle();
      expect(events('personalization_skip_click'), isEmpty);
      final skip = find.byKey(const ValueKey('personalization-skip'));
      await tester.tap(skip);
      await tester.tap(skip);
      await tester.pumpAndSettle();
      await GenesisTelemetry.waitForCollectWritesForTesting();
      expect(find.byType(PersonalizationSheet), findsNothing);
      final skipped = events('personalization_skip_click');
      expect(skipped, hasLength(track ? 1 : 0));
      if (track) {
        final event = skipped.single;
        expect(event.actionType, 'event');
        expect([
          event.object1,
          event.object2,
          event.object3,
          event.object4,
          event.extData,
        ], everyElement(''));
      }
    });
  }

  testWidgets('a new sheet instance counts a new exposure', (tester) async {
    final revision = ValueNotifier(0);
    addTearDown(revision.dispose);
    await mount(
      tester,
      ValueListenableBuilder<int>(
        valueListenable: revision,
        builder: (_, value, _) => sheet(key: ValueKey(value)),
      ),
    );
    revision.value++;
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(events(), hasLength(2));
    expect(events().map((event) => event.eventId).toSet(), hasLength(2));
  });

  testWidgets('developer preview does not queue production form events', (
    tester,
  ) async {
    await mount(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showDeveloperPersonalizationPreview(
            context,
            PersonalizationPreviewScenario.newUser,
          ),
          child: const Text('Preview'),
        ),
      ),
    );
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(find.byType(PersonalizationSheet), findsOneWidget);
    expect(events(), isEmpty);
    await tester.tap(find.byKey(const ValueKey('personalization-continue')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('personalization-sign-in')));
    await tester.pumpAndSettle();
    await GenesisTelemetry.waitForCollectWritesForTesting();
    expect(events('personalization_continue_click'), isEmpty);
    expect(events('personalization_sign_in_click'), isEmpty);
  });
}
