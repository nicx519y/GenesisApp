import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/components/gems/daily_check_in_dialog.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/network/models/membership_claim.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';

import '../app/membership/membership_purchase_service_test.dart' as support;

GemWallet _wallet({required bool member}) => GemWallet(
  balanceCent: 5000,
  membership: GemWalletMembership(
    status: member ? 1 : 0,
    planCode: member ? 'pro_monthly' : '',
    expiresAt: member ? DateTime.utc(2041) : null,
    autoRenew: member,
    blueGemsCent: member ? 30000 : 0,
  ),
);

void main() {
  test(
    'a login without paid guest records does not start claim or report work',
    () async {
      final h = support.Harness(claimEnabled: true);
      expect(await h.service.waitForGuestClaim(), isTrue);
      expect(h.claimRequests, isEmpty);
      expect(h.reports, isEmpty);
      expect(h.refreshes, 0);
      expect(h.guestDiscoveries, 0);
    },
  );

  test(
    'concurrent waiters share one claim and wait for its wallet refresh',
    () async {
      final h = support.Harness(claimEnabled: true)..uid = null;
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(h.purchase());
      h.uid = 'first-login';
      final claim = Completer<MembershipClaimResult>();
      final refresh = Completer<void>();
      h.claimHandler = (_) => claim.future;
      h.walletRefreshHandler = () => refresh.future;
      final results = <bool>[];
      final first = h.service.waitForGuestClaim().then(results.add);
      final second = h.service.waitForGuestClaim().then(results.add);
      await pumpEventQueue();
      expect(h.claimRequests, hasLength(1));
      expect(results, isEmpty);
      claim.complete(
        MembershipClaimResult(status: MembershipReportStatus.completed),
      );
      await pumpEventQueue();
      expect(results, isEmpty);
      refresh.complete();
      await Future.wait([first, second]);
      expect(results, [true, true]);
      expect(h.claimRequests, hasLength(1));
    },
  );

  for (final outcome in [
    'completed',
    'accepted',
    'claim_error',
    'wallet_error',
  ]) {
    testWidgets(
      'check-in waits for guest binding before choosing buttons: $outcome',
      (tester) async {
        final h = support.Harness(claimEnabled: true)..uid = null;
        await h.service.purchase(h.product());
        await h.service.interceptPurchase(h.purchase());
        h.uid = 'first-login';
        final claimResponse = Completer<MembershipClaimResult>();
        final walletResponse = Completer<GemWallet>();
        var walletCalls = 0;
        final wallet = GemWalletStore(
          readUid: () async => h.uid,
          loadWallet: () async => ++walletCalls == 1
              ? _wallet(member: false)
              : walletResponse.future,
        );
        final membership = MembershipAccessStore(
          wallet: wallet,
          readLoginUid: () async => h.uid,
          serverNow: () => DateTime.utc(2040),
        );
        h.claimHandler = (_) => claimResponse.future;
        h.walletRefreshHandler = wallet.refreshAfterMembershipChanged;
        // Login's wallet response arrives before this guest purchase is bound.
        expect((await membership.refresh()).isVip, isFalse);
        bool? confirmed;
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    confirmed = await showDailyCheckInDialog(
                      context,
                      status: DailyCheckInDialogStatus.checkIn,
                      membershipAccess: membership,
                      membershipPurchases: h.service,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(h.claimRequests, hasLength(1));
          expect(find.text('Daily Check-in'), findsNothing);
          expect(find.text('Get 100'), findsNothing);

          if (outcome == 'claim_error') {
            claimResponse.completeError(StateError('claim offline'));
          } else {
            claimResponse.complete(
              MembershipClaimResult(
                status: outcome == 'accepted'
                    ? MembershipReportStatus.accepted
                    : MembershipReportStatus.completed,
              ),
            );
          }
          await tester.pumpAndSettle();
          if (outcome == 'completed' || outcome == 'wallet_error') {
            expect(walletCalls, 2);
            expect(find.text('Daily Check-in'), findsNothing);
            if (outcome == 'wallet_error') {
              walletResponse.completeError(StateError('wallet offline'));
            } else {
              walletResponse.complete(_wallet(member: true));
            }
            await tester.pumpAndSettle();
          }
          expect(find.text('Daily Check-in'), findsOneWidget);
          expect(find.text('Get 100'), findsNothing);
          expect(find.text('Check in'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('daily-check-in-subscription-gem')),
            findsNothing,
          );
          expect(h.claimRequests, hasLength(1));
          if (outcome == 'completed') {
            // Member actions keep the shared Cancel row at the bottom.
            expect(
              tester.getCenter(find.text('Cancel')).dy,
              greaterThan(tester.getCenter(find.text('Check in')).dy),
            );
            expect(h.store.claims, isEmpty);
            expect(membership.state.value.isVip, isTrue);
          } else {
            expect(h.store.claims, hasLength(1));
          }
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(confirmed, isFalse);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          h.service.dispose();
          membership.dispose();
          wallet.dispose();
        }
      },
    );
  }

  testWidgets(
    'an in-flight wallet from before binding cannot choose non-member buttons',
    (tester) async {
      final h = support.Harness(claimEnabled: true)..uid = null;
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(h.purchase());
      h.uid = 'first-login';
      final beforeBinding = Completer<GemWallet>();
      final afterBinding = Completer<GemWallet>();
      var walletCalls = 0;
      final wallet = GemWalletStore(
        readUid: () async => h.uid,
        loadWallet: () =>
            ++walletCalls == 1 ? beforeBinding.future : afterBinding.future,
      );
      final membership = MembershipAccessStore(
        wallet: wallet,
        readLoginUid: () async => h.uid,
        serverNow: () => DateTime.utc(2040),
      );
      h.walletRefreshHandler = wallet.refreshAfterMembershipChanged;
      final loginRefresh = membership.refresh();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDailyCheckInDialog(
                  context,
                  status: DailyCheckInDialogStatus.checkIn,
                  membershipAccess: membership,
                  membershipPurchases: h.service,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(h.claimRequests, hasLength(1));
        expect(walletCalls, 1);
        beforeBinding.complete(_wallet(member: false));
        await tester.pumpAndSettle();
        await loginRefresh;
        expect(walletCalls, 2);
        expect(find.text('Daily Check-in'), findsNothing);
        afterBinding.complete(_wallet(member: true));
        await tester.pumpAndSettle();
        expect(find.text('Get 100'), findsNothing);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Check in'), findsOneWidget);
        expect(membership.state.value.isVip, isTrue);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        h.service.dispose();
        membership.dispose();
        wallet.dispose();
      }
    },
  );
}
