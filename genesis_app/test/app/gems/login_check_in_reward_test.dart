import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/app/bootstrap/service_registry.dart';
import 'package:genesis_flutter_android/app/gems/daily_check_in_coordinator.dart';
import 'package:genesis_flutter_android/app/gems/gem_wallet_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_access_store.dart';
import 'package:genesis_flutter_android/app/membership/membership_purchase_service.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/models/gem_task.dart';
import 'package:genesis_flutter_android/network/models/gem_wallet.dart';
import 'package:genesis_flutter_android/network/models/membership_claim.dart';
import 'package:genesis_flutter_android/network/models/membership_purchase.dart';
import 'package:genesis_flutter_android/network/v1/gem_api.dart';
import 'package:genesis_flutter_android/network/v1/genesis_v1_api.dart';
import 'package:genesis_flutter_android/platform/session/user_session_store.dart';

import '../membership/membership_purchase_service_test.dart' as support;

void main() {
  for (final outcome in [
    'completed',
    'accepted',
    'session_changed',
    'timeout',
  ]) {
    testWidgets('login reward query follows guest binding: $outcome', (
      tester,
    ) async {
      final h = support.Harness(claimEnabled: true)..uid = null;
      await h.service.purchase(h.product());
      await h.service.interceptPurchase(h.purchase());
      h.uid = 'first-login';
      var bound = false;
      final claim = Completer<MembershipClaimResult>();
      final refresh = Completer<void>();
      h.claimHandler = (_) async {
        final result = await claim.future;
        bound = result.status == MembershipReportStatus.completed;
        return result;
      };
      final wallet = GemWalletStore(
        readUid: () async => h.uid,
        loadWallet: () async => GemWallet(
          balanceCent: 0,
          membership: GemWalletMembership(
            status: bound ? 1 : 0,
            planCode: bound ? 'test-monthly' : '',
            expiresAt: bound ? DateTime.utc(2041) : null,
            autoRenew: bound,
            blueGemsCent: 0,
          ),
        ),
      );
      final membership = MembershipAccessStore(
        wallet: wallet,
        readLoginUid: () async => h.uid,
        serverNow: () => DateTime.utc(2040),
      );
      h.walletRefreshHandler = () async {
        await refresh.future;
        await wallet.refreshAfterMembershipChanged();
      };
      final gem = _GemApi(() => bound ? 10000 : 5000);
      final services = _Services(
        h.service,
        membership,
        wallet,
        _Api(_V1(gem)),
        _Session(() => h.uid),
      );
      services.pendingLoginCheckInUid.value = h.uid;
      await membership.refresh();
      try {
        await tester.pumpWidget(
          AppServicesScope(
            services: services,
            child: MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showPendingDailyCheckInAfterLogin(
                    context,
                    canShow: () => true,
                  ),
                  child: const Text('Login complete'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Login complete'));
        await tester.pumpAndSettle();
        expect(h.claimRequests, hasLength(1));
        expect(gem.calls, 0);
        expect(find.text('Daily Check-in'), findsNothing);
        if (outcome == 'session_changed') {
          h.uid = 'another-user';
          services.sessionRevision.value++;
        }
        if (outcome == 'timeout') {
          await tester.pump(membership.requestTimeout);
          expect(services.pendingLoginCheckInUid.value, isNull);
        }
        claim.complete(
          MembershipClaimResult(
            status: outcome == 'accepted'
                ? MembershipReportStatus.accepted
                : MembershipReportStatus.completed,
          ),
        );
        await tester.pumpAndSettle();
        expect(gem.calls, 0);
        refresh.complete();
        await tester.pumpAndSettle();
        if (outcome == 'completed') {
          expect(gem.calls, 1);
          expect(find.text('+100'), findsOneWidget);
          expect(find.text('+50'), findsNothing);
          expect(find.text('Cancel'), findsOneWidget);
          expect(find.text('Check in'), findsOneWidget);
          expect(find.text('Get 100'), findsNothing);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        } else {
          expect(gem.calls, 0);
          expect(find.text('Daily Check-in'), findsNothing);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        services.pendingLoginCheckInUid.dispose();
        services.sessionRevision.dispose();
        h.service.dispose();
        membership.dispose();
        wallet.dispose();
      }
    });
  }
}

class _Services extends Fake implements AppServices {
  _Services(
    this.membershipPurchases,
    this.membership,
    this.gemWallet,
    this.api,
    this.sessionStore,
  );
  @override
  final MembershipPurchaseService membershipPurchases;
  @override
  final MembershipAccessStore membership;
  @override
  final GemWalletStore gemWallet;
  @override
  final GenesisApi api;
  @override
  final UserSessionStore sessionStore;
  @override
  final pendingLoginCheckInUid = ValueNotifier<String?>(null);
  @override
  final sessionRevision = ValueNotifier<int>(0);
  @override
  void dispose() {}
}

class _Session extends Fake implements UserSessionStore {
  _Session(this.uid);
  final String? Function() uid;
  @override
  Future<String?> readUid() async => uid();
}

class _Api extends Fake implements GenesisApi {
  _Api(this.v1);
  @override
  final GenesisV1Api v1;
}

class _V1 extends Fake implements GenesisV1Api {
  _V1(this.gem);
  @override
  final GemV1Api gem;
}

class _GemApi extends Fake implements GemV1Api {
  _GemApi(this.reward);
  final int Function() reward;
  int calls = 0;
  @override
  Future<GemTaskList> tasks() async {
    calls++;
    return GemTaskList(
      groups: [
        GemTaskGroup(
          groupCode: 'daily',
          groupTitle: 'Daily',
          tasks: [
            GemTask(
              taskCode: 'daily_checkin',
              title: 'Daily Check-in',
              description: '',
              rewardGemsCent: reward(),
              rewardValidDays: 1,
              cycleType: 'daily',
              cycleKey: 'test-day',
              progress: 0,
              targetCount: 1,
              progressText: '0/1',
              status: 'in_progress',
              actionText: 'Check in',
            ),
          ],
        ),
      ],
    );
  }
}
