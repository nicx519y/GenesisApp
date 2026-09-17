part of 'membership_purchase_service.dart';

class _MembershipClaimRetry {
  int attempts = 0;
  int proofAttempts = 0;
  Timer? timer;

  // One initial request and at most five additional attempts in this session.
  bool get canAttempt => timer == null && attempts < 6;
}

extension _MembershipGuestClaim on MembershipPurchaseService {
  Future<void> _discardUnpurchasedGuestIdentity(String uuid) async {
    final claim = _guestClaims[uuid];
    if (claim == null ||
        claim.hasPurchase ||
        claim.ownerUid != null ||
        claim.status != null ||
        _records.values.any(
          (record) =>
              record.guest?.accountUuid == uuid &&
              (record.hasReceipt || record.paid || record.state != 'canceled'),
        )) {
      _unpaidGuestCleanup.remove(uuid);
      return;
    }
    _unpaidGuestCleanup.add(uuid);
    try {
      if (await store.removeUnpurchasedGuestIdentity(uuid) &&
          identical(_guestClaims[uuid], claim)) {
        _guestClaims.remove(uuid);
        _pendingGuestClaimWrites.remove(uuid);
        _guestOrderChecks.remove(uuid);
      }
      _unpaidGuestCleanup.remove(uuid);
    } catch (error) {
      _scheduleGuestMaintenance();
      _log('canceled guest identity cleanup deferred', error);
    }
  }

  Future<MembershipPurchaseRequest> _guestPurchaseRequest(
    MembershipPurchaseRecord purchase,
  ) async {
    final reported = _guestPurchaseRequests[purchase.requestId];
    if (reported != null) return reported;
    var request = purchase.request;
    if (request.guest == null) return request;
    if (provider == MembershipProvider.apple) {
      final signed = await _signedGuestRequest(
        MembershipClaimRequest.fromPurchase(request),
      );
      request = request.withSignedTransaction(signed.signedTransaction);
      if (!_disposed &&
          purchase.paid &&
          purchase.signedTransaction != request.signedTransaction) {
        final complete = purchase.copyWith(
          signedTransaction: request.signedTransaction,
        );
        await _save(complete);
        try {
          await store.saveGuestPurchase(complete);
        } catch (error) {
          _log('guest signed proof persistence deferred', error);
        }
      }
    }
    if (!_disposed) _guestPurchaseRequests[purchase.requestId] = request;
    return request;
  }

  Future<MembershipClaimRequest> _signedGuestRequest(
    MembershipClaimRequest request,
  ) async {
    if (request.provider != MembershipProvider.apple ||
        request.signedTransaction.isNotEmpty) {
      return request;
    }
    final key = '${request.guest.accountUuid}:${request.transactionId}';
    var signed = _signedTransactions[key];
    if (signed == null || signed.isEmpty) {
      signed = await loadSignedTransaction?.call(request);
      if (signed == null || signed.isEmpty) {
        throw const BillingPlatformException(
          'membership_signed_transaction_missing',
        );
      }
      if (!_disposed) _signedTransactions[key] = signed;
    }
    return request.withSignedTransaction(signed);
  }

  Future<MembershipClaimRequest> _recoveredGuestClaimRequest(
    MembershipGuestClaimRecord claim,
  ) async {
    final proof = claim.recoveredProof!;
    if (proof.provider != provider) {
      throw const BillingPlatformException(
        'membership_claim_provider_mismatch',
      );
    }
    return _signedGuestRequest(
      MembershipClaimRequest(
        provider: provider,
        storeProductId: proof.storeProductId,
        guest: claim.guest,
        purchaseToken: proof.purchaseToken,
        transactionId: proof.transactionId,
        signedTransaction: proof.signedTransaction,
      ),
    );
  }

  MembershipPurchaseRecord? _claimPurchase(MembershipGuestClaimRecord claim) {
    bool matches(MembershipPurchaseRecord p) =>
        p.product.provider == provider &&
        p.guest?.accountUuid == claim.guest.accountUuid &&
        p.paid &&
        p.hasReceipt;
    final saved = _records[claim.purchaseRequestId];
    if (claim.purchaseRequestId != null) {
      return saved != null && matches(saved) ? saved : null;
    }
    // Legacy claims may not yet have an associated request ID. Recover the
    // original persisted receipt, never invent a new idempotency key.
    for (final purchase in _records.values.toList().reversed) {
      if (matches(purchase)) return purchase;
    }
    return null;
  }

