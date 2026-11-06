import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/components/common/genesis_action_box.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/network/models/membership_order_product.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/components/gems/daily_check_in_dialog.dart';
import 'package:genesis_flutter_android/components/gems/pro_subscription_content.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

void main() {
  for (final scenario in [
    'monthly',
    'yearly',
    'deluxe',
    'both',
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
      final memberLayout = [
        'monthly',
        'yearly',
        'deluxe',
        'both',
      ].contains(scenario);
      final noOffers =
          memberLayout || ['unknown', 'missing_membership'].contains(scenario);
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
                    rewardGemsCentPremium: 10000,
                    rewardGemsCentDeluxe: 25000,
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
                status: ['non_member', 'deluxe'].contains(scenario)
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
              membershipDeluxe: ['deluxe', 'both'].contains(scenario)
                  ? GemWalletMembership(
                      status: 1,
                      planCode: 'deluxe_monthly',
                      expiresAt: DateTime.utc(2041),
                      autoRenew: true,
                      blueGemsCent: 0,
                    )
                  : null,
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Daily Check-in'), findsOneWidget);
        expect(find.text('+50'), findsOneWidget);
        expect(find.text('Check in'), findsOneWidget);
        expect(find.text('Claim'), findsNothing);
        expect(find.text('Get 150'), !noOffers ? findsOneWidget : findsNothing);
        expect(find.text('Get 300'), !noOffers ? findsOneWidget : findsNothing);
        expect(
          find.text('Cancel'),
          memberLayout ? findsOneWidget : findsNothing,
        );
        expect(find.text('Worldo Premium'), findsNothing);
        expect(find.text('Worldo Deluxe'), findsNothing);
        if (!noOffers) {
          expect(find.byType(GenesisActionBoxDivider), findsNWidgets(3));
          expect(
            tester.widget<Text>(find.text('Get 150')).style?.color,
            GenesisColors.redSecondary,
          );
          expect(
            tester.getCenter(find.text('Get 300')).dy,
            lessThan(tester.getCenter(find.text('Get 150')).dy),
          );
          expect(
            tester.getCenter(find.text('Get 150')).dy,
            lessThan(tester.getCenter(find.text('Check in')).dy),
          );
        }
        if (memberLayout) {
          await tester.tap(find.text('Cancel'));
        } else if (noOffers) {
          await tester.tapAt(const Offset(1, 1));
        } else {
          await tester.tap(find.text('Check in'));
        }
        await tester.pumpAndSettle();
        expect(checkedIn, !noOffers);
        if (scenario == 'non_member') {
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(requests, 1);
          await tester.tap(
            find.text(scenario == 'deluxe' ? 'Get 150' : 'Get 300'),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ProSubscriptionContent>(
                  find.byType(ProSubscriptionContent),
                )
                .initialMembershipType,
            scenario == 'deluxe'
                ? MembershipType.premium
                : MembershipType.deluxe,
          );
          await tester.tap(
            find.byKey(const ValueKey('gem-purchase-sheet-close')),
          );
          await tester.pumpAndSettle();
          expect(checkedIn, isFalse);
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
                      rewardGemsCentPremium: 10000,
                      rewardGemsCentDeluxe: 25000,
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
          expect(find.text('Get 150'), findsNothing);
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
          expect(find.text('Get 300'), findsNothing);
          expect(
            find.text('Cancel'),
            refreshFails ? findsNothing : findsOneWidget,
          );
          expect(find.text('Check in'), findsOneWidget);
          expect(requests, 2);
          if (refreshFails) {
            await tester.tapAt(const Offset(1, 1));
          } else {
            await tester.tap(find.text('Check in'));
          }
          await tester.pumpAndSettle();
          expect(checkedIn, !refreshFails);
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
    'daily check-in success shows the reward and dismisses after three seconds',
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
      expect(
        tester.getCenter(find.text('+50')).dx,
        lessThan(
          tester
              .getCenter(
                find.byKey(const ValueKey<String>('gem-task-reward-icon')),
              )
              .dx,
        ),
      );
      expect(find.text('Check in'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Get 150'), findsNothing);

      await tester.tap(find.text('Check in'));
      await tester.pumpAndSettle();

      expect(find.text('Check in successful!'), findsOneWidget);
      expect(find.text('+50'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('+50')).style?.color,
        GenesisColors.darkTextSecondary,
      );
      expect(find.byType(GenesisActionBoxDivider), findsNothing);

      expect(find.text('Worldo Premium'), findsNothing);
      expect(find.text('Worldo Deluxe'), findsNothing);
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text('Check in successful!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Check in successful!'), findsNothing);
    },
  );

  testWidgets('Get 150 opens Subscription without performing check-in', (
    tester,
  ) async {
    final wallet = GemWalletStore(
      readUid: () async => null,
      loadWallet: () async => const GemWallet(balanceCent: 0),
    );
    final membership = MembershipAccessStore(
      wallet: wallet,
      readLoginUid: () async => null,
      serverNow: () => DateTime.utc(2040),
    );
    addTearDown(membership.dispose);
    addTearDown(wallet.dispose);
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
                membershipAccess: membership,
                rewardGemsCentPremium: 10000,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get 150'));
    await tester.pumpAndSettle();
    expect(find.byType(ProSubscriptionContent), findsOneWidget);
    expect(
      tester
          .widget<ProSubscriptionContent>(find.byType(ProSubscriptionContent))
          .initialMembershipType,
      MembershipType.premium,
    );
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

    await tester.tapAt(const Offset(1, 1));
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
