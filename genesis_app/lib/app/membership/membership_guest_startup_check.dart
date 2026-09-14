part of 'membership_purchase_service.dart';

int? _purchaseTimeMillis(String value) =>
    int.tryParse(value) ?? DateTime.tryParse(value)?.millisecondsSinceEpoch;

String _guestStoreEventKey(BillingPurchase purchase) =>
    '${purchase.provider.name}:${purchase.productId}:'
    '${purchase.purchaseToken}:${purchase.transactionId}';

extension _MembershipGuestStartupCheck on MembershipPurchaseService {
  void _traceGuestRecovery(String message) =>
      debugPrint('[Membership][guest_recovery] $message');

  void _invalidateGuestStartupCheck() {
    _guestStartupRevision++;
    _guestStartupResolved = false;
    _guestStartupCheckedAt = null;
    _guestStartupRefreshNeeded = _guestHomeCheck != null;
    _guestStartupRetry?.cancel();
    _guestStartupRetry = null;
    _guestStartupRetryCount = 0;
  }

  void _scheduleGuestStartupRetry() {
    if (_disposed || _guestStartupRetry != null) return;
    if (_guestStartupRetryCount >= 3) {
      _traceGuestRecovery(
        'retry_limit; waiting_for_purchase_or_session_change',
      );
      return;
    }
    final session = _session;
    final delay = retryDelay * (1 << _guestStartupRetryCount++);
    _traceGuestRecovery('retry_scheduled; attempt=$_guestStartupRetryCount');
    _guestStartupRetry = Timer(delay, () {
      _guestStartupRetry = null;
      if (!_disposed && session == _session) {
        unawaited(_checkGuestPurchasesOnHome(retrying: true));
      }
    });
  }

  // Recover missing metadata only from an exact saved receipt, never a SKU guess.
  String? _savedGuestUuid(BillingPurchase purchase) {
    final matches = <String>{};
    for (final record in _records.values) {
      if (record.guest != null &&
          record.product.provider == provider &&
          record.product.storeProductId == purchase.productId &&
          (provider == MembershipProvider.google
              ? purchase.purchaseToken.isNotEmpty &&
                    purchase.purchaseToken == record.purchaseToken
              : purchase.transactionId.isNotEmpty &&
                    purchase.transactionId == record.transactionId)) {
        matches.add(record.guest!.accountUuid);
      }
    }
    for (final claim in _guestClaims.values) {
      final proof = claim.recoveredProof;
      if (proof != null &&
          proof.provider == provider &&
          proof.storeProductId == purchase.productId &&
          (provider == MembershipProvider.google
              ? purchase.purchaseToken.isNotEmpty &&
                    purchase.purchaseToken == proof.purchaseToken
              : purchase.transactionId.isNotEmpty &&
                    purchase.transactionId == proof.transactionId)) {
        matches.add(claim.guest.accountUuid);
      }
    }
    return matches.length == 1 ? matches.single : null;
  }

  MembershipGuestClaimRecord? _latestCachedGuestPurchase() {
    final candidates = Map<String, MembershipGuestClaimRecord>.of(_guestClaims);
    // A receipt may have been persisted before its claim write succeeded.
    for (final record in _records.values) {
      if (record.guest == null ||
          record.product.provider != provider ||
          !record.paid ||
          !record.hasReceipt ||
          record.reportStatus == 'rejected') {
        continue;
      }
      final uuid = record.guest!.accountUuid;
      final existing = candidates[uuid];
      if (existing?.hasPurchase != true) {
        candidates[uuid] =
            (existing ?? MembershipGuestClaimRecord(guest: record.guest!))
                .copyWith(
                  purchaseRequestId: record.requestId,
                  purchaseConfirmed: record.reportStatus == 'completed',
                );
      }
    }
    MembershipGuestClaimRecord? selected;
    for (final claim in candidates.values) {
      if (!claim.hasPurchase ||
          claim.status == 'completed' ||
          claim.recoveredProof != null &&
              claim.recoveredProof!.provider != provider) {
        continue;
      }
      // Legacy rows have no timestamp; preserve their durable insertion order.
      if (selected == null ||
          (claim.purchasedAt ?? 0) >= (selected.purchasedAt ?? 0)) {
        selected = claim;
      }
    }
    return selected;
  }

