import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/network/models/gem_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/gems/gem_daily_reset_countdown.dart';
import 'package:genesis_flutter_android/l10n/app_localizations.dart';

void main() {
  test(
    'countdown contract accepts seconds and hides missing or invalid data',
    () {
      GemTaskGroup group(Object? value) => GemTaskGroup.fromJson({
        'group_code': 'daily',
        'tasks': [],
        'next_claim_countdown_seconds': value,
      });
      expect(group(86400).nextClaimCountdownSeconds, 86400);
      expect(group(1).nextClaimCountdownSeconds, 1);
      for (final value in [null, 0, -1, 86401, 2.5, '20']) {
        expect(group(value).nextClaimCountdownSeconds, isNull);
      }
    },
  );

  test('reads only group countdown, ignoring obsolete task field', () {
    final list = GemTaskList.fromJson({
      'list': [
        {
          'group_code': 'daily',
          'next_claim_countdown_seconds': 57600,
          'tasks': [
            {'reward_gems_cent': 100, 'next_claim_countdown_seconds': 99},
          ],
        },
        {
          'group_code': 'starter',
          'tasks': [
            {'reward_gems_cent': 100, 'next_claim_countdown_seconds': 99},
          ],
        },
      ],
    });
    expect(list.groups.first.nextClaimCountdownSeconds, 57600);
    expect(list.groups.last.nextClaimCountdownSeconds, isNull);
  });

  testWidgets('uses elapsed time, survives rebuild, expires once', (
    tester,
  ) async {
    var elapsed = Duration.zero;
    var expired = 0;
    final clock = GemDailyResetClock(3661, elapsed: () => elapsed);
    Widget page() => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: GemDailyResetCountdown(clock: clock, onExpired: () => expired++),
    );
    await tester.pumpWidget(page());
    expect(find.text('Resets in 01:01:01'), findsOneWidget);
    elapsed = const Duration(seconds: 61);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resets in 01:00:00'), findsOneWidget);
    await tester.pumpWidget(page());
    expect(find.text('Resets in 01:00:00'), findsOneWidget);
    elapsed = const Duration(days: 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resets in 00:00:00'), findsOneWidget);
    expect(expired, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(expired, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
