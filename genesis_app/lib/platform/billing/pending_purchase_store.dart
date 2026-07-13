import 'package:sqflite/sqflite.dart';

import 'billing_models.dart';

abstract interface class BillingPendingPurchaseStore {
  Future<List<BillingPendingPurchase>> loadAll();

  Future<BillingPendingPurchase?> find({
    required BillingProvider provider,
    required String purchaseToken,
  });

  Future<void> upsert(BillingPendingPurchase purchase);

  Future<void> remove({
    required BillingProvider provider,
    required String purchaseToken,
  });
}

class SqfliteBillingPendingPurchaseStore
    implements BillingPendingPurchaseStore {
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final root = await getDatabasesPath();
    final database = await openDatabase(
      '$root/genesis_billing.db',
      version: 1,
      onCreate: (db, _) => db.execute(_createTableSql),
    );
    _database = database;
    return database;
  }

  @override
  Future<List<BillingPendingPurchase>> loadAll() async {
    final rows = await (await _db).query(
      'billing_pending_purchases',
      orderBy: 'updated_at ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<BillingPendingPurchase?> find({
    required BillingProvider provider,
    required String purchaseToken,
  }) async {
    final rows = await (await _db).query(
      'billing_pending_purchases',
      where: 'provider = ? AND purchase_token = ?',
      whereArgs: <Object>[provider.name, purchaseToken],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  @override
  Future<void> upsert(BillingPendingPurchase purchase) async {
    await (await _db).insert(
      'billing_pending_purchases',
      _toRow(purchase),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove({
    required BillingProvider provider,
    required String purchaseToken,
  }) async {
    await (await _db).delete(
      'billing_pending_purchases',
      where: 'provider = ? AND purchase_token = ?',
      whereArgs: <Object>[provider.name, purchaseToken],
    );
  }
}

class MemoryBillingPendingPurchaseStore implements BillingPendingPurchaseStore {
  final Map<String, BillingPendingPurchase> _purchases =
      <String, BillingPendingPurchase>{};

  @override
  Future<List<BillingPendingPurchase>> loadAll() async {
    final values = _purchases.values.toList(growable: false)
      ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return values;
  }

  @override
  Future<BillingPendingPurchase?> find({
    required BillingProvider provider,
    required String purchaseToken,
  }) async {
    return _purchases['${provider.name}:$purchaseToken'];
  }

  @override
  Future<void> upsert(BillingPendingPurchase purchase) async {
    _purchases[purchase.key] = purchase;
  }

  @override
  Future<void> remove({
    required BillingProvider provider,
    required String purchaseToken,
  }) async {
    _purchases.remove('${provider.name}:$purchaseToken');
  }
}

Map<String, Object?> _toRow(BillingPendingPurchase purchase) {
  return <String, Object?>{
    'provider': purchase.provider.name,
    'purchase_token': purchase.purchaseToken,
    'attempt_id': purchase.attemptId,
    'billing_account_id': purchase.billingAccountId,
    'product_id': purchase.productId,
    'store_product_id': purchase.storeProductId,
    'transaction_id': purchase.transactionId,
    'original_json': purchase.originalJson,
    'purchase_time': purchase.purchaseTime,
    'status': purchase.status.name,
    'retry_count': purchase.retryCount,
    'created_at': purchase.createdAt.millisecondsSinceEpoch,
    'updated_at': purchase.updatedAt.millisecondsSinceEpoch,
  };
}

BillingPendingPurchase _fromRow(Map<String, Object?> row) {
  return BillingPendingPurchase(
    provider: BillingProvider.values.byName('${row['provider']}'),
    purchaseToken: '${row['purchase_token'] ?? ''}',
    attemptId: '${row['attempt_id'] ?? ''}',
    billingAccountId: '${row['billing_account_id'] ?? ''}',
    productId: '${row['product_id'] ?? ''}',
    storeProductId: '${row['store_product_id'] ?? ''}',
    transactionId: '${row['transaction_id'] ?? ''}',
    originalJson: '${row['original_json'] ?? ''}',
    purchaseTime: '${row['purchase_time'] ?? ''}',
    status: BillingPendingPurchaseStatus.values.byName('${row['status']}'),
    retryCount: row['retry_count'] as int? ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
  );
}

const _createTableSql = '''
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
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY(provider, purchase_token)
  )
''';
