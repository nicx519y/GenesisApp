import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../network/http_transport.dart';
import '../../../network/models/world_history.dart';

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

/// One snapshot, one operation at a time. Cancellation invalidates callbacks
/// even with a transport that completes after cancel. Failures never retry on
/// a timer and never modify the directory or the displayed window.
class WorldHistoryController extends ChangeNotifier {
  WorldHistoryController({
    required this.worldId,
    required this.fetch,
    this.maxMessages = 1000,
    this.maxBytes = 8 * 1024 * 1024,
  });
  final String worldId;
  final WorldHistoryFetch fetch;
  final int maxMessages, maxBytes;
  final List<HistoryPageSlot> _pages = [];
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

  bool get loading => _completion != null;
  bool get failed => _failed != null;
  int get firstResident => _pages.indexWhere((p) => p.messages != null);
  int get lastResident => _pages.lastIndexWhere((p) => p.messages != null);
  bool get hasNewer => firstResident > 0;
  bool get hasOlder =>
      !ready ||
      lastResident >= 0 &&
          (lastResident < _pages.length - 1 || _pages.last.hasMore);
  Iterable<WorldHistoryMessage> get newestFirst sync* {
    final seen = <String>{};
    for (final page in _pages) {
      for (final row in page.messages ?? const <WorldHistoryMessage>[]) {
        if (seen.add(row.id)) yield row;
      }
    }
  }

  int get residentCount => newestFirst.length;
  int get residentBytes => newestFirst.fold(0, (n, m) => n + m.contentBytes);

  void setActive(bool value) {
    if (_disposed || active == value) return;
    active = value;
    if (!value) {
      _cancel(remember: true);
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
    if (!ready) return refresh();
    if (!hasOlder) return Future.value();
    return _run(lastResident + 1);
  }

  Future<void> loadNewer() =>
      hasNewer ? _run(firstResident - 1) : Future.value();

  Future<void> _run(int operation) {
    if (_disposed) return Future.value();
    if (!active) {
      // Only explicitly requested operations are resumed on visibility return.
      _resume = operation;
      return Future.value();
    }
    if (loading) {
      if (_operation == operation) return _completion!.future;
      final generation = _generation, requestedSnapshot = snapshot;
      return _completion!.future.then<void>((_) async {
        if (_disposed ||
            !active ||
            generation != _generation ||
            operation != -1 && requestedSnapshot != snapshot) {
          return;
        }
        await _run(operation);
      });
    }
    final cursor = operation == -1
        ? null
        : operation < _pages.length
        ? _pages[operation].requestCursor
        : _pages.last.responseCursor;
    final generation = _generation;
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
        final page = await fetch(
          worldId: worldId,
          cursor: cursor,
          limit: 20,
          cancellationToken: token,
        );
        if (_disposed || generation != _generation || token.isCancelled) return;
        page.validate(worldId, cursor);
        if (page.hasMore &&
            _pages
                .take(operation < 0 ? 0 : operation)
                .any((p) => p.requestCursor == page.cursor)) {
          throw const FormatException('History cursor cycle');
        }
        if (operation >= 0 && operation < _pages.length) {
          final old = _pages[operation];
          if (old.responseCursor != page.cursor ||
              old.hasMore != page.hasMore ||
              old.firstId != page.messages.firstOrNull?.id ||
              old.lastId != page.messages.lastOrNull?.id) {
            throw const FormatException(
              'History snapshot changed; refresh required',
            );
          }
          old.messages = page.messages;
        } else if (operation == -1) {
          _pages.clear();
          _pages.add(HistoryPageSlot(null, page));
          snapshot++;
          _readingPage = 0;
          _pinnedPages.clear();
          _arrivingPage = null;
        } else {
          _pages.add(HistoryPageSlot(cursor, page));
        }
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
        }
        if (!completion.isCompleted) completion.complete();
      }
    }());
    return completion.future;
  }

  int? pageFor(String id) {
    for (var index = 0; index < _pages.length; index++) {
      if (_pages[index].messages?.any((m) => m.id == id) ?? false) return index;
    }
    return null;
  }

  /// Called after layout with visible rows, plus any pending reveal/anchor.
  /// Neighbour pages stay resident. Eviction only removes an outside page so
  /// the shared list never silently bridges a hole in the middle of history.
  void updateReading({
    String? messageId,
    Iterable<String> pinnedIds = const [],
  }) {
    if (_disposed) return;
    final page = messageId == null ? null : pageFor(messageId);
    if (page != null) _readingPage = page;
    _pinnedPages
      ..clear()
      ..addAll(pinnedIds.map(pageFor).whereType<int>());
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
      _pages[candidates.first].messages = null;
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
    _cancel(remember: false);
    _resume = null;
    _failed = null;
    error = null;
    _pages.clear();
    _pinnedPages.clear();
    _arrivingPage = null;
    ready = false;
    revision++;
    snapshot++;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel(remember: false);
    _pages.clear();
    super.dispose();
  }
}
