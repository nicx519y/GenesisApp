import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../../../network/http_transport.dart';
import '../../../network/models/world_history.dart';
import 'world_history_section_participation.dart';

part 'world_history_latest_sync.dart';

typedef WorldHistoryFetch =
    Future<WorldHistoryPage> Function({
      required String worldId,
      String? cursor,
      int limit,
      NetworkCancellationToken? cancellationToken,
    });

/// A lightweight directory survives eviction, never message bodies or Tick VMs.
class HistoryPageSlot {
  HistoryPageSlot(this.requestCursor, WorldHistoryPage page)
    : responseCursor = page.cursor,
      hasMore = page.hasMore,
      firstId = page.messages.firstOrNull?.id,
      lastId = page.messages.lastOrNull?.id,
      messages = page.messages;
  final String? requestCursor;
  final String responseCursor;
  final bool hasMore;
  final String? firstId, lastId;
  List<WorldHistoryMessage>? messages;
}

/// A reading snapshot/archive chain and an independent latest HTTP head.
/// Each request lane is serialized. Cancellation invalidates callbacks even
/// with a transport that completes after cancel. Failures preserve both caches.
class WorldHistoryController extends ChangeNotifier {
  WorldHistoryController({
    required this.worldId,
    required this.fetch,
    this.maxMessages = 1000,
    this.maxBytes = 8 * 1024 * 1024,
    int appVersion = 0x7fffffff,
  }) : sectionParticipation = HistorySectionParticipation(
         appVersion: appVersion,
       );
  final String worldId;
  final WorldHistoryFetch fetch;
  final int maxMessages, maxBytes;
  final List<HistoryPageSlot> _pages = [];
  final HistorySectionParticipation sectionParticipation;
  final _resident = SplayTreeMap<int, List<WorldHistoryMessage>>();
  final _messagePages = <String, int>{};
  List<WorldHistoryMessage> _residentMessages = const [];
  int _residentBytes = 0;
  int _chainRevision = 0;
  int residentIndexBuilds = 0;
  int readingUpdates = 0;
  int? updatedPage;
  bool updatedTowardNewer = false;
  bool awaitingUserContinuation = false;
  void allowContinuation() => awaitingUserContinuation = false;
  List<WorldHistoryMessage>? _firstPageSnapshot;
  List<HistoryPageSlot> get pages => List.unmodifiable(_pages);
  int revision = 0;
  int snapshot = 0;
  bool ready = false;
  bool active = false;
  Object? error;
  int? _failed, _resume, _operation;
  // -1 is a refresh, nonnegative values index the page directory.
  NetworkCancellationToken? _token;
  Completer<void>? _completion;
  int _generation = 0;
  bool _disposed = false;
  int _readingPage = 0;
  final Set<int> _pinnedPages = {};
  int? _arrivingPage;
  WorldHistoryPage? _latestPage;
  bool syncEnabled = false;
  bool hasPendingLatest = false;
  Object? syncError;
  int _dirtyRevision = 0, _checkedRevision = 0, _syncGeneration = 0;
  Timer? _syncDebounce, _syncDeadline, _calibration;
  NetworkCancellationToken? _syncToken;
  Completer<void>? _syncCompletion;
  bool get latestDirty => _dirtyRevision > _checkedRevision;
  bool get syncing => _syncCompletion != null;
  void _notifyLatestChanged() => notifyListeners();

  bool get loading => _completion != null;
  bool get failed => _failed != null;
  int get firstResident => _resident.firstKey() ?? -1;
  int get lastResident => _resident.lastKey() ?? -1;
  bool get hasNewer => firstResident > 0;
  bool get hasOlder =>
      !ready ||
      lastResident >= 0 &&
          (lastResident < _pages.length - 1 || _pages.last.hasMore);
  Iterable<WorldHistoryMessage> get newestFirst => _residentMessages;
  int get residentCount => _residentMessages.length;
  int get residentBytes => _residentBytes;

  // Reconcile only the incoming page against bounded, already-owned data.
  // Do not join cursor chains or retain another archive-wide body cache.
  WorldHistoryPage _reuseUnchangedRows(WorldHistoryPage page) {
    final heads = <String, List<WorldHistoryMessage>>{};
    for (final row in [...?_latestPage?.messages, ...?_firstPageSnapshot]) {
      (heads[row.id] ??= []).add(row);
    }
    final messages = <WorldHistoryMessage>[];
    for (final row in page.messages) {
      final residentPage = _messagePages[row.id];
      final candidates = [
        ...?heads[row.id],
        if (residentPage != null) ...?_resident[residentPage],
      ];
      messages.add(
        candidates.where((old) => _sameHistoryMessage(old, row)).firstOrNull ??
            row,
      );
    }
    return WorldHistoryPage(
      worldId: page.worldId,
      messages: List.unmodifiable(messages),
      hasMore: page.hasMore,
      cursor: page.cursor,
    );
  }

