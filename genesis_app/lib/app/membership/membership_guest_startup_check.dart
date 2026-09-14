part of 'membership_purchase_service.dart';

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
      _traceGuestRecovery('retry_limit; waiting_for_next_entry');
      return;
    }
    final session = _session;
    final delay = retryDelay * (1 << _guestStartupRetryCount++);
    _traceGuestRecovery('retry_scheduled; attempt=$_guestStartupRetryCount');
    _guestStartupRetry = Timer(delay, () {
      _guestStartupRetry = null;
      if (!_disposed && session == _session) {
        unawaited(checkGuestPurchasesOnHome());
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

  Future<void> _checkGuestPurchasesOnHome() {
    _guestHomeSeen = true;
    if (_disposed || checkGuestPurchase == null) return Future.value();
    final running = _guestHomeCheck;
    if (running != null) return running;
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
            _guestStartupRetry?.cancel();
            _guestStartupRetry = null;
            _guestStartupRefreshNeeded = false;
            final revision = _guestStartupRevision;
            final uuids = {
              ..._guestClaims.keys,
              for (final record in _records.values)
                if (record.guest != null && record.hasReceipt)
                  record.guest!.accountUuid,
            };
            final discovered = <String, Map<String, BillingPurchase>>{};
            var allChecked = true;
            _traceGuestRecovery('start; cached_uuid_count=${uuids.length}');
            // Merge both sources. Store failures must not block cached identity checks.
            if (discoverGuestPurchases != null) {
              try {
                final purchases = await discoverGuestPurchases!().timeout(
                  guestRecoveryTimeout,
                );
                if (!await _guestStartupIsCurrent(session) ||
                    _busy ||
                    _presentedAttempts.isNotEmpty) {
                  return;
                }
                _traceGuestRecovery(
                  'store_candidate_count=${purchases.length}',
                );
                final storeProvider = provider == MembershipProvider.google
                    ? BillingProvider.googlePlay
                    : BillingProvider.appStore;
                for (final candidate in purchases) {
                  final purchase = candidate.purchase;
                  if (purchase.provider != storeProvider ||
                      !candidate.isCurrent(DateTime.now())) {
                    continue;
                  }
                  if (purchase.status == BillingPurchaseStatus.pending) {
                    allChecked = false;
                    _traceGuestRecovery('deferred=pending_payment');
                    continue;
                  }
                  if (purchase.status != BillingPurchaseStatus.purchased &&
                      purchase.status != BillingPurchaseStatus.restored) {
                    continue;
                  }
                  var uuid = purchase.obfuscatedAccountId?.trim() ?? '';
                  if (!isMembershipAccountUuid(uuid)) {
                    uuid = _savedGuestUuid(purchase) ?? '';
                  }
                  if (!isMembershipAccountUuid(uuid)) {
                    allChecked = false;
                    _traceGuestRecovery('deferred=store_account_uuid_missing');
                    continue;
                  }
                  final accountUuid = uuid.toLowerCase();
                  uuids.add(accountUuid);
                  final credential = provider == MembershipProvider.google
                      ? purchase.purchaseToken
                      : purchase.transactionId;
                  if (credential.isNotEmpty && purchase.productId.isNotEmpty) {
                    discovered.putIfAbsent(
                      accountUuid,
                      () => {},
                    )['${purchase.productId}:$credential'] = purchase;
                  } else {
                    allChecked = false;
                    _traceGuestRecovery('deferred=store_receipt_missing');
                  }
                }
              } catch (error) {
                allChecked = false;
                _log('guest store discovery deferred', error);
              }
            }
            for (final uuid in uuids) {
              if (!await _guestStartupIsCurrent(session)) return;
              try {
                final result = await checkGuestPurchase!(
                  uuid,
                ).timeout(guestRecoveryTimeout);
                if (!await _guestStartupIsCurrent(session) ||
                    _busy ||
                    _presentedAttempts.isNotEmpty) {
                  return;
                }
                _traceGuestRecovery(
                  'check; has_unbound_order=${result.hasUnboundOrder}',
                );
                _guestOrderChecks[uuid] = result;
                final existing = _guestClaims[uuid];
                if (result.hasUnboundOrder &&
                    (existing == null ||
                        existing.status != 'completed' &&
                            existing.recoveredProof == null &&
                            _claimPurchase(existing) == null)) {
                  final candidates = discovered[uuid]?.values.toList() ?? [];
                  // Never select an arbitrary independent subscription chain.
                  if (candidates.length == 1) {
                    final purchase = candidates.single;
                    await _serialize(() async {
                      if (!await _guestStartupIsCurrent(session)) return;
                      final current = _guestClaims[uuid];
                      if (current != null &&
                          (current.status == 'completed' ||
                              current.recoveredProof != null ||
                              _claimPurchase(current) != null)) {
                        return;
                      }
                      final proof = MembershipGuestClaimProof(
                        provider: provider,
                        storeProductId: purchase.productId,
                        requestId: newBillingAttemptId(),
                        purchaseToken: purchase.purchaseToken,
                        transactionId: purchase.transactionId,
                      );
                      if (provider == MembershipProvider.apple &&
                          purchase.signedTransaction.isNotEmpty) {
                        _signedTransactions['$uuid:${purchase.transactionId}'] =
                            purchase.signedTransaction;
                      }
                      await _saveGuestClaim(
                        (current ??
                                MembershipGuestClaimRecord(
                                  guest: MembershipGuestIdentity(
                                    accountUuid: uuid,
                                  ),
                                ))
                            .copyWith(
                              loginRequired: true,
                              recoveredProof: proof,
                              autoClaimAllowed: true,
                            ),
                      );
                    });
                  }
                }
                final claim = _guestClaims[uuid];
                if (claim != null &&
                    claim.status != 'completed' &&
                    claim.ownerUid == null) {
                  await _serialize(() async {
                    if (!await _guestStartupIsCurrent(session)) return;
                    final current = _guestClaims[uuid];
                    if (current == null ||
                        current.ownerUid != null ||
                        current.status == 'completed') {
                      return;
                    }
                    await _saveGuestClaim(
                      current.copyWith(
                        autoClaimAllowed: result.hasUnboundOrder,
                      ),
                    );
                  });
                }
                // Store payment can precede backend notification/report. Retry false
                // briefly without granting entitlement or claiming on a false result.
                if (!result.hasUnboundOrder &&
                    discovered[uuid]?.isNotEmpty == true &&
                    claim?.status != 'completed') {
                  allChecked = false;
                }
              } catch (error) {
                allChecked = false;
                _log('guest purchase check deferred', error);
              }
            }
            if (!await _guestStartupIsCurrent(session)) return;
            _guestStartupResolved =
                allChecked && revision == _guestStartupRevision;
            _guestStartupCheckedAt = _guestStartupResolved
                ? DateTime.now()
                : null;
            needsRetry = !allChecked;
            if (_guestStartupResolved) _guestStartupRetryCount = 0;
            _traceGuestRecovery(
              'done; uuid_count=${uuids.length}; resolved=$_guestStartupResolved',
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