  Future<void> _repairLegacyGuestClaimReferences() async {
    // Earlier clients appended each paid receipt but left the unclaimed UUID
    // pointing at its first report. The secure receipt list preserves write
    // order. Repair only those unsigned, unowned completed-report records;
    // once claim has an owner or response, its proof must remain fixed.
    for (final claim in _guestClaims.values.toList()) {
      if (claim.ownerUid != null ||
          claim.status != null ||
          !claim.purchaseConfirmed ||
          claim.recoveredProof != null) {
        continue;
      }
      final selected = _claimPurchase(claim);
      if (selected == null ||
          selected.signedTransaction.isNotEmpty ||
          selected.reportStatus != 'completed') {
        continue;
      }
      final candidates = _records.values.where(
        (purchase) =>
            purchase.product.provider == provider &&
            purchase.guest?.accountUuid == claim.guest.accountUuid &&
            purchase.paid &&
            purchase.hasReceipt &&
            purchase.reportStatus == 'completed',
      );
      final latest = candidates.last;
      if (latest.requestId == selected.requestId) continue;
      await _saveGuestClaim(
        claim.copyWith(
          purchaseRequestId: latest.requestId,
          tracking: _trackingFor(latest),
        ),
      );
    }
  }

  void _resetGuestClaimRetries() {
    for (final retry in _claimRetries.values) {
      retry.timer?.cancel();
    }
    _claimRetries.clear();
    _claimWalletRefreshSessions.clear();
  }

  void _scheduleGuestClaimRetry(
    String accountUuid,
    _MembershipClaimRetry retry,
  ) {
    if (_disposed ||
        !identical(_claimRetries[accountUuid], retry) ||
        retry.timer != null ||
        retry.attempts >= 6) {
      return;
    }
    final session = _session;
    final delay = Duration(
      milliseconds: retryDelay.inMilliseconds * (1 << (retry.attempts - 1)),
    );
    retry.timer = Timer(delay, () {
      retry.timer = null;
      if (_disposed || session != _session) return;
      if (_recovery != null) _recoverAgain = true;
      unawaited(recover());
    });
  }

  Future<void> _saveGuestClaim(MembershipGuestClaimRecord record) async {
    // Keep an in-flight login's ownership even if persistence must be retried.
    _guestClaims[record.guest.accountUuid] = record;
    _pendingGuestClaimWrites.add(record.guest.accountUuid);
    await store.saveGuestClaim(record);
    _pendingGuestClaimWrites.remove(record.guest.accountUuid);
  }

  Future<void> _prepareGuestClaim(
    MembershipPurchaseRecord purchase, {
    String? purchaseTime,
    bool fromStoreCallback = false,
  }) async {
    final guest = purchase.guest;
    if (_disposed || guest == null || !purchase.paid || !purchase.hasReceipt) {
      return;
    }
    if (purchase.reportStatus == 'rejected') {
      // Drop the provisional guest proof just as terminal cleanup did before;
      // it must not become an unconfirmed purchase again after restart.
      await store.saveGuestPurchase(purchase);
      return;
    }
    var previous = _guestClaims[guest.accountUuid];
    if (previous != null &&
        previous.hasPurchase &&
        previous.purchaseRequestId != purchase.requestId) {
      // A new paid callback selects its own order. Maintenance of an older
      // receipt must never overwrite it, or move an already pinned claim.
      if (!fromStoreCallback ||
          previous.ownerUid != null && previous.status != 'completed') {
        return;
      }
      previous = null;
    }
    if (previous?.status == 'completed') {
      // A later explicit guest checkout may reuse the UUID retained for check.
      // Its new receipt needs a new claim; an old background callback does not.
      if (!fromStoreCallback) return;
      previous = null;
    }
    if (previous == null ||
        previous.purchaseRequestId != purchase.requestId ||
        purchase.reportStatus == 'completed' && !previous.purchaseConfirmed) {
      await store.saveGuestPurchase(purchase);
    }
    var claim =
        previous ??
        MembershipGuestClaimRecord(
          guest: guest,
          purchaseRequestId: purchase.requestId,
          tracking: _trackingFor(purchase),
        );
    if (claim.purchaseRequestId == null && claim.recoveredProof == null) {
      claim = claim.copyWith(
        purchaseRequestId: purchase.requestId,
        tracking: _trackingFor(purchase),
        autoClaimAllowed: true,
      );
    }
    final purchasedAt = _purchaseTimeMillis(purchaseTime ?? '');
    if (claim.purchasedAt == null ||
        purchasedAt != null && purchasedAt > claim.purchasedAt!) {
      claim = claim.copyWith(
        purchasedAt: purchasedAt ?? DateTime.now().millisecondsSinceEpoch,
      );
    }
    if (purchase.reportStatus == 'completed' && !claim.purchaseConfirmed) {
      claim = claim.copyWith(
        purchaseRequestId: purchase.requestId,
        purchaseConfirmed: true,
      );
      if (!_currentGuestLoginUuids.contains(guest.accountUuid)) {
        _invalidateGuestStartupCheck();
        _guestOrderChecks.remove(guest.accountUuid);
      }
    }
    if (!identical(previous, claim) ||
        _pendingGuestClaimWrites.contains(guest.accountUuid)) {
      await _saveGuestClaim(claim);
    }
  }

