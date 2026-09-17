import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/billing/pending_purchase_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('SQLite v3 Gems queue migrates optional store price columns', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'genesis-billing-migration-',
    );
    final path = '${directory.path}/billing.db';
    final legacy = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE billing_pending_purchases (
            provider TEXT NOT NULL,
            purchase_token TEXT NOT NULL,
            attempt_id TEXT NOT NULL,
            billing_account_id TEXT NOT NULL,
            product_id TEXT NOT NULL,
            store_product_id TEXT NOT NULL,
            transaction_id TEXT NOT NULL,
            original_json TEXT NOT NULL,
            purchase_time TEXT NOT NULL,
            status TEXT NOT NULL,
            retry_count INTEGER NOT NULL,
            report_timeout_tracked INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY(provider, purchase_token)
          )
        '''),
      ),
    );
    await legacy.insert('billing_pending_purchases', <String, Object?>{
      'provider': 'googlePlay',
      'purchase_token': 'legacy-token',
      'attempt_id': 'legacy-attempt',
      'billing_account_id': 'account',
      'product_id': 'gems-500',
      'store_product_id': 'worldo_gems_500',
      'transaction_id': 'GPA.legacy',
      'original_json': '{}',
      'purchase_time': '1000',
      'status': 'pending',
      'retry_count': 0,
      'report_timeout_tracked': 0,
      'created_at': 1,
      'updated_at': 1,
    });
    await legacy.close();

    final store = SqfliteBillingPendingPurchaseStore(
      databaseFactoryOverride: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(() async {
      await store.close();
      if (directory.existsSync()) await directory.delete(recursive: true);
    });

    final migrated = (await store.loadAll()).single;
    expect(migrated.priceAmountMicros, isNull);
    expect(migrated.priceCurrencyCode, isEmpty);

    await store.upsert(
      migrated.copyWith(priceAmountMicros: 1490000, priceCurrencyCode: 'USD'),
    );
    final priced = (await store.loadAll()).single;
    expect(priced.priceAmountMicros, 1490000);
    expect(priced.priceCurrencyCode, 'USD');
  });
}
