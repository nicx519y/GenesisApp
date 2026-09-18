import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../network/models/membership_order_product.dart';
import '../../app/membership/subscription_analytics.dart';
import '../../network/models/membership_purchase.dart';
import 'membership_restore_record.dart';
import 'membership_guest_claim_record.dart';

String membershipPurchaseTokenFingerprint(String token) =>
    sha256.convert(utf8.encode(token)).toString();

class MembershipPurchaseRecord {
  const MembershipPurchaseRecord({
    required this.requestId,
    required this.product,
    required this.accountUuid,
    required this.ownerUid,
    this.guest,
    this.transactionId = '',
    this.originalTransactionId = '',
    this.purchaseToken = '',
    this.signedTransaction = '',
    this.replacedPurchaseTokenFingerprint = '',
    this.state = 'prepared',
    this.reportStatus,
    this.reportReason,
    this.finished = false,
    this.tracking,
    this.priceAmountMicros,
    this.priceCurrencyCode = '',
  });

  final String requestId;
  final MembershipOrderProduct product;
  final String accountUuid;
  final String? ownerUid;
  final MembershipGuestIdentity? guest;
  final String transactionId;
  final String originalTransactionId;
  final String purchaseToken;
  // Kept with the guest receipt in secure storage until claim completes.
  final String signedTransaction;
  // Legacy attempts may carry an old-token digest. Keep reading it so their
  // delayed callbacks remain excluded after an app update.
  final String replacedPurchaseTokenFingerprint;
  final String state;
  final String? reportStatus;
  final String? reportReason;
  // Legacy local-cache field retained for format compatibility only. Store
  // settlement now belongs to the server and never depends on this value.
  final bool finished;
  final SubscriptionTracking? tracking;
  final int? priceAmountMicros;
  final String priceCurrencyCode;

  bool replacesPurchaseToken(String token) =>
      token.isNotEmpty &&
      replacedPurchaseTokenFingerprint.isNotEmpty &&
      membershipPurchaseTokenFingerprint(token) ==
          replacedPurchaseTokenFingerprint;

  bool get hasReceipt => product.provider == MembershipProvider.google
      ? purchaseToken.isNotEmpty
      : transactionId.isNotEmpty;
  bool get paid => state == 'purchased' || state == 'restored';
  // A purchase status without any receipt cannot be reported or treated as
  // proof of payment. Keep its identity so a later store callback can recover it.
  bool get needsReceiptRecovery =>
      reportStatus == null &&
      !hasReceipt &&
      (paid || state == 'receipt_missing');
  MembershipPurchaseRequest get request => MembershipPurchaseRequest(
    product: product,
    transactionId: transactionId,
    purchaseToken: purchaseToken,
    signedTransaction: signedTransaction,
    guest: guest,
  );

  MembershipPurchaseRecord copyWith({
    String? requestId,
    MembershipOrderProduct? product,
    String? transactionId,
    String? originalTransactionId,
    String? purchaseToken,
    String? signedTransaction,
    String? state,
    String? reportStatus,
    String? reportReason,
    bool? finished,
    SubscriptionTracking? tracking,
    int? priceAmountMicros,
    String? priceCurrencyCode,
    bool clearPrice = false,
    bool newReport = false,
    bool retryReport = false,
  }) => MembershipPurchaseRecord(
    requestId: requestId ?? this.requestId,
    product: product ?? this.product,
    accountUuid: accountUuid,
    ownerUid: ownerUid,
    guest: guest,
    transactionId: transactionId ?? this.transactionId,
    originalTransactionId: originalTransactionId ?? this.originalTransactionId,
    purchaseToken: purchaseToken ?? this.purchaseToken,
    signedTransaction:
        signedTransaction ??
        (transactionId != null && transactionId != this.transactionId
            ? ''
            : this.signedTransaction),
    replacedPurchaseTokenFingerprint: replacedPurchaseTokenFingerprint,
    state: state ?? this.state,
    reportStatus: newReport || retryReport
        ? null
        : reportStatus ?? this.reportStatus,
    reportReason: newReport || retryReport
        ? null
        : reportStatus != null
        ? reportReason
        : reportReason ?? this.reportReason,
    finished: newReport ? false : finished ?? this.finished,
    tracking: tracking ?? (newReport ? null : this.tracking),
    priceAmountMicros: clearPrice
        ? null
        : priceAmountMicros ?? this.priceAmountMicros,
    priceCurrencyCode: clearPrice
        ? ''
        : priceCurrencyCode ?? this.priceCurrencyCode,
  );

