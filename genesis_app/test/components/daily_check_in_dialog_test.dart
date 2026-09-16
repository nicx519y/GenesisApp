import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/components/gems/daily_check_in_dialog.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  for (final scenario in [
    'monthly',
    'yearly',
    'non_member',
    'expired_status',
    'expired_time',
    'unknown',
    'missing_membership',
  ]) {
    testWidgets('daily check-in uses global membership buttons: $scenario', (
      tester,
    ) async {
      final now = DateTime.utc(2040);
      final active = ['monthly', 'yearly'].contains(scenario);
      var requests = 0;
      final response = Completer<GemWallet>();
      final wallet = GemWalletStore(
        readUid: () async => 'user-test',
        loadWallet: () {
          requests++;
          return response.future;
        },
      );
      final membership = MembershipAccessStore(
        wallet: wallet,
        readLoginUid: () async => 'user-test',
        serverNow: () => now,
      );
      bool? checkedIn;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  checkedIn = await showDailyCheckInDialog(
                    context,
                    status: DailyCheckInDialogStatus.checkIn,
                    membershipAccess: membership,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(requests, 1);
        expect(find.text('Daily Check-in'), findsNothing);
        if (scenario == 'unknown') {
          response.completeError(StateError('offline'));
        } else if (scenario == 'missing_membership') {
          response.complete(const GemWallet(balanceCent: 5000));
        } else {
          response.complete(
            GemWallet(
              balanceCent: 5000,
              membership: GemWalletMembership(
                status: scenario == 'non_member'
                    ? 0
                    : scenario == 'expired_status'
                    ? 2
                    : 1,
                planCode: scenario == 'yearly' ? 'pro_yearly' : 'pro_monthly',
                expiresAt: scenario == 'expired_time'
                    ? now
                    : DateTime.utc(2041),
                autoRenew: true,
                blueGemsCent: 30000,
              ),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Daily Check-in'), findsOneWidget);
        expect(find.text('+50'), findsOneWidget);
        expect(find.text('Check in'), findsOneWidget);
        expect(find.text('Claim'), findsNothing);
        if (active) {
          expect(find.text('Get 100'), findsNothing);
          expect(find.text('Cancel'), findsOneWidget);
          if (active) {
            expect(
              tester.getCenter(find.text('Cancel')).dy,
              greaterThan(tester.getCenter(find.text('Check in')).dy),
            );
            expect(
              tester.widget<Text>(find.text('Cancel')).style?.color,
              GenesisColors.darkTextPrimary,
            );
            expect(
              tester.widget<Text>(find.text('Check in')).style?.color,
              GenesisColors.redSecondary,
            );
            expect(
              tester.widget<Text>(find.text('Check in')).style?.fontWeight,
              FontWeight.w600,
            );
            expect(
              find.byKey(const ValueKey('daily-check-in-subscription-gem')),
              findsNothing,
            );
          }
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(checkedIn, isFalse);
          expect(find.byType(ProSubscriptionContent), findsNothing);
          // Reopening with a valid snapshot must reuse the global cache.
          if (active) {
            await tester.tap(find.text('Open'));
            await tester.pumpAndSettle();
            expect(requests, 1);
            await tester.tap(find.text('Check in'));
            await tester.pumpAndSettle();
            expect(checkedIn, isTrue);
          }
        } else {
          expect(find.text('Get 100'), findsOneWidget);
          expect(find.text('Cancel'), findsNothing);
          if (scenario == 'unknown' || scenario == 'missing_membership') {
            expect(membership.state.value.isVip, isNull);
          }
          await tester.tap(find.text('Check in'));
          await tester.pumpAndSettle();
          expect(checkedIn, isTrue);
        }
        expect(find.text('Daily Check-in'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        membership.dispose();
        wallet.dispose();
      }
    });
  }

  for (final refreshFails in [false, true]) {
    testWidgets(
      'daily check-in waits for wallet refresh over non-member cache (fails: $refreshFails)',
      (tester) async {
        var requests = 0;
        final response = Completer<GemWallet>();
        final wallet = GemWalletStore(
          readUid: () async => 'user-test',
          loadWallet: () async {
            if (++requests > 1) return response.future;
            return GemWallet(
              balanceCent: 5000,
              membership: const GemWalletMembership(
                status: 0,
                planCode: '',
                expiresAt: null,
                autoRenew: false,
                blueGemsCent: 0,
              ),
            );
          },
        );
        final membership = MembershipAccessStore(
          wallet: wallet,
          readLoginUid: () async => 'user-test',
          serverNow: () => DateTime.utc(2040),
        );
        bool? checkedIn;
        try {
          expect((await membership.refresh()).isVip, isFalse);
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    checkedIn = await showDailyCheckInDialog(
                      context,
                      status: DailyCheckInDialogStatus.checkIn,
                      membershipAccess: membership,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          );
          final walletRequest = wallet.refresh();
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text('Daily Check-in'), findsNothing);
          expect(find.text('Get 100'), findsNothing);
          expect(checkedIn, isNull);
          expect(requests, 2);

          if (refreshFails) {
            response.completeError(StateError('offline'));
          } else {
            response.complete(
              GemWallet(
                balanceCent: 5000,
                membership: GemWalletMembership(
                  status: 1,
                  planCode: 'pro_monthly',
                  expiresAt: DateTime.utc(2041),
                  autoRenew: true,
                  blueGemsCent: 30000,
                ),
              ),
            );
          }
          await walletRequest;
          await tester.pumpAndSettle();
          expect(find.text('Daily Check-in'), findsOneWidget);
          expect(
            find.text('Get 100'),
            refreshFails ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Cancel'),
            refreshFails ? findsNothing : findsOneWidget,
          );
          expect(find.text('Check in'), findsOneWidget);
          expect(requests, 2);
          await tester.tap(find.text(refreshFails ? 'Check in' : 'Cancel'));
          await tester.pumpAndSettle();
          expect(checkedIn, refreshFails);
          expect(find.byType(ProSubscriptionContent), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          membership.dispose();
          wallet.dispose();
        }
      },
    );
  }

  testWidgets(
    'daily check-in shows success and dismisses after three seconds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const GenesisScrollBehavior(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final checkedIn = await showDailyCheckInDialog(
                  context,
                  status: DailyCheckInDialogStatus.checkIn,
                );
                if (checkedIn && context.mounted) {
                  await showDailyCheckInSuccessDialog(context);
                }
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Check-in'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('+50')).style?.color,
        GenesisColors.darkTextSecondary,
      );
      expect(
        find.byKey(const ValueKey<String>('gem-task-reward-icon')),
        findsOneWidget,
      );
      expect(find.text('Check in'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Get 100'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Check in')).style?.fontWeight,
        FontWeight.w600,
      );
      expect(
        tester.widget<Text>(find.text('Get 100')).style?.color,
        GenesisColors.redSecondary,
      );
      expect(
        tester.widget<Text>(find.text('Check in')).style?.color,
        GenesisColors.darkTextPrimary,
      );
      expect(
        tester.getCenter(find.text('Get 100')).dy,
        lessThan(tester.getCenter(find.text('Check in')).dy),
      );
      final gem = find.byKey(const ValueKey('daily-check-in-subscription-gem'));
      expect(tester.getSize(gem).height, 16);
      expect(
        tester.getTopLeft(gem).dx - tester.getTopRight(find.text('Get 100')).dx,
        4,
      );

      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();

      expect(find.text('Check in successful!'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('+50')).style?.color,
        GenesisColors.darkTextSecondary,
      );

      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text('Check in successful!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Check in successful!'), findsNothing);
    },
  );

  testWidgets('Get 100 opens Subscription without performing check-in', (
    tester,
  ) async {
    bool? checkedIn;
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const GenesisScrollBehavior(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              checkedIn = await showDailyCheckInDialog(
                context,
                status: DailyCheckInDialogStatus.checkIn,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get 100'));
    await tester.pumpAndSettle();
    expect(find.byType(ProSubscriptionContent), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Buy Gems'), findsNothing);
    expect(find.text('Daily Check-in'), findsNothing);
    expect(checkedIn, isNull);
    final close = find.byKey(const ValueKey('gem-purchase-sheet-close'));
    final route =
        ModalRoute.of(tester.element(close))! as ModalBottomSheetRoute<void>;
    expect(route.isDismissible, isFalse);
    expect(route.enableDrag, isFalse);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(close, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(close, findsNothing);
    expect(checkedIn, isFalse);
  });

  testWidgets('claimed daily check-in action is disabled', (tester) async {
    var checkedIn = false;
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const GenesisScrollBehavior(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              checkedIn = await showDailyCheckInDialog(
                context,
                status: DailyCheckInDialogStatus.claimed,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Claimed'), findsOneWidget);

    await tester.tap(find.text('Claimed'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Check-in'), findsOneWidget);
    expect(checkedIn, isFalse);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Check-in'), findsNothing);
    expect(checkedIn, isFalse);
  });

  testWidgets('generic task success uses supplied title and reward', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const GenesisScrollBehavior(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGemTaskSuccessDialog(
              context,
              title: 'Claim successful!',
              rewardGemsCent: 12000,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Claim successful!'), findsOneWidget);
    expect(find.text('+120'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