  Future<void> _refreshGuestLoginRequest() async {
    if (_disposed) return;
    final uid = await readLoginUid();
    if (_disposed) return;
    String? requestId;
    if (uid == null) {
      for (final claim in _guestClaims.values) {
        if (claim.status == 'completed') continue;
        final id = claim.purchaseRequestId ?? claim.guest.accountUuid;
        if (checkGuestPurchase != null &&
            !_currentGuestLoginUuids.contains(claim.guest.accountUuid) &&
            _guestOrderChecks[claim.guest.accountUuid]?.hasUnboundOrder !=
                true) {
          continue;
        }
        final needsLogin =
            _currentGuestLoginUuids.contains(claim.guest.accountUuid)
            ? claim.requiresLogin
            : checkGuestPurchase == null
            ? claim.requiresLogin
            : _guestOrderChecks[claim.guest.accountUuid]?.hasUnboundOrder ==
                  true;
        if (needsLogin && !_presentedAttempts.contains(id)) {
          requestId = id;
          break;
        }
      }
      if (requestId == null && !_busy && _presentedAttempts.isEmpty) {
        // A reinstall has no local claim record. A store-discovered UUID can
        // still require login according to check, without creating an order.
        for (final entry in _guestOrderChecks.entries) {
          if (!_guestClaims.containsKey(entry.key) &&
              entry.value.hasUnboundOrder) {
            requestId = entry.key;
            break;
          }
        }
      }
    }
    guestLoginRequestId.value = requestId;
  }

  Future<void> _completeGuestClaim(MembershipGuestClaimRecord record) async {
    if (record.status != 'completed' || record.ownerUid == null) return;
    final accountUuid = record.guest.accountUuid;
    final session = _session;
    if (_claimWalletRefreshSessions[accountUuid] != session &&
        !_disposed &&
        await readLoginUid() == record.ownerUid) {
      // Refresh even when a local report or cleanup is still pending. A failed
      // wallet request retries this completed claim's cleanup, never its POST.
      await refreshWallet?.call();
      if (!_disposed && session == _session) {
        _claimWalletRefreshSessions[accountUuid] = session;
      }
    }
    // The server also owns store settlement for a recovered claim. Keep the
    // completed claim and proof until local cleanup succeeds, without reposting.
    await store.completeGuestClaim(record);
    for (final purchase in _records.values.toList()) {
      if (purchase.guest?.accountUuid == record.guest.accountUuid) {
        _records[purchase.requestId] = purchase.bindGuestToAccount(
          record.ownerUid!,
        );
      }
    }
    _guestClaims.remove(accountUuid);
    _currentGuestLoginUuids.remove(accountUuid);
    _guestOrderChecks.remove(record.guest.accountUuid);
    _pendingGuestClaimWrites.remove(record.guest.accountUuid);
    _claimRetries.remove(accountUuid)?.timer?.cancel();
    _claimWalletRefreshSessions.remove(accountUuid);
    _signedTransactions.removeWhere(
      (key, _) => key.startsWith('$accountUuid:'),
    );
    _guestPurchaseRequests.removeWhere(
      (_, request) => request.guest?.accountUuid == accountUuid,
    );
    await _refreshGuestLoginRequest();
  }

  Future<void> _flushGuestClaims() async {
    for (final uuid in _unpaidGuestCleanup.toList()) {
      await _discardUnpurchasedGuestIdentity(uuid);
    }
    for (final claim in _guestClaims.values.toList()) {
      if (_disposed) return;
      try {
        if (_pendingGuestClaimWrites.contains(claim.guest.accountUuid)) {
          await _saveGuestClaim(claim);
        }
        if (claim.status == 'completed') await _completeGuestClaim(claim);
      } catch (error) {
        _scheduleGuestMaintenance();
        _log('guest claim cleanup deferred', error);
      }
    }
  }