  /// Keep store receipt identity for restore after removing the guest identity.
  MembershipPurchaseRecord bindGuestToAccount(String uid) =>
      MembershipPurchaseRecord(
        requestId: requestId,
        product: product,
        accountUuid: accountUuid,
        ownerUid: uid,
        transactionId: transactionId,
        originalTransactionId: originalTransactionId,
        purchaseToken: purchaseToken,
        replacedPurchaseTokenFingerprint: replacedPurchaseTokenFingerprint,
        state: state,
        reportStatus: reportStatus,
        reportReason: reportReason,
        finished: finished,
        tracking: tracking,
        priceAmountMicros: priceAmountMicros,
        priceCurrencyCode: priceCurrencyCode,
      );

  Map<String, Object?> toJson() => {
    'request_id': requestId,
    'product': product.toOrderJson(),
    'account_uuid': accountUuid,
    'owner_uid': ownerUid,
    'guest': guest?.toJson(),
    'transaction_id': transactionId,
    'original_transaction_id': originalTransactionId,
    'purchase_token': purchaseToken,
    if (guest != null &&
        product.provider == MembershipProvider.apple &&
        signedTransaction.isNotEmpty)
      'signed_transaction': signedTransaction,
    if (replacedPurchaseTokenFingerprint.isNotEmpty)
      'replaced_purchase_token_fingerprint': replacedPurchaseTokenFingerprint,
    'state': state,
    'report_status': reportStatus,
    if (reportReason != null) 'report_reason': reportReason,
    'finished': finished,
    if (tracking != null) 'subscription_tracking': tracking!.toJson(),
    if (priceAmountMicros != null) 'price_amount_micros': priceAmountMicros,
    if (priceCurrencyCode.isNotEmpty) 'price_currency_code': priceCurrencyCode,
  };

  factory MembershipPurchaseRecord.fromJson(Map<String, dynamic> json) =>
      MembershipPurchaseRecord(
        requestId: json['request_id'] as String,
        tracking: SubscriptionTracking.fromJson(json['subscription_tracking']),
        product: MembershipOrderProduct.fromJson(
          Map<String, dynamic>.from(json['product'] as Map),
        ),
        accountUuid: (json['account_uuid'] as String).toLowerCase(),
        ownerUid: json['owner_uid'] as String?,
        guest: json['guest'] == null
            ? null
            : MembershipGuestIdentity.fromJson(
                Map<String, dynamic>.from(json['guest'] as Map),
              ),
        transactionId: json['transaction_id'] as String,
        originalTransactionId: json['original_transaction_id'] as String,
        purchaseToken: json['purchase_token'] as String,
        signedTransaction: json['signed_transaction'] as String? ?? '',
        replacedPurchaseTokenFingerprint:
            json['replaced_purchase_token_fingerprint'] as String? ?? '',
        state: json['state'] as String,
        reportStatus: json['report_status'] as String?,
        reportReason: json['report_reason'] as String?,
        priceAmountMicros: json['price_amount_micros'] as int?,
        priceCurrencyCode: json['price_currency_code'] as String? ?? '',
        // Older clients marked an ownership rejection as finished without
        // calling StoreKit. Never treat that legacy flag as store completion.
        finished: json['report_status'] == 'rejected'
            ? false
            : json['finished'] as bool,
      );
}

abstract interface class MembershipPendingStore {
  Future<List<MembershipPurchaseRecord>> loadAll();
  Future<void> save(MembershipPurchaseRecord record);
  Future<List<MembershipPurchaseRecord>> loadConfirmedReceipts();
  Future<void> complete(MembershipPurchaseRecord record);
  Future<void> saveGuestPurchase(MembershipPurchaseRecord record);
  Future<List<MembershipRestoreRecord>> loadRestores();
  Future<void> saveRestore(MembershipRestoreRecord record);
  Future<void> removeRestore(String requestId);
  Future<List<MembershipGuestClaimRecord>> loadGuestClaims();
  Future<void> saveGuestClaim(MembershipGuestClaimRecord record);
  Future<void> completeGuestClaim(MembershipGuestClaimRecord record);
  Future<bool> removeUnpurchasedGuestIdentity(String accountUuid);
}

