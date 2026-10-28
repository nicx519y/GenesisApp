import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_balance_prompt_controller.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/components/gems/gem_balance_prompt_host.dart';
import 'package:genesis_flutter_android/network/gem_balance_alert.dart';
import 'package:genesis_flutter_android/platform/session/memory_user_session_store.dart';

const insufficient = GemBalanceAlert(
  kind: GemBalanceAlertKind.insufficient,
  message: 'Server balance error',
);
const low = GemBalanceAlert(kind: GemBalanceAlertKind.low);

void main() {
  testWidgets(
    'root prompt follows services replaced after environment switch',
    (tester) async {
      final session = MemoryUserSessionStore();
      await session.saveUid('u');
      await session.saveAuthToken('token');
      final services = ServiceRegistry.build(
        config: const AppConfig(useMock: true),
        sessionStoreOverride: session,
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      late BuildContext builderContext;
      var presentations = 0;
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) {
              builderContext = context;
              return GemBalancePromptHost(
                controller: AppServicesScope.of(context).balancePrompts,
                navigatorKey: navigatorKey,
                present: (_, _) async {
                  presentations++;
                },
                child: child!,
              );
            },
            home: const Scaffold(),
          ),
        ),
      );
      final updated = (await tester.runAsync(
        () async => AppServicesScope.replaceWithConfig(
          builderContext,
          const AppConfig(
            useMock: true,
            apiBaseUrl: 'https://changed.test/api/',
          ),
        ),
      ))!;
      await tester.pumpAndSettle();
      updated.balancePrompts.report(insufficient, 'token');
      await tester.pumpAndSettle();
      expect(presentations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'same asynchronous failure is consumed across socket and recovery reports',
    () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('u');
      await store.saveAuthToken('token');
      final controller = GemBalancePromptController(sessionStore: store);
      addTearDown(controller.dispose);
      const alert = GemBalanceAlert(
        kind: GemBalanceAlertKind.insufficient,
        occurrenceKey: 'phone:w:r',
      );
      controller.report(alert, 'token');
      await Future<void>.delayed(Duration.zero);
      expect(controller.beginPresentation(), alert);
      controller.endPresentation();
      controller.report(alert, 'token');
      await Future<void>.delayed(Duration.zero);
      expect(controller.pending, isNull);
      controller.reset();
      controller.report(alert, 'token');
      await Future<void>.delayed(Duration.zero);
      expect(controller.pending, alert);
    },
  );

  test(
    'controller rejects anonymous, stale-account and reset in-flight events',
    () async {
      final store = MemoryUserSessionStore();
      await store.saveUid('u');
      await store.saveAuthToken('new');
      final controller = GemBalancePromptController(sessionStore: store);
      addTearDown(controller.dispose);
      controller.report(insufficient, 'old');
      controller.report(insufficient, null);
      await Future<void>.delayed(Duration.zero);
      expect(controller.pending, isNull);
      controller.report(insufficient, 'new');
      controller.reset();
      await Future<void>.delayed(Duration.zero);
      expect(controller.pending, isNull);
      controller.report(low, 'Bearer new');
      controller.report(insufficient, 'new');
      await Future<void>.delayed(Duration.zero);
      expect(controller.pending, insufficient);
      controller.reset();
      expect(controller.pending, isNull);
    },
  );

  testWidgets(
    'root host presents over unrelated routes, coalesces and reopens',
    (tester) async {
      final store = MemoryUserSessionStore();
      await store.saveUid('u');
      await store.saveAuthToken('token');
      final controller = GemBalancePromptController(sessionStore: store);
      addTearDown(controller.dispose);
      final key = GlobalKey<NavigatorState>();
      var presentations = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          builder: (_, child) => GemBalancePromptHost(
            controller: controller,
            navigatorKey: key,
            child: child!,
            present: (context, alert) {
              presentations++;
              return showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('Recharge')),
              );
            },
          ),
          home: const Scaffold(body: Text('Home')),
        ),
      );
      unawaited(
        key.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Future chat')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.report(insufficient, 'token');
      controller.report(low, 'token');
      await tester.pumpAndSettle();
      expect(find.text('Recharge'), findsOneWidget);
      expect(find.text('Server balance error'), findsOneWidget);
      expect(presentations, 1);
      controller.report(insufficient, 'token');
      await tester.pumpAndSettle();
      expect(presentations, 1);
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Future chat'), findsOneWidget);
      controller.report(insufficient, 'token');
      await tester.pumpAndSettle();
      expect(presentations, 2);
      key.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'background events wait for foreground and account reset clears pending',
    (tester) async {
      final store = MemoryUserSessionStore();
      await store.saveUid('u');
      await store.saveAuthToken('token');
      final controller = GemBalancePromptController(sessionStore: store);
      addTearDown(controller.dispose);
      final key = GlobalKey<NavigatorState>();
      var presentations = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          builder: (_, child) => GemBalancePromptHost(
            controller: controller,
            navigatorKey: key,
            child: child!,
            present: (_, _) async {
              presentations++;
            },
          ),
          home: const Scaffold(),
        ),
      );
      void background() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      }

      void foreground() {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }

      background();
      controller.report(insufficient, 'token');
      await tester.pump();
      expect(presentations, 0);
      foreground();
      await tester.pumpAndSettle();
      expect(presentations, 1);
      background();
      controller.report(insufficient, 'token');
      await tester.pump();
      controller.reset();
      foreground();
      await tester.pumpAndSettle();
      expect(presentations, 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
