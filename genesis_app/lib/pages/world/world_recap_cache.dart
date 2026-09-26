import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../network/models/world_recent_summary.dart';

typedef WorldRecapLoader =
    Future<WorldRecentSummaryPage> Function({
      required String worldId,
      String? cursor,
    });

/// Owned by one WorldPage, so closing a sheet does not discard its content.
class WorldRecapCache extends ChangeNotifier {
  String worldId = '';
  List<WorldRecentSummary> items = const [];
  String cursor = '';
  bool hasMore = false;
  bool hasLoaded = false;
  bool refreshing = false;
  bool loadingMore = false;
  Object? refreshError;
  Object? loadMoreError;
  int _revision = 0;
  bool _disposed = false;
  bool _refreshAfterCurrent = false;

  /// A push can arrive while the entry refresh is still in flight. Fetch once
  /// more afterward so that response cannot hide the newly saved summary.
  Future<void> refreshOnUpdate(String id, WorldRecapLoader load) {
    if (_disposed) return Future<void>.value();
    if (id == worldId && refreshing) {
      _refreshAfterCurrent = true;
      return Future<void>.value();
    }
    return refresh(id, load);
  }

  Future<void> refresh(String id, WorldRecapLoader load) async {
    if (_disposed) return;
    if (id != worldId) {
      clear();
      worldId = id;
    }
    if (refreshing) return;
    final revision = ++_revision;
    refreshing = true;
    loadingMore = false;
    refreshError = null;
    loadMoreError = null;
    notifyListeners();
    try {
      final page = await load(worldId: id);
      if (!_isCurrent(revision)) return;
      items = List.unmodifiable(page.items);
      hasMore = page.hasMore;
      cursor = page.cursor;
      hasLoaded = true;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      refreshError = error;
    } finally {
      if (_isCurrent(revision)) {
        refreshing = false;
        notifyListeners();
        if (_refreshAfterCurrent) {
          _refreshAfterCurrent = false;
          unawaited(refreshOnUpdate(id, load));
        }
      }
    }
  }

  Future<void> loadMore(WorldRecapLoader load, {bool retry = false}) async {
    if (_disposed ||
        !hasLoaded ||
        !hasMore ||
        refreshing ||
        loadingMore ||
        (loadMoreError != null && !retry)) {
      return;
    }
    final revision = _revision;
    final requestedCursor = cursor;
    loadingMore = true;
    loadMoreError = null;
    notifyListeners();
    try {
      final page = await load(worldId: worldId, cursor: requestedCursor);
      if (!_isCurrent(revision)) return;
      if (page.hasMore && page.cursor == requestedCursor) {
        throw const FormatException('Recent summary cursor did not advance');
      }
      items = List.unmodifiable([...items, ...page.items]);
      hasMore = page.hasMore;
      cursor = page.cursor;
    } catch (error) {
      if (!_isCurrent(revision)) return;
      loadMoreError = error;
    } finally {
      if (_isCurrent(revision)) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int revision) => !_disposed && revision == _revision;

  void clear() {
    ++_revision;
    worldId = '';
    items = const [];
    cursor = '';
    hasMore = false;
    hasLoaded = false;
    refreshing = false;
    loadingMore = false;
    refreshError = null;
    loadMoreError = null;
    _refreshAfterCurrent = false;
  }

  @override
  void dispose() {
    clear();
    _disposed = true;
    super.dispose();
  }
}
