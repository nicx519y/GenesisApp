import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/membership_product.dart';
import 'package:genesis_flutter_android/platform/billing/membership_restore_record.dart';

import 'membership_purchase_service_test.dart' as support;

MembershipRestoreRecord legacy(
  support.Harness h, {
  String id = 'legacy-restore',
  String? owner,
  String transaction = '100',
  String? status = 'accepted',
  String? reason,
  bool finished = false,
}) => MembershipRestoreRecord(
  requestId: id,
  ownerUid: owner ?? h.uid!,
  purchase: h.purchase(transaction: transaction),
  product: h.product(),
  reportStatus: status,
  finished: finished,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final provider in MembershipProvider.values) {
    for (final status in [null, 'accepted', 'completed', 'rejected']) {
      for (final finished in [false, true]) {
        test(
          '$provider legacy $status finished=$finished is removed without report',
          () async {
            final h = support.Harness(provider: provider);
            await h.store.saveRestore(
              legacy(h, status: status, finished: finished),
            );
            await h.service.start();
            expect(h.reports, isEmpty);
            expect(h.store.restores, isEmpty);
            expect(h.store.records, isEmpty);
            h.service.dispose();
            final restarted = support.Harness(
              provider: provider,
              storage: h.store,
            );
            await restarted.service.start();
            expect(restarted.reports, isEmpty);
          },
        );
      }
    }
    test(
      '$provider cleanup failure retries only cleanup, never report',
      () async {
        final h = support.Harness(provider: provider);
        await h.store.saveRestore(legacy(h));
        h.store.failRestoreCleanup = true;
        await h.service.recover();
        expect(h.reports, isEmpty);
        expect(h.store.restores, hasLength(1));
        h.service.dispose();
        h.store.failRestoreCleanup = false;
        final restarted = support.Harness(provider: provider, storage: h.store);
        await restarted.service.recover();
        expect(restarted.reports, isEmpty);
        expect(h.store.restores, isEmpty);
        expect(h.store.records, isEmpty);
      },
    );
    test(
      '$provider foreign legacy receipt cannot affect new checkout',
      () async {
        final h = support.Harness(provider: provider);
        await h.store.saveRestore(legacy(h, owner: 'other-owner'));
        await h.service.purchase(h.product());
        expect(h.platform.launches, 1);
        expect(h.reports, isEmpty);
        await h.service.interceptPurchase(h.purchase(transaction: 'new'));
        expect(h.reports.single.transactionId, 'new');
      },
    );
  }
}