  MembershipStorePurchase? _latestStoreGuestPurchase(
    List<MembershipStorePurchase> purchases,
  ) {
    final candidates = <String, MembershipStorePurchase>{};
    for (final candidate in purchases) {
      final purchase = candidate.purchase;
      if (purchase.provider.apiValue != provider.name ||
          !candidate.isCurrent(DateTime.now()) ||
          (purchase.status != BillingPurchaseStatus.purchased &&
              purchase.status != BillingPurchaseStatus.restored)) {
        continue;
      }
      candidates[_guestStoreEventKey(purchase)] = candidate;
    }
    final ordered = candidates.values.toList()
      ..sort(
        (a, b) => (_purchaseTimeMillis(b.purchase.purchaseTime) ?? 0).compareTo(
          _purchaseTimeMillis(a.purchase.purchaseTime) ?? 0,
        ),
      );
    if (ordered.length > 1 &&
        _purchaseTimeMillis(ordered[0].purchase.purchaseTime) ==
            _purchaseTimeMillis(ordered[1].purchase.purchaseTime)) {
      throw StateError('Latest guest subscription is ambiguous');
    }
    return ordered.isEmpty ? null : ordered.first;
  }

  Future<void> _checkGuestPurchasesOnHome({bool retrying = false}) {
    _guestHomeSeen = true;
    if (_disposed || checkGuestPurchase == null) return Future.value();
    final running = _guestHomeCheck;
    if (running != null) return running;
    // Home rebuilds and lifecycle callbacks must not bypass a scheduled backoff.
    if (!retrying &&
        (_guestStartupRetry != null || _guestStartupRetryCount >= 3)) {
      _traceGuestRecovery('skip=retry_backoff');
      return Future.value();
    }
    final session = _session;
    var needsRetry = false;
    late final Future<void> task;
    task =
        (() async {
          try {
            if (!await _guestStartupIsCurrent(session)) return;
            await _load();
            if (!await _guestStartupIsCurrent(session) ||
                _busy ||
                _presentedAttempts.isNotEmpty) {
              return;
            }
            final checkedAt = _guestStartupCheckedAt;
            if (_guestStartupResolved &&
                checkedAt != null &&
                DateTime.now().difference(checkedAt) <
                    const Duration(seconds: 30)) {
              _traceGuestRecovery('skip=recent_check');
              return;
            }
            _guestStartupRefreshNeeded = false;
            final revision = _guestStartupRevision;
            final cached = _latestCachedGuestPurchase();
            BillingPurchase? discovered;
            String? uuid = cached?.guest.accountUuid;
            _traceGuestRecovery(
              'start; source=${cached == null ? 'store' : 'paid_cache'}',
            );
            if (cached == null && discoverGuestPurchases != null) {
              final purchases = await discoverGuestPurchases!().timeout(
                guestRecoveryTimeout,
              );
              if (!await _guestStartupIsCurrent(session) ||
                  _busy ||
                  _presentedAttempts.isNotEmpty) {
                return;
              }
              // A paid callback received during discovery takes precedence over history.
              if (revision != _guestStartupRevision) return;
              final selected = _latestStoreGuestPurchase(purchases);
              // History callbacks for this same snapshot do not represent a new payment.
              for (final candidate in purchases) {
                final purchase = candidate.purchase;
                if (purchase.provider.apiValue == provider.name &&
                    (purchase.status == BillingPurchaseStatus.purchased ||
                        purchase.status == BillingPurchaseStatus.restored)) {
                  _guestStoreEvents.add(_guestStoreEventKey(purchase));
                }
              }
              _traceGuestRecovery(
                'store_candidate_count=${purchases.length}; selected=${selected == null ? 0 : 1}',
              );
              if (selected != null) {
                discovered = selected.purchase;
                uuid = discovered.obfuscatedAccountId?.trim().toLowerCase();
                if (uuid == null || !isMembershipAccountUuid(uuid)) {
                  uuid = _savedGuestUuid(discovered);
                }
                if (uuid == null || !isMembershipAccountUuid(uuid)) {
                  throw StateError('Latest guest subscription UUID is missing');
                }
                final credential = provider == MembershipProvider.google
                    ? discovered.purchaseToken
                    : discovered.transactionId;
                if (credential.isEmpty || discovered.productId.isEmpty) {
                  throw StateError(
                    'Latest guest subscription receipt is missing',
                  );
                }
              }
            }
            if (uuid != null) {
              final result = await checkGuestPurchase!(
                uuid,
              ).timeout(guestRecoveryTimeout);
              if (!await _guestStartupIsCurrent(session) ||
                  _busy ||
                  _presentedAttempts.isNotEmpty ||
                  revision != _guestStartupRevision) {
                return;
              }
              _traceGuestRecovery(
                'check; has_unbound_order=${result.hasUnboundOrder}',
              );
              // These are disposable check snapshots, never purchase credentials.
              _guestOrderChecks.removeWhere((key, _) => key != uuid);
              _guestOrderChecks[uuid] = result;
              await _serialize(() async {
                if (!await _guestStartupIsCurrent(session) ||
                    revision != _guestStartupRevision) {
                  return;
                }
                for (final other in _guestClaims.values.toList()) {
                  if (other.guest.accountUuid != uuid &&
                      other.ownerUid == null &&
                      other.status != 'completed' &&
                      other.autoClaimAllowed) {
                    await _saveGuestClaim(
                      other.copyWith(autoClaimAllowed: false),
                    );
                  }
                }
                var claim = _guestClaims[uuid];
                if (claim?.hasPurchase != true && cached != null) {
                  claim = cached;
                }
                if (result.hasUnboundOrder &&
                    discovered != null &&
                    claim?.status != 'completed' &&
                    claim?.recoveredProof == null &&
                    (claim == null || _claimPurchase(claim) == null)) {
                  final purchase = discovered;
                  if (provider == MembershipProvider.apple &&
                      purchase.signedTransaction.isNotEmpty) {
                    _signedTransactions['$uuid:${purchase.transactionId}'] =
                        purchase.signedTransaction;
                  }
                  claim =
                      (claim ??
                              MembershipGuestClaimRecord(
                                guest: MembershipGuestIdentity(
                                  accountUuid: uuid!,
                                ),
                              ))
                          .copyWith(
                            loginRequired: true,
                            purchasedAt:
                                _purchaseTimeMillis(purchase.purchaseTime) ??
                                DateTime.now().millisecondsSinceEpoch,
                            recoveredProof: MembershipGuestClaimProof(
                              provider: provider,
                              storeProductId: purchase.productId,
                              requestId: newBillingAttemptId(),
                              purchaseToken: purchase.purchaseToken,
                              transactionId: purchase.transactionId,
                            ),
                          );
                }
                if (claim != null &&
                    claim.status != 'completed' &&
                    claim.ownerUid == null) {
                  await _saveGuestClaim(
                    claim.copyWith(autoClaimAllowed: result.hasUnboundOrder),
                  );
                }
              });
            }
            if (!await _guestStartupIsCurrent(session)) return;
            // false is a successful ownership snapshot, not a synchronization error.
            _guestStartupResolved = revision == _guestStartupRevision;
            _guestStartupCheckedAt = _guestStartupResolved
                ? DateTime.now()
                : null;
            if (_guestStartupResolved) _guestStartupRetryCount = 0;
            _traceGuestRecovery(
              'done; uuid_count=${uuid == null ? 0 : 1}; resolved=$_guestStartupResolved',
            );
            await _refreshGuestLoginRequest();
          } catch (error) {
            needsRetry = true;
            _log('guest startup check deferred', error);
          }
        })().whenComplete(() {
          if (!identical(_guestHomeCheck, task)) return;
          _guestHomeCheck = null;
          if (_disposed || session != _session) return;
          if (_guestStartupRefreshNeeded) {
            _guestStartupRefreshNeeded = false;
            unawaited(checkGuestPurchasesOnHome());
          } else if (needsRetry) {
            _scheduleGuestStartupRetry();
          }
        });
    _guestHomeCheck = task;
    return task;
  }

  Future<bool> _guestStartupIsCurrent(int session) async =>
      !_disposed && session == _session && await readLoginUid() == null;
}