  void _setResident(int index, List<WorldHistoryMessage>? messages) {
    _pages[index].messages = messages;
    if (messages == null) {
      _resident.remove(index);
    } else {
      _resident[index] = messages;
    }
  }

  // Only page mutations rebuild this bounded resident index. Scrolling never
  // walks the archive directory or recomputes body sizes.
  void _indexResidents() {
    residentIndexBuilds++;
    _messagePages.clear();
    final rows = <WorldHistoryMessage>[];
    var bytes = 0;
    for (final entry in _resident.entries) {
      // Pages arrive newest-page first, but each response is oldest-first.
      // Normalize only the derived index; cached pages retain server order.
      for (final message in entry.value.reversed) {
        if (_messagePages.containsKey(message.id)) continue;
        _messagePages[message.id] = entry.key;
        rows.add(message);
        bytes += message.contentBytes;
      }
    }
    _residentMessages = rows;
    _residentBytes = bytes;
  }

  void setActive(bool value) {
    if (_disposed || active == value) return;
    active = value;
    if (!value) {
      // The first user-requested page belongs to World once synchronization
      // is enabled, even if the sheet closes before it arrives.
      if (!(!ready && _operation == -1 && syncEnabled)) {
        _cancel(remember: true);
      }
    } else if (_resume != null) {
      final operation = _resume!;
      _resume = null;
      unawaited(_run(operation));
    }
  }

  void requestEntryRefresh() {
    _resume = null;
    active = true;
    unawaited(refresh());
  }

  Future<void> refresh() => _run(-1);
  Future<void> retry() => _failed == null ? Future.value() : _run(_failed!);
  Future<void> loadOlder() {
    allowContinuation();
    if (!ready) return refresh();
    if (!hasOlder) return Future.value();
    return _run(lastResident + 1);
  }

  Future<void> loadNewer() {
    allowContinuation();
    return hasNewer ? _run(firstResident - 1) : Future.value();
  }

  /// Adopt the cached latest head, or restore the reading head, without HTTP.
  bool returnToNewest() {
    if (_disposed ||
        !active ||
        !ready ||
        (loading && !hasPendingLatest) ||
        _firstPageSnapshot == null) {
      return false;
    }
    if (hasPendingLatest) {
      _adoptLatest();
      return true;
    }
    updatedPage = null;
    allowContinuation();
    if (!hasNewer) return true;
    for (final index in _resident.keys.toList()) {
      _setResident(index, null);
    }
    _setResident(0, _firstPageSnapshot);
    _indexResidents();
    _readingPage = 0;
    _pinnedPages.clear();
    _arrivingPage = 0;
    _failed = null;
    error = null;
    revision++;
    notifyListeners();
    return true;
  }

  Future<void> _run(int operation) {
    if (_disposed) return Future.value();
    if (!active && !(operation == -1 && syncEnabled)) {
      // Only explicitly requested operations are resumed on visibility return.
      _resume = operation;
      return Future.value();
    }
    if (loading) {
      if (_operation == operation) return _completion!.future;
      final generation = _generation, requestedSnapshot = snapshot;
      final chainRevision = _chainRevision;
      return _completion!.future.then<void>((_) async {
        if (_disposed ||
            !active ||
            generation != _generation ||
            chainRevision != _chainRevision ||
            operation != -1 && requestedSnapshot != snapshot) {
          return;
        }
        await _run(operation);
      });
    }
    // Normal newer-page navigation uses the same saved first page too.
    if (operation == 0 && _firstPageSnapshot != null) {
      updatedPage = null;
      _setResident(0, _firstPageSnapshot);
      _indexResidents();
      _failed = null;
      error = null;
      _arrivingPage = 0;
      revision++;
      _evict();
      notifyListeners();
      return Future.value();
    }
    final cursor = operation == -1
        ? null
        : operation < _pages.length
        ? _pages[operation].requestCursor
        : _pages.last.responseCursor;
    final generation = _generation;
    final dirtyRevision = _dirtyRevision;
    final completion = Completer<void>();
    final token = NetworkCancellationToken();
    _operation = operation;
    _completion = completion;
    _token = token;
    error = null;
    _failed = null;
    notifyListeners();
    unawaited(() async {
      try {
        final response = await fetch(
          worldId: worldId,
          cursor: cursor,
          limit: 20,
          cancellationToken: token,
        );
        if (_disposed || generation != _generation || token.isCancelled) return;
        response.validate(worldId, cursor);
        final page = _reuseUnchangedRows(response);
        if (page.hasMore &&
            _pages
                .take(operation < 0 ? 0 : operation)
                .any((p) => p.requestCursor == page.cursor)) {
          throw const FormatException('History cursor cycle');
        }
        if (operation >= 0 && operation < _pages.length) {
          final old = _pages[operation];
          updatedTowardNewer = operation < _readingPage;
          if (old.responseCursor != page.cursor ||
              old.hasMore != page.hasMore) {
            // Downstream request cursors belonged to the old chain. Do not
            // combine them with the new response or automatically walk it.
            for (final index
                in _resident.keys.where((i) => i > operation).toList()) {
              _resident.remove(index);
            }
            _pages.removeRange(operation + 1, _pages.length);
            sectionParticipation.truncate(operation + 1);
            _pinnedPages.removeWhere((i) => i > operation);
            if (_readingPage > operation) _readingPage = operation;
            _chainRevision++;
            awaitingUserContinuation = true;
            _resume = null;
          }
          _pages[operation] = HistoryPageSlot(old.requestCursor, page);
          _setResident(operation, page.messages);
          sectionParticipation.replacePage(operation, page.messages.reversed);
          updatedPage = operation;
        } else if (operation == -1) {
          _pages.clear();
          _resident.clear();
          _pages.add(HistoryPageSlot(null, page));
          _setResident(0, page.messages);
          updatedPage = null;
          allowContinuation();
          _chainRevision++;
          _firstPageSnapshot = List.unmodifiable(page.messages);
          _latestPage = page;
          hasPendingLatest = false;
          _checkedRevision = dirtyRevision;
          sectionParticipation.clear();
          sectionParticipation.appendOlder(page.messages.reversed);
          snapshot++;
          _readingPage = 0;
          _pinnedPages.clear();
          _arrivingPage = null;
        } else {
          _pages.add(HistoryPageSlot(cursor, page));
          _setResident(_pages.length - 1, page.messages);
          updatedPage = null;
          sectionParticipation.appendOlder(page.messages.reversed);
        }
        _indexResidents();
        ready = true;
        _arrivingPage = operation < 0 ? 0 : operation;
        revision++;
        _evict();
      } catch (failure) {
        if (!_disposed && generation == _generation && !token.isCancelled) {
          error = failure;
          _failed = operation;
        }
      } finally {
        if (!_disposed && generation == _generation) {
          _completion = null;
          _token = null;
          _operation = null;
          notifyListeners();
          if (operation == -1 && ready && latestDirty) _scheduleLatestSync();
        }
        if (!completion.isCompleted) completion.complete();
      }
    }());
    return completion.future;
  }