/// Kept separate from the Gems queue, including guest identity after reporting.
class SecureMembershipPendingStore implements MembershipPendingStore {
  SecureMembershipPendingStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            aOptions: AndroidOptions(resetOnError: false),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'membership_purchase_records_v1';
  static const _restoreKey = 'membership_restore_records_v1';
  static const _confirmedKey = 'membership_confirmed_receipts_v1';
  static const _guestClaimsKey = 'membership_guest_claims_v1';
  Future<void> _writes = Future.value();
  Future<void>? _migration;

  Future<void> _migrateGuestIdentity() {
    if (_migration != null) return _migration!;
    final operation = _writes.then((_) async {
      for (final key in [_key, _confirmedKey, _guestClaimsKey]) {
        final raw = await _storage.read(key: key);
        if (raw == null) continue;
        final rows = (jsonDecode(raw) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        final legacy = rows.any((row) {
          final guest = row['guest'];
          return guest is Map &&
              (guest.containsKey('guest_id') ||
                  guest.containsKey('claim_token'));
        });
        if (!legacy) continue;
        // Rewrite in place only after every row parses. Preserve receipts,
        // account ownership, report status and request IDs across upgrades.
        final migrated = rows
            .map(
              (row) => key == _guestClaimsKey
                  ? MembershipGuestClaimRecord.fromJson(row).toJson()
                  : MembershipPurchaseRecord.fromJson(row).toJson(),
            )
            .toList();
        await _storage.write(key: key, value: jsonEncode(migrated));
      }
    });
    _writes = operation.catchError((Object _) {});
    return _migration = operation.catchError((Object error) {
      _migration = null;
      throw error;
    });
  }

  @override
  Future<List<MembershipPurchaseRecord>> loadAll() async {
    await _migrateGuestIdentity();
    await _writes;
    return _read();
  }

  Future<List<MembershipPurchaseRecord>> _read([String key = _key]) async {
    final raw = await _storage.read(key: key);
    if (raw == null) return [];
    final rows = jsonDecode(raw) as List;
    return rows
        .map(
          (row) => MembershipPurchaseRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<MembershipPurchaseRecord>> loadConfirmedReceipts() async {
    await _migrateGuestIdentity();
    await _writes;
    return _read(_confirmedKey);
  }

  @override
  Future<void> saveGuestPurchase(MembershipPurchaseRecord record) {
    final operation = _writes.then((_) => _saveGuestPurchase(record));
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _saveGuestPurchase(MembershipPurchaseRecord record) async {
    final receipts = await _read(_confirmedKey);
    receipts.removeWhere(
      (r) => r.requestId == record.requestId || r.guest == null,
    );
    if (record.guest != null &&
        record.paid &&
        record.hasReceipt &&
        record.reportStatus != 'rejected') {
      receipts.add(record);
    }
    if (receipts.isEmpty) {
      await _storage.delete(key: _confirmedKey);
    } else {
      await _storage.write(
        key: _confirmedKey,
        value: jsonEncode(receipts.map((r) => r.toJson()).toList()),
      );
    }
  }

  @override
  Future<void> complete(MembershipPurchaseRecord record) {
    final operation = _writes.then((_) async {
      // Only an unbound guest needs proof after report succeeds. Ordinary
      // successful purchases have no durable local order history.
      await _saveGuestPurchase(record);
      await _removePurchase(record.requestId);
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _removePurchase(String requestId) async {
    final records = await _read();
    records.removeWhere((r) => r.requestId == requestId);
    await _storage.write(
      key: _key,
      value: jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  @override
  Future<void> save(MembershipPurchaseRecord record) {
    final operation = _writes.then((_) async {
      final records = await _read();
      final index = records.indexWhere(
        (item) => item.requestId == record.requestId,
      );
      if (index < 0) {
        records.add(record);
      } else {
        records[index] = record;
      }
      await _storage.write(
        key: _key,
        value: jsonEncode(records.map((item) => item.toJson()).toList()),
      );
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<List<MembershipRestoreRecord>> loadRestores() async {
    await _writes;
    return _readRestores();
  }

  Future<List<MembershipRestoreRecord>> _readRestores() async {
    final raw = await _storage.read(key: _restoreKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (row) => MembershipRestoreRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveRestore(MembershipRestoreRecord record) {
    final operation = _writes.then((_) async {
      final records = await _readRestores();
      final index = records.indexWhere((r) => r.requestId == record.requestId);
      if (index < 0) {
        records.add(record);
      } else {
        records[index] = record;
      }
      await _storage.write(
        key: _restoreKey,
        value: jsonEncode(records.map((r) => r.toJson()).toList()),
      );
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> removeRestore(String requestId) {
    final operation = _writes.then((_) async {
      final records = await _readRestores();
      records.removeWhere((r) => r.requestId == requestId);
      await _storage.write(
        key: _restoreKey,
        value: jsonEncode(records.map((r) => r.toJson()).toList()),
      );
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<List<MembershipGuestClaimRecord>> _readGuestClaims() async {
    final raw = await _storage.read(key: _guestClaimsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map(
          (row) => MembershipGuestClaimRecord.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  @override
  Future<List<MembershipGuestClaimRecord>> loadGuestClaims() async {
    await _migrateGuestIdentity();
    await _writes;
    return _readGuestClaims();
  }

  @override
  Future<void> saveGuestClaim(MembershipGuestClaimRecord record) {
    final operation = _writes.then((_) async {
      final records = await _readGuestClaims();
      records.removeWhere(
        (r) => r.guest.accountUuid == record.guest.accountUuid,
      );
      records.add(record);
      await _storage.write(
        key: _guestClaimsKey,
        value: jsonEncode(records.map((r) => r.toJson()).toList()),
      );
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<bool> removeUnpurchasedGuestIdentity(String accountUuid) {
    final operation = _writes.then((_) async {
      final claims = await _readGuestClaims();
      if (claims.any(
        (claim) =>
            claim.guest.accountUuid == accountUuid &&
            (claim.hasPurchase ||
                claim.ownerUid != null ||
                claim.status != null),
      )) {
        return false;
      }
      final purchases = [...await _read(), ...await _read(_confirmedKey)];
      if (purchases.any(
        (purchase) =>
            purchase.guest?.accountUuid == accountUuid &&
            (purchase.hasReceipt ||
                purchase.paid ||
                purchase.state == 'pending'),
      )) {
        return false;
      }
      claims.removeWhere((claim) => claim.guest.accountUuid == accountUuid);
      if (claims.isEmpty) {
        await _storage.delete(key: _guestClaimsKey);
      } else {
        await _storage.write(
          key: _guestClaimsKey,
          value: jsonEncode(claims.map((claim) => claim.toJson()).toList()),
        );
      }
      return true;
    });
    _writes = operation.then<void>((_) {}, onError: (Object _) {});
    return operation;
  }

  @override
  Future<void> completeGuestClaim(MembershipGuestClaimRecord record) {
    final operation = _writes.then((_) async {
      final uid = record.ownerUid;
      if (record.status != 'completed' || uid == null || uid.isEmpty) {
        throw StateError('Guest claim is not completed');
      }
      final claims = await _readGuestClaims();
      final saved = claims.where(
        (r) => r.guest.accountUuid == record.guest.accountUuid,
      );
      if (saved.isEmpty) return;
      if (saved.single.status != 'completed' || saved.single.ownerUid != uid) {
        throw StateError('Guest claim completion must be durable');
      }
      final pending = await _read();
      bool belongsToClaim(MembershipPurchaseRecord purchase) =>
          purchase.guest?.accountUuid == record.guest.accountUuid;
      if (pending.any(
        (purchase) =>
            belongsToClaim(purchase) &&
            purchase.hasReceipt &&
            purchase.reportStatus != 'completed' &&
            purchase.reportStatus != 'rejected',
      )) {
        throw StateError('Guest report cleanup is not completed');
      }
      final before = pending.length;
      pending.removeWhere(belongsToClaim);
      if (pending.length != before) {
        await _storage.write(
          key: _key,
          value: jsonEncode(pending.map((r) => r.toJson()).toList()),
        );
      }
      final receipts = await _read(_confirmedKey);
      receipts.removeWhere(
        (r) => r.guest?.accountUuid == record.guest.accountUuid,
      );
      if (receipts.isEmpty) {
        await _storage.delete(key: _confirmedKey);
      } else {
        await _storage.write(
          key: _confirmedKey,
          value: jsonEncode(receipts.map((r) => r.toJson()).toList()),
        );
      }
      // Claim is durable and report/StoreKit cleanup has settled. Remove the
      // identity too; later logged-out recovery queries the store and backend.
      claims.removeWhere(
        (r) => r.guest.accountUuid == record.guest.accountUuid,
      );
      if (claims.isEmpty) {
        await _storage.delete(key: _guestClaimsKey);
      } else {
        await _storage.write(
          key: _guestClaimsKey,
          value: jsonEncode(claims.map((r) => r.toJson()).toList()),
        );
      }
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }
}
