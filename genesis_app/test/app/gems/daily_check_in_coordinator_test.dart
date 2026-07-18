import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/daily_check_in_coordinator.dart';
import 'package:genesis_flutter_android/components/gems/daily_check_in_dialog.dart';
import 'package:genesis_flutter_android/network/models/gem_task.dart';
import 'package:genesis_flutter_android/network/models/gem_task_action.dart';

void main() {
  testWidgets('daily check-in reports and claims with one user action', (
    tester,
  ) async {
    var reportCalls = 0;
    var claimCalls = 0;
    var refreshCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => runDailyCheckInFlow(
              context,
              task: _dailyTask(status: 'in_progress'),
              reportTask: () async {
                reportCalls += 1;
                return const GemTaskActionResult(status: 'claimable');
              },
              claimTask: () async {
                claimCalls += 1;
                return const GemTaskActionResult(status: 'claimed');
              },
              refreshWallet: () async {
                refreshCalls += 1;
              },
            ),
            child: const Text('Login complete'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Login complete'));
    await tester.pumpAndSettle();
    expect(find.text('Check in'), findsOneWidget);

    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    expect(reportCalls, 1);
    expect(claimCalls, 1);
    expect(refreshCalls, 1);
    expect(find.text('Claim'), findsNothing);
    expect(find.text('Check in successful!'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Check in successful!'), findsNothing);
  });

  testWidgets('claimed daily check-in does not show after login', (
    tester,
  ) async {
    var reportCalls = 0;
    var claimCalls = 0;
    var refreshCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => runDailyCheckInFlow(
              context,
              task: _dailyTask(status: 'claimed'),
              reportTask: () async {
                reportCalls += 1;
                return const GemTaskActionResult(status: 'claimed');
              },
              claimTask: () async {
                claimCalls += 1;
                return const GemTaskActionResult(status: 'claimed');
              },
              refreshWallet: () async {
                refreshCalls += 1;
              },
            ),
            child: const Text('Login complete'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Login complete'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Check-in'), findsNothing);
    expect(reportCalls, 0);
    expect(claimCalls, 0);
    expect(refreshCalls, 0);
  });
}

GemTask _dailyTask({required String status}) {
  return GemTask(
    taskCode: dailyCheckInTaskCode,
    title: 'Daily Check-in',
    description: 'Check in every day.',
    rewardGems: 50,
    rewardValidDays: 1,
    cycleType: 'daily',
    cycleKey: '2026-07-18',
    progress: status == 'in_progress' ? 0 : 1,
    targetCount: 1,
    progressText: status == 'in_progress' ? '0/1' : '1/1',
    status: status,
    actionText: status == 'claimable' ? 'Claim' : 'Check in',
  );
}
