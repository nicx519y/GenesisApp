import 'package:genesis_flutter_android/app/debug/rating_prompt_debug_settings.dart';
import 'package:genesis_flutter_android/components/common/rating_prompt_debug_control.dart';
import 'package:genesis_flutter_android/components/common/rating_prompt_host.dart';
import 'package:genesis_flutter_android/app/review/rating_prompt_store.dart';
import 'package:genesis_flutter_android/app/config/app_global_config.dart';
import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';
import 'package:genesis_flutter_android/components/common/pending_rating_reward_host.dart';
import 'package:genesis_flutter_android/app/genesis_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/review/app_review_service.dart';
import 'package:genesis_flutter_android/components/common/rating_reward_dialog.dart';
import 'package:genesis_flutter_android/components/common/worldo_rating_dialog.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/config/app_config.dart';
import 'package:genesis_flutter_android/app/config/platform_config.dart';
import 'package:genesis_flutter_android/app/version/app_version_check_service.dart';
import 'package:genesis_flutter_android/components/common/genesis_action_box.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_client.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/direct_message_conversation_store.dart';
import 'package:genesis_flutter_android/network/direct_message_message_store.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/models/user.dart';
import 'package:genesis_flutter_android/pages/me/settings_page.dart';
import 'package:genesis_flutter_android/platform/platform_services.dart';
import 'package:genesis_flutter_android/ui/genesis_ui.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final sheet in [true, false]) {
    testWidgets(
      'Rate Dialog dismisses developer ${sheet ? 'sheet' : 'page'} before preview',
      (tester) async {
        final services = _feedbackTestServices(_RecordingFeedbackTransport());
        await services.sessionStore.saveUid('u_debug_preview');
        final navigatorKey = GlobalKey<NavigatorState>();
        var developerTransitionCompleted = false;
        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                key: const ValueKey('actual-page-behind-developer'),
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () {
                      Widget developer(BuildContext context) {
                        ModalRoute.of(context)!.completed.then((_) {
                          developerTransitionCompleted = true;
                        });
                        return const Scaffold(
                          key: ValueKey('developer-preview-surface'),
                          body: SingleChildScrollView(
                            child: RatingPromptDebugSection(),
                          ),
                        );
                      }

                      if (sheet) {
                        showGenesisModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: developer,
                        );
                      } else {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute<void>(builder: developer));
                      }
                    },
                    child: const Text('Open developer'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open developer'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('developer-preview-surface')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('developer-rate-button')));
        await tester.pump();
        expect(find.byType(WorldoRatingContent), findsNothing);
        await tester.pumpAndSettle();

        expect(developerTransitionCompleted, isTrue);
        expect(
          find.byKey(const ValueKey('developer-preview-surface')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('actual-page-behind-developer')),
          findsOneWidget,
        );
        expect(find.byType(WorldoRatingContent), findsOneWidget);
        expect(tester.takeException(), isNull);

        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();
        expect(navigatorKey.currentState!.canPop(), isFalse);
        expect(find.byType(WorldoRatingContent), findsNothing);
      },
    );
  }

  testWidgets(
    'developer Rate Dialog button is always visible without a display request',
    (tester) async {
      final transport = _RecordingFeedbackTransport();
      final services = _feedbackTestServices(transport);
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: const MaterialApp(
            home: Scaffold(body: RatingPromptDebugSection()),
          ),
        ),
      );
      final rateButton = find.byKey(const ValueKey('developer-rate-button'));
      expect(rateButton, findsOneWidget);
      expect(transport.requests, isEmpty);
      await tester.tap(rateButton);
      await tester.pumpAndSettle();
      expect(rateButton, findsOneWidget);
      expect(find.byType(WorldoRatingContent), findsNothing);
      expect(find.text('Available after signing in'), findsOneWidget);
      expect(transport.requests, isEmpty);

      await services.sessionStore.saveUid('guest_debug');
      services.sessionRevision.value++;
      await tester.pumpAndSettle();
      expect(rateButton, findsOneWidget);
      await tester.tap(rateButton);
      await tester.pumpAndSettle();
      expect(find.text('Available after signing in'), findsOneWidget);
      expect(transport.requests, isEmpty);
      await services.sessionStore.saveUid('u_debug');
      services.sessionRevision.value++;
      await tester.pumpAndSettle();
      expect(rateButton, findsOneWidget);
      expect(transport.requests, isEmpty);
      expect(find.text('Rating message threshold'), findsNothing);
      expect(
        find.byKey(const ValueKey('developer-rating-threshold-input')),
        findsNothing,
      );
      expect(find.text('Apply'), findsNothing);
      expect(find.text('Use server'), findsNothing);
      expect(find.text('Reset rating prompt'), findsNothing);
      await services.sessionStore.clearUid();
      await tester.pumpAndSettle();
      expect(rateButton, findsOneWidget);
      expect(find.text('Reset rating prompt'), findsNothing);
      expect(transport.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('guest Rate Dialog tap keeps the developer sheet open', (
    tester,
  ) async {
    final transport = _RecordingFeedbackTransport();
    final services = _feedbackTestServices(transport);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showGenesisModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const RatingPromptDebugSection(),
                ),
                child: const Text('Open developer'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open developer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('developer-rate-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('developer-rate-button')), findsOneWidget);
    expect(find.byType(WorldoRatingContent), findsNothing);
    expect(find.text('Available after signing in'), findsOneWidget);
    expect(transport.requests, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets(
    'automatic rating waits until chat and world routes have exited',
    (tester) async {
      final services = _feedbackTestServices(_RecordingFeedbackTransport());
      await services.sessionStore.saveUid('guest_auto');
      services.personalization.blocksOtherPrompts.value = false;
      services.appGlobalConfig.value = const AppGlobalConfig(
        ratingPromptMessageCount: 0,
      );
      await RatingPromptDebugSettings.save(1);
      await RatingPromptStore.instance.recordMessage(
        owner: Future.value('u_auto'),
        threshold: 1,
        messageId: 'one',
      );
      await RatingPromptStore.instance.recordMessage(
        owner: Future.value('u_auto'),
        threshold: 1,
        messageId: 'two',
      );
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            navigatorKey: genesisNavigatorKey,
            navigatorObservers: [ratingPromptRouteObserver],
            builder: (_, child) => RatingPromptHost(child: child!),
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WorldoRatingContent), findsNothing);
      final nav = genesisNavigatorKey.currentState!;
      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/world'),
          builder: (_) => const Scaffold(body: Text('World')),
        ),
      );
      await tester.pumpAndSettle();
      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/location_chat'),
          builder: (_) => const Scaffold(body: Text('Chat')),
        ),
      );
      await tester.pumpAndSettle();
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.byType(WorldoRatingContent), findsNothing);
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.byType(WorldoRatingContent), findsNothing);
      await services.sessionStore.saveUid('u_auto');
      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/world'),
          builder: (_) => const Scaffold(body: Text('World')),
        ),
      );
      await tester.pumpAndSettle();
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.byType(WorldoRatingContent), findsOneWidget);
      nav.pop();
      await tester.pumpAndSettle();
      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/origin_world'),
          builder: (_) => const Scaffold(body: Text('Worldo')),
        ),
      );
      await tester.pumpAndSettle();
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.byType(WorldoRatingContent), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final uid in ['', 'guest_test']) {
    testWidgets('guest $uid cannot open rating dialog even from manual entry', (
      tester,
    ) async {
      final transport = _RecordingFeedbackTransport();
      final services = _feedbackTestServices(transport);
      if (uid.isNotEmpty) await services.sessionStore.saveUid(uid);
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showWorldoRatingDialog(context),
                  child: const Text('Rate'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Rate'));
      await tester.pumpAndSettle();
      expect(find.byType(WorldoRatingContent), findsNothing);
      expect(transport.requestsFor('/api/v1/feedback/create'), isEmpty);
      expect(PendingRatingReward.flowActive, false);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rating dialog shows close button or cancel, never both', (
    tester,
  ) async {
    final transport = _RecordingFeedbackTransport();
    final services = _feedbackTestServices(transport);
    await services.sessionStore.saveUid('u_rating_close');
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showWorldoRatingDialog(context),
                child: const Text('Rate'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('worldo-rating-close')), findsOneWidget);
    final dialog = tester.getRect(find.byType(GenesisActionBoxSurface));
    final close = tester.getRect(
      find.byKey(const ValueKey('worldo-rating-close')),
    );
    expect(close.top - dialog.top, closeTo(12, 0.1));
    expect(dialog.right - close.right, closeTo(12, 0.1));
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.byType(WorldoRatingContent), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WorldoRatingContent), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('worldo-rating-star-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('worldo-rating-close')), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WorldoRatingContent), findsOneWidget);
    expect(transport.requestsFor('/api/v1/feedback/create'), isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(WorldoRatingContent), findsNothing);
    expect(find.byType(RatingRewardDialog), findsNothing);
    await tester.tap(find.text('Rate'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('worldo-rating-close')), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('worldo-rating-close')));
    await tester.pumpAndSettle();
    expect(find.byType(WorldoRatingContent), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (stars, withContent) in [
    (1, false),
    (2, false),
    (3, false),
    (3, true),
    (4, false),
    (5, false),
  ]) {
    testWidgets(
      'rating $stars content=$withContent enforces feedback requirement',
      (tester) async {
        GenesisTelemetry.resetForTesting();
        addTearDown(GenesisTelemetry.resetForTesting);
        final collectStore = MemoryCollectEventStore();
        GenesisTelemetry.setCollectUploaderForTesting(
          CollectTelemetryUploader(store: collectStore)
            ..configure(enabled: true),
        );
        List<CollectEvent> ratingEvents(String action) => collectStore
            .eventsForTesting
            .where((event) => event.action == action)
            .toList(growable: false);
        final transport = _RecordingFeedbackTransport();
        final services = _feedbackTestServices(transport);
        await services.sessionStore.saveUid('u_rating');
        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showWorldoRatingDialog(
                      context,
                      reviewService: AppReviewService(
                        request: () async {
                          expect(find.byType(RatingRewardDialog), findsNothing);
                          if (stars == 5) {
                            throw StateError('native review failed');
                          }
                        },
                      ),
                    ),
                    child: const Text('Rate'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Rate'));
        await tester.pumpAndSettle();
        expect(ratingEvents('rate_star_show'), hasLength(1));
        expect(ratingEvents('rate_star_show').single.actionType, 'pageview');
        expect(ratingEvents('rate_star_show').single.object1, isEmpty);
        final initialWidth = tester
            .getSize(find.byType(GenesisActionBoxSurface))
            .width;
        expect(
          initialWidth,
          closeTo(
            (tester.view.physicalSize.width /
                    tester.view.devicePixelRatio *
                    0.7)
                .clamp(0.0, 800.0),
            0.1,
          ),
        );
        await tester.tap(find.byKey(ValueKey('worldo-rating-star-$stars')));
        if (stars < 4) {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 180));
          final midwayWidth = tester
              .getSize(find.byType(GenesisActionBoxSurface))
              .width;
          expect(midwayWidth, closeTo(initialWidth, 0.1));
        }
        await tester.pumpAndSettle();
        expect(ratingEvents('rate_star_show'), hasLength(1));
        expect(
          ratingEvents('rate_star_submit'),
          stars < 4 ? isEmpty : hasLength(1),
        );
        if (stars >= 4) {
          expect(ratingEvents('rate_star_submit').single.actionType, 'event');
          expect(ratingEvents('rate_star_submit').single.object1, '$stars');
        }
        if (stars < 4) {
          expect(
            tester.getSize(find.byType(GenesisActionBoxSurface)).width,
            closeTo(initialWidth, 0.1),
          );
        }
        expect(
          find.byKey(const ValueKey('genesis-feedback-content-input')),
          stars < 4 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(WorldoRatingContent),
          stars < 4 ? findsOneWidget : findsNothing,
        );
        expect(
          transport.requestsFor('/api/v1/feedback/create'),
          stars < 4 ? isEmpty : hasLength(1),
        );
        if (stars == 3 && withContent) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('genesis-feedback-content-input')),
            'Rating feedback',
          );
          await tester.pumpAndSettle();
          final send = find.text('Submit');
          await tester.ensureVisible(send);
          await tester.tap(send);
          await tester.pumpAndSettle();
          expect(
            transport.requestsFor('/api/v1/feedback/create'),
            hasLength(1),
          );
          expect(
            transport.decodedBody(
              transport.requestsFor('/api/v1/feedback/create').single,
            ),
            {'content': '3 Star Rating feedback', 'rating': 3},
          );
          expect(ratingEvents('rate_star_submit').single.object1, '3');
          expect(find.byType(WorldoRatingContent), findsNothing);
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
        }
        if (stars <= 3 && !withContent) {
          if (stars == 2) {
            await tester.enterText(
              find.byKey(const ValueKey('genesis-feedback-content-input')),
              '   ',
            );
            await tester.pumpAndSettle();
          }
          var actionBox = tester.widget<GenesisActionBox<int>>(
            find.byType(GenesisActionBox<int>),
          );
          expect(actionBox.actions.single.enabled, isFalse);
          expect(
            tester.widget<Text>(find.text('Submit')).style?.color,
            GenesisColors.darkTextTertiary,
          );
          await tester.ensureVisible(find.text('Submit'));
          await tester.tap(find.text('Submit'));
          await tester.pumpAndSettle();
          expect(find.byType(WorldoRatingContent), findsOneWidget);
          expect(transport.requestsFor('/api/v1/feedback/create'), isEmpty);
          expect(ratingEvents('rate_star_submit'), isEmpty);

          final input = find.byKey(
            const ValueKey('genesis-feedback-content-input'),
          );
          await tester.enterText(input, 'Rating feedback');
          await tester.pumpAndSettle();
          actionBox = tester.widget<GenesisActionBox<int>>(
            find.byType(GenesisActionBox<int>),
          );
          expect(actionBox.actions.single.enabled, isTrue);
          expect(
            tester.widget<Text>(find.text('Submit')).style?.color,
            GenesisColors.redSecondary,
          );
          await tester.enterText(input, '');
          await tester.pumpAndSettle();
          actionBox = tester.widget<GenesisActionBox<int>>(
            find.byType(GenesisActionBox<int>),
          );
          expect(actionBox.actions.single.enabled, isFalse);
          await tester.enterText(input, 'Rating feedback');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Submit'));
          await tester.tap(find.text('Submit'));
          await tester.pumpAndSettle();
          expect(
            transport.decodedBody(
              transport.requestsFor('/api/v1/feedback/create').single,
            ),
            {'content': '$stars Star Rating feedback', 'rating': stars},
          );
          expect(ratingEvents('rate_star_submit'), hasLength(1));
          expect(ratingEvents('rate_star_submit').single.actionType, 'event');
          expect(ratingEvents('rate_star_submit').single.object1, '$stars');
        }
        if (stars >= 1) {
          expect(find.byType(RatingRewardDialog), findsOneWidget);
        }
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  for (final highRating in [4, 5]) {
    testWidgets(
      'low rating can change to $highRating without sending feedback text',
      (tester) async {
        final transport = _RecordingFeedbackTransport();
        final services = _feedbackTestServices(transport);
        await services.sessionStore.saveUid('u_rating_change_$highRating');
        var reviewRequests = 0;
        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showWorldoRatingDialog(
                      context,
                      reviewService: AppReviewService(
                        request: () async => reviewRequests++,
                      ),
                    ),
                    child: const Text('Rate'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Rate'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('worldo-rating-star-1')));
        await tester.pumpAndSettle();
        final input = find.byKey(
          const ValueKey('genesis-feedback-content-input'),
        );
        await tester.enterText(input, 'Feedback for low rating');
        await tester.tap(find.byKey(const ValueKey('worldo-rating-star-2')));
        await tester.pumpAndSettle();
        expect(find.byType(WorldoRatingContent), findsOneWidget);
        expect(
          tester.widget<TextField>(input).controller?.text,
          'Feedback for low rating',
        );
        expect(transport.requestsFor('/api/v1/feedback/create'), isEmpty);

        await tester.tap(
          find.byKey(ValueKey('worldo-rating-star-$highRating')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(WorldoRatingContent), findsNothing);
        expect(reviewRequests, 1);
        expect(
          transport.decodedBody(
            transport.requestsFor('/api/v1/feedback/create').single,
          ),
          {'rating': highRating},
        );
        expect(find.byType(RatingRewardDialog), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('pending reward waits for next app interaction', (tester) async {
    final services = _feedbackTestServices(_RecordingFeedbackTransport());
    await services.sessionStore.saveUid('u_pending');
    await PendingRatingReward.save('u_pending', 5);
    PendingRatingReward.flowActive = false;
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          navigatorKey: genesisNavigatorKey,
          builder: (_, child) => PendingRatingRewardHost(child: child!),
          home: const Scaffold(body: Text('Continue')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RatingRewardDialog), findsNothing);

    await services.sessionStore.saveUid('other_owner');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingRewardDialog), findsNothing);
    await services.sessionStore.saveUid('u_pending');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(RatingRewardDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getInt(
        PendingRatingReward.key('u_pending'),
      ),
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final claimed in [false, true]) {
    testWidgets('reward entry claimed=$claimed skips thank-you-only dialog', (
      tester,
    ) async {
      final services = _feedbackTestServices(_RecordingFeedbackTransport());
      await services.sessionStore.saveUid('u_reward_entry');
      await (await SharedPreferences.getInstance()).setBool(
        RatingPromptStore.rewardClaimedKey('u_reward_entry'),
        claimed,
      );
      await PendingRatingReward.save('u_reward_entry', 3);
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      PendingRatingReward.show(context, 'u_reward_entry', 3),
                  child: const Text('Reward'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Reward'));
      await tester.pumpAndSettle();
      expect(find.text('Your feedback has been saved.'), findsNothing);
      expect(
        find.byType(RatingRewardDialog),
        claimed ? findsNothing : findsOneWidget,
      );
      if (!claimed) {
        expect(find.text('Claim'), findsOneWidget);
        await tester.tapAt(const Offset(1, 1));
        await tester.pumpAndSettle();
        expect(find.byType(RatingRewardDialog), findsOneWidget);
        await tester.dragFrom(const Offset(1, 400), const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(find.byType(RatingRewardDialog), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(RatingRewardDialog), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          PendingRatingReward.key('u_reward_entry'),
        ),
        false,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'rating reward retries an explicit claim error and refreshes wallet',
    (tester) async {
      final transport = _RecordingFeedbackTransport()..claimFailures = 1;
      final services = _feedbackTestServices(transport);
      await services.sessionStore.saveUid('u_reward');
      await services.sessionStore.saveAuthToken('token');
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const RatingRewardDialog(rating: 3),
                  ),
                  child: const Text('Reward'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Reward'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claim'));
      await tester.pumpAndSettle();
      expect(find.byType(RatingRewardDialog), findsOneWidget);
      expect(transport.requestsFor('/api/v1/gem/task/claim'), hasLength(1));
      await tester.tap(find.text('Claim'));
      await tester.pumpAndSettle();
      expect(transport.requestsFor('/api/v1/gem/task/claim'), hasLength(2));
      expect(
        transport.decodedBody(
          transport.requestsFor('/api/v1/gem/task/claim').last,
        ),
        {'task_code': 'rating'},
      );
      expect(find.byType(RatingRewardDialog), findsNothing);
      expect(services.gemWallet.state.value.balanceCent, 33000);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'rating_reward_claimed_v1:u_reward',
        ),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings language name follows the current locale', (
    tester,
  ) async {
    final services = _feedbackTestServices(_RecordingFeedbackTransport());
    for (final entry in const {
      'en': 'English',
      'zh': '繁體中文',
      'es': 'Español',
      'pt': 'Português',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
      'ja': '日本語',
      'ko': '한국어',
    }.entries) {
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            locale: entry.key == 'zh'
                ? const Locale('zh', 'TW')
                : Locale(entry.key),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('settings feedback opens shared dialog and submits', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.viewInsets = FakeViewPadding.zero;
    });

    final transport = _RecordingFeedbackTransport();
    final services = _feedbackTestServices(transport);

    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About us'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Language')).dy,
      lessThan(tester.getTopLeft(find.text('About us')).dy),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      GenesisColors.darkBackground,
    );
    final logout = tester.widget<GenesisPrimaryButton>(
      find.widgetWithText(GenesisPrimaryButton, 'Log out'),
    );
    expect(logout.backgroundColor, GenesisColors.darkFaintFill);
    expect(logout.foregroundColor, GenesisColors.darkTextTertiary);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Join Discord'), findsOneWidget);
    expect(find.text('Feedback'), findsOneWidget);
    expect(find.text('Delete account'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Account')).dy,
      greaterThan(tester.getTopLeft(find.text('About us')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Feedback')).dy,
      greaterThan(tester.getTopLeft(find.text('Account')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Join Discord')).dy,
      greaterThan(tester.getTopLeft(find.text('Feedback')).dy),
    );

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.text('Current login account:'), findsOneWidget);
    final currentLoginAccountText = tester.widget<Text>(
      find.text('Current login account:'),
    );
    expect(currentLoginAccountText.style?.fontSize, 16);
    final accountCard = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Current login account:'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (accountCard.decoration as BoxDecoration).color,
      GenesisColors.darkFaintFill,
    );
    expect(find.text('Account Deletion Agreement'), findsOneWidget);
    expect(
      find.text('I have read the Account Deletion Agreement'),
      findsOneWidget,
    );
    final agreementTextFinder = find.text(
      'I have read the Account Deletion Agreement',
    );
    final agreementText = tester.widget<Text>(agreementTextFinder);
    expect(agreementText.style?.fontSize, 14);
    expect(
      tester.getTopLeft(find.byType(Checkbox)).dx,
      closeTo(tester.getTopLeft(find.text('Account Deletion Agreement')).dx, 1),
    );
    expect(
      tester.getTopLeft(find.byType(Checkbox)).dx,
      lessThan(tester.getTopLeft(agreementTextFinder).dx),
    );
    final gemsWarningFinder = find.textContaining(
      'All unused Gems, including purchased and earned Gems',
    );
    await tester.scrollUntilVisible(
      gemsWarningFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(gemsWarningFinder, findsOneWidget);
    expect(find.textContaining('voluntarily waive them'), findsOneWidget);
    expect(
      find.textContaining('account deletion does not automatically entitle'),
      findsOneWidget,
    );
    final gemsWarning = tester.widget<Text>(gemsWarningFinder);
    expect(gemsWarning.style?.color, GenesisColors.redSecondary);
    await tester.tap(find.widgetWithText(GenesisPrimaryButton, 'Delete'));
    await tester.pump();
    expect(find.text('Agree to our terms to continue.'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    final selectedCheckbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(selectedCheckbox.value, isTrue);
    expect(selectedCheckbox.activeColor, GenesisColors.redPrimary);
    await tester.tap(find.widgetWithText(GenesisPrimaryButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(GenesisActionBox<bool>), findsOneWidget);
    expect(
      tester.getSize(find.byType(GenesisActionBoxSurface)).width,
      closeTo(
        (tester.view.physicalSize.width / tester.view.devicePixelRatio * 0.7)
            .clamp(0.0, 800.0),
        0.1,
      ),
    );
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.text('Delete'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();

    final logoutButtonTopBeforeKeyboard = tester
        .getTopLeft(find.widgetWithText(GenesisPrimaryButton, 'Log out'))
        .dy;

    await tester.tap(find.text('Feedback'));
    await tester.pumpAndSettle();

    expect(find.byType(GenesisActionBox<bool>), findsOneWidget);
    expect(find.text('Feedback'), findsWidgets);
    final inputFinder = find.byKey(
      const ValueKey<String>('genesis-feedback-content-input'),
    );
    final input = tester.widget<TextField>(inputFinder);
    expect(input.minLines, 5);
    expect(input.maxLines, 5);
    expect(input.autofocus, isTrue);
    expect(input.focusNode?.hasFocus, isTrue);
    expect(input.decoration?.filled, isTrue);
    expect(input.decoration?.fillColor, GenesisColors.darkFaintFill);
    expect(input.decoration?.focusedBorder?.borderSide, BorderSide.none);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();

    expect(
      tester
          .getTopLeft(find.widgetWithText(GenesisPrimaryButton, 'Log out'))
          .dy,
      logoutButtonTopBeforeKeyboard,
    );

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();

    await tester.enterText(inputFinder, '希望增加夜间模式');
    await tester.pump();
    await tester.tap(find.widgetWithText(InkWell, 'Submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Feedback submitted'), findsOneWidget);
    expect(transport.requestsFor('/api/v1/feedback/create'), hasLength(1));
    expect(
      transport.decodedBody(
        transport.requestsFor('/api/v1/feedback/create').single,
      ),
      {'content': '希望增加夜间模式'},
    );
    await tester.pumpAndSettle();
    expect(find.byType(GenesisActionBox<bool>), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}

AppServices _feedbackTestServices(_RecordingFeedbackTransport transport) {
  const config = AppConfig(useMock: false);
  final platformConfig = DefaultPlatformConfig(appConfig: config);
  final deviceId = const _FakeDeviceIdService();
  final sessionStore = MemoryUserSessionStore();
  final identityAuth = const _FakeIdentityAuthService();
  final api = GenesisApi(
    useMock: false,
    transport: transport,
    platformConfig: platformConfig,
    deviceIdService: deviceId,
    sessionStore: sessionStore,
    identityAuthService: identityAuth,
    appHeaderProvider: () async => const <String, String>{
      'app-id': 'test-app',
      'app-version': '1.0.0',
      'app-platform': 'test',
      'device-id': 'test-device-id',
    },
  );
  return AppServices(
    config: config,
    platformConfig: platformConfig,
    deviceId: deviceId,
    sessionStore: sessionStore,
    identityAuth: identityAuth,
    backendAuth: const _FakeBackendAuthCoordinator(),
    api: api,
    chatroom: ChatroomClient(
      wsBaseUrl: config.chatroomWsBaseUrl,
      sessionStore: sessionStore,
    ),
    chatroomMessages: MemoryChatroomMessageStorage(),
    directMessageConversations: DirectMessageConversationStore(
      api: api,
      sessionStore: sessionStore,
      storage: MemoryDirectMessageConversationStorage(),
    ),
    directMessageMessages: DirectMessageMessageStore(
      api: api,
      sessionStore: sessionStore,
      storage: MemoryDirectMessageMessageStorage(),
    ),
    appVersionCheck: const _NoUpgradeVersionCheckService(),
    externalUrlOpener: const _FakeExternalUrlOpener(),
  );
}

class _RecordingFeedbackTransport implements HttpTransport {
  final requests = <TransportRequest>[];
  int claimFailures = 0;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    if (request.uri.path.endsWith('/gem/task/claim')) {
      final failed = claimFailures > 0;
      if (failed) claimFailures--;
      return TransportResponse(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        body: failed
            ? '{"err_no":21006,"err_msg":"Not claimable","data":{}}'
            : '{"err_no":0,"err_msg":"succ","data":{"task_code":"rating","status":"claimed","reward_gems_cent":3000,"balance_cent":33000,"ledger_id":"rating_ledger"}}',
      );
    }
    if (request.uri.path.endsWith('/gem/wallet')) {
      return const TransportResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body:
            '{"err_no":0,"err_msg":"succ","data":{"wallet":{"balance_cent":33000}}}',
      );
    }
    return const TransportResponse(
      statusCode: 200,
      headers: {'content-type': 'application/json'},
      body: '{"err_no":0,"err_msg":"succ","data":{"feedback_id":"fbk_test"}}',
    );
  }

  List<TransportRequest> requestsFor(String path) {
    return requests.where((request) => request.uri.path == path).toList();
  }

  Map<String, dynamic> decodedBody(TransportRequest request) {
    return jsonDecode(utf8.decode(request.bodyBytes ?? const <int>[]))
        as Map<String, dynamic>;
  }
}

class _NoUpgradeVersionCheckService implements AppVersionCheckService {
  const _NoUpgradeVersionCheckService();

  @override
  Future<AppVersionCheckResult> check() async {
    return const AppVersionCheckResult.noUpgrade();
  }
}

class _FakeDeviceIdService implements DeviceIdService {
  const _FakeDeviceIdService();

  @override
  Future<String> getDeviceId() async => 'test-device-id';
}

class _FakeIdentityAuthService implements IdentityAuthService {
  const _FakeIdentityAuthService();

  @override
  Future<AuthSession?> refreshSilently() async => null;

  @override
  Future<AuthSession> signIn(IdentityProvider provider) {
    throw UnsupportedError('Identity sign-in is not used in this test.');
  }

  @override
  Future<void> signOutIdentity() async {}
}

class _FakeBackendAuthCoordinator implements BackendAuthCoordinator {
  const _FakeBackendAuthCoordinator();

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<bool> hasAuthenticatedBackendSession({
    bool tryAutoRefresh = true,
  }) async {
    return false;
  }

  @override
  Future<User> loginWithIdentity(
    AuthSession session, {
    LoginSource source = LoginSource.unknown,
  }) {
    throw UnsupportedError('Backend login is not used in this test.');
  }

  @override
  Future<void> signOut() async {}
}

class _FakeExternalUrlOpener implements ExternalUrlOpener {
  const _FakeExternalUrlOpener();

  @override
  Future<bool> open(String url) async => true;
}
