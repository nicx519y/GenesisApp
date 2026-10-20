part of 'world_history_controller.dart';

/// Latest HTTP data is independent of the page chain being read. A socket hint
/// is never treated as an archive row or as proof that HTTP has caught up.
extension WorldHistoryLatestSync on WorldHistoryController {
  void setSyncEnabled(bool value) {
    if (_disposed || syncEnabled == value) return;
    syncEnabled = value;
    if (!value) {
      _cancelLatestSync();
      if (!ready && loading) _cancel(remember: true);
    } else if (!ready && _resume == -1) {
      _resume = null;
      unawaited(_run(-1));
    } else if (latestDirty) {
      _scheduleLatestSync();
    }
  }

  void markLatestDirty() {
    if (_disposed) return;
    _dirtyRevision++;
    _calibration?.cancel();
    _scheduleLatestSync();
    _notifyLatestChanged();
  }

  void _scheduleLatestSync() {
    if (_disposed || !syncEnabled || !ready || syncing) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(syncLatest()),
    );
    _syncDeadline ??= Timer(
      const Duration(seconds: 2),
      () => unawaited(syncLatest()),
    );
  }

  /// Explicit calls also recheck a previously unchanged/failed response.
  Future<void> syncLatest({bool calibration = false}) {
    if (_disposed || !syncEnabled || !ready) return Future.value();
    if (syncing) return _syncCompletion!.future;
    _stopLatestTimers();
    final completion = Completer<void>();
    final token = NetworkCancellationToken();
    final generation = _syncGeneration;
    final requestedRevision = _dirtyRevision;
    final previous = _latestPage;
    _syncCompletion = completion;
    _syncToken = token;
    syncError = null;
    _notifyLatestChanged();
    unawaited(() async {
      var unchanged = false;
      var succeeded = false;
      try {
        final response = await fetch(
          worldId: worldId,
          cursor: null,
          limit: 20,
          cancellationToken: token,
        );
        if (_disposed || generation != _syncGeneration || token.isCancelled) {
          return;
        }
        response.validate(worldId, null);
        final page = _reuseUnchangedRows(response);
        unchanged =
            previous != null &&
            _sameHistoryRows(previous.messages, page.messages) &&
            previous.hasMore == page.hasMore;
        _latestPage = page;
        hasPendingLatest =
            !_sameHistoryRows(_firstPageSnapshot ?? const [], page.messages) ||
            _pages.first.hasMore != page.hasMore;
        if (!unchanged) _checkedRevision = requestedRevision;
        succeeded = true;
      } catch (failure) {
        if (!_disposed && generation == _syncGeneration && !token.isCancelled) {
          syncError = failure;
        }
      } finally {
        if (!_disposed && generation == _syncGeneration) {
          _syncCompletion = null;
          _syncToken = null;
          if (_dirtyRevision > requestedRevision) {
            _scheduleLatestSync();
          } else if (succeeded && unchanged && !calibration && latestDirty) {
            _calibration = Timer(
              const Duration(seconds: 2),
              () => unawaited(syncLatest(calibration: true)),
            );
          }
          _notifyLatestChanged();
        }
        if (!completion.isCompleted) completion.complete();
      }
    }());
    return completion.future;
  }

  void _adoptLatest() {
    final page = _latestPage!;
    // Invalidate old-chain callbacks without canceling the independent sync.
    _cancel(remember: false);
    _resume = null;
    _failed = null;
    error = null;
    _pages
      ..clear()
      ..add(HistoryPageSlot(null, page));
    _resident.clear();
    _setResident(0, page.messages);
    _firstPageSnapshot = List.unmodifiable(page.messages);
    sectionParticipation.clear();
    sectionParticipation.appendOlder(page.messages.reversed);
    _indexResidents();
    _readingPage = 0;
    _pinnedPages.clear();
    _arrivingPage = 0;
    updatedPage = null;
    allowContinuation();
    _chainRevision++;
    hasPendingLatest = false;
    revision++;
    // snapshot is the identity/reset epoch. Updating the head must not clear
    // the view's fold choices or behave like an account switch.
    _notifyLatestChanged();
  }

  void _stopLatestTimers() {
    _syncDebounce?.cancel();
    _syncDeadline?.cancel();
    _calibration?.cancel();
    _syncDebounce = _syncDeadline = _calibration = null;
  }

  void _cancelLatestSync() {
    _stopLatestTimers();
    _syncGeneration++;
    _syncToken?.cancel();
    _syncToken = null;
    final completion = _syncCompletion;
    _syncCompletion = null;
    if (completion != null && !completion.isCompleted) completion.complete();
  }
}

bool _sameHistoryRows(
  List<WorldHistoryMessage> a,
  List<WorldHistoryMessage> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_sameHistoryMessage(a[i], b[i])) return false;
  }
  return true;
}

bool _sameHistoryMessage(WorldHistoryMessage x, WorldHistoryMessage y) =>
    identical(x, y) ||
    (x.id == y.id &&
        x.type == y.type &&
        x.senderId == y.senderId &&
        x.senderName == y.senderName &&
        x.userId == y.userId &&
        x.messageType == y.messageType &&
        x.content == y.content &&
        x.minAppVersion == y.minAppVersion &&
        x.currentTime == y.currentTime &&
        x.createdAt == y.createdAt &&
        x.tickNo == y.tickNo &&
        x.subTickNo == y.subTickNo &&
        listEquals(x.locationRefs, y.locationRefs));