  Future<void> _claimPendingGuests() async {
    if (_disposed) return;
    await _flushGuestClaims();
    final uid = await readLoginUid();
    if (_disposed) return;
    await _refreshGuestLoginRequest();
    if (uid == null || claimGuest == null) return;
    for (var record in _guestClaims.values.toList()) {
      if (_disposed || await readLoginUid() != uid) return;
      if (record.ownerUid == null &&
          _guestHomeCheck != null &&
          !_guestStartupResolved &&
          !_currentGuestLoginUuids.contains(record.guest.accountUuid)) {
        continue;
      }
      if (!record.needsRetry ||
          (!record.autoClaimAllowed && record.ownerUid == null) ||
          record.ownerUid != null && record.ownerUid != uid) {
        continue;
      }
      final session = _session;
      final previousStatus = record.status;
      final accountUuid = record.guest.accountUuid;
      final retry = _claimRetries.putIfAbsent(
        accountUuid,
        _MembershipClaimRetry.new,
      );
      if (!retry.canAttempt) continue;
      var requested = false;
      try {
        final purchase = _claimPurchase(record);
        if (purchase == null && record.recoveredProof == null) {
          // Login can finish before a temporarily unavailable store recovers.
          // Keep recovering the original proof after login, not just on Home.
          if (retry.proofAttempts >= 3) continue;
          record = record.copyWith(ownerUid: uid);
          await _saveGuestClaim(record);
          if (_disposed || session != _session || await readLoginUid() != uid) {
            return;
          }
          retry.proofAttempts++;
          final recovered = await _recoverGuestProofAfterLogin(record, uid);
          if (recovered == null) {
            _scheduleGuestMaintenance();
            continue;
          }
          record = recovered;
        }
        final request = purchase != null
            ? MembershipClaimRequest.fromPurchase(
                await _guestPurchaseRequest(purchase),
              )
            : await _recoveredGuestClaimRequest(record);
        if (_disposed || session != _session || await readLoginUid() != uid) {
          return;
        }
        record = record.copyWith(
          ownerUid: uid,
          recoveredProof: request.signedTransaction.isEmpty
              ? null
              : record.recoveredProof?.withSignedTransaction(
                  request.signedTransaction,
                ),
        );
        // Pin the first login before sending a request. A timeout must never
        // cause this receipt to be claimed by a later, different account.
        await _saveGuestClaim(record);
        if (_disposed || session != _session || await readLoginUid() != uid) {
          return;
        }
        retry.attempts++;
        requested = true;
        final result = await _sendTrackedClaim(record, request);
        record = record.copyWith(status: result.status.name);
        await _saveGuestClaim(record);
        if (result.status == MembershipReportStatus.completed) {
          await _completeGuestClaim(record);
        }
        if (record.needsRetry) _scheduleGuestClaimRetry(accountUuid, retry);
      } catch (error) {
        if (requested && record.needsRetry) {
          _scheduleGuestClaimRetry(accountUuid, retry);
        } else {
          _scheduleGuestMaintenance();
        }
        _log('guest claim deferred', error);
      } finally {
        if (session == _session &&
            record.status != null &&
            record.status != previousStatus) {
          _catalogChanged();
        }
      }
    }
  }

  Future<MembershipGuestClaimRecord?> _recoverGuestProofAfterLogin(
    MembershipGuestClaimRecord record,
    String uid,
  ) async {
    if (discoverGuestPurchases == null) return null;
    final session = _session;
    final candidates = <String, BillingPurchase>{};
    for (final entry in await discoverGuestPurchases!().timeout(
      guestRecoveryTimeout,
    )) {
      final purchase = entry.purchase;
      final credential = provider == MembershipProvider.google
          ? purchase.purchaseToken
          : purchase.transactionId;
      final uuid = purchase.obfuscatedAccountId?.trim().toLowerCase();
      if (purchase.provider.apiValue == provider.name &&
          (purchase.status == BillingPurchaseStatus.purchased ||
              purchase.status == BillingPurchaseStatus.restored) &&
          entry.isCurrent(DateTime.now()) &&
          purchase.productId.isNotEmpty &&
          credential.isNotEmpty &&
          uuid == record.guest.accountUuid) {
        candidates['${purchase.productId}:$credential'] = purchase;
      }
    }
    if (candidates.length != 1 ||
        _disposed ||
        session != _session ||
        await readLoginUid() != uid) {
      return null;
    }
    final purchase = candidates.values.single;
    final recovered = record.copyWith(
      recoveredProof: MembershipGuestClaimProof(
        provider: provider,
        storeProductId: purchase.productId,
        requestId: newBillingAttemptId(),
        purchaseToken: purchase.purchaseToken,
        transactionId: purchase.transactionId,
        signedTransaction: purchase.signedTransaction,
      ),
    );
    if (provider == MembershipProvider.apple &&
        purchase.signedTransaction.isNotEmpty) {
      _signedTransactions['${record.guest.accountUuid}:${purchase.transactionId}'] =
          purchase.signedTransaction;
    }
    await _saveGuestClaim(recovered);
    return recovered;
  }
}