  int? pageFor(String id) => _messagePages[id];

  /// Called after layout with visible rows, plus any pending reveal/anchor.
  /// Neighbour pages stay resident. Eviction only removes an outside page so
  /// the shared list never silently bridges a hole in the middle of history.
  void updateReading({
    String? messageId,
    Iterable<String> pinnedIds = const [],
  }) {
    if (_disposed) return;
    final page = messageId == null ? null : pageFor(messageId);
    final pins = pinnedIds.map(pageFor).whereType<int>().toSet();
    if ((page == null || page == _readingPage) &&
        setEquals(pins, _pinnedPages) &&
        _arrivingPage == null) {
      return;
    }
    readingUpdates++;
    if (page != null) _readingPage = page;
    _pinnedPages
      ..clear()
      ..addAll(pins);
    _arrivingPage = null;
    if (_evict()) notifyListeners();
  }

  bool _evict() {
    var changed = false;
    final protected = <int>{
      _readingPage,
      ..._pinnedPages,
      if (_arrivingPage != null) _arrivingPage!,
    };
    final neighborhood = <int>{
      for (final i in protected) ...[i - 1, i, i + 1],
    };
    while (residentCount > maxMessages || residentBytes > maxBytes) {
      final first = firstResident, last = lastResident;
      if (first < 0 || first == last) {
        break; // Never truncate an oversized page.
      }
      final candidates = [first, last]..removeWhere(neighborhood.contains);
      if (candidates.isEmpty) {
        break; // Visible/reveal pages temporarily exceed budget.
      }
      candidates.sort(
        (a, b) => (b - _readingPage).abs().compareTo((a - _readingPage).abs()),
      );
      _setResident(candidates.first, null);
      _indexResidents();
      changed = true;
    }
    if (changed) revision++;
    return changed;
  }

  void _cancel({required bool remember}) {
    if (remember && loading) _resume = _operation;
    _generation++;
    _token?.cancel();
    _token = null;
    final completion = _completion;
    _completion = null;
    _operation = null;
    if (completion != null && !completion.isCompleted) completion.complete();
  }

  void clear() {
    _cancelLatestSync();
    _latestPage = null;
    hasPendingLatest = false;
    syncError = null;
    _dirtyRevision = _checkedRevision = 0;
    _cancel(remember: false);
    _resume = null;
    _failed = null;
    error = null;
    _pages.clear();
    _resident.clear();
    _indexResidents();
    updatedPage = null;
    _chainRevision++;
    allowContinuation();
    _pinnedPages.clear();
    _firstPageSnapshot = null;
    sectionParticipation.clear();
    _arrivingPage = null;
    ready = false;
    revision++;
    snapshot++;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelLatestSync();
    _latestPage = null;
    _cancel(remember: false);
    _pages.clear();
    _resident.clear();
    _indexResidents();
    _firstPageSnapshot = null;
    sectionParticipation.clear();
    super.dispose();
  }
}
