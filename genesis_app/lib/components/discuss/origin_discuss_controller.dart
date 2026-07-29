part of 'origin_discuss_library.dart';

class OriginDiscussListController extends ChangeNotifier {
  final List<OriginDiscussListItem> _items = <OriginDiscussListItem>[];

  String _oid = '';
  OriginDiscussPageLoader? _loader;
  int _requestSerial = 0;
  int _totalAll = 0;
  int _currentPage = 0;
  bool _hasLoaded = false;
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  bool _expanded = false;
  Object? _error;
  final Set<String> _likePendingIds = <String>{};
  final Set<String> _replyLoadingIds = <String>{};
  final Set<String> _progressLoadingKeys = <String>{};
  final Set<String> _progressCompletedKeys = <String>{};
  final Map<String, _OriginDiscussProgress> _progressResults =
      <String, _OriginDiscussProgress>{};
  final Map<String, int> _replyCurrentPages = <String, int>{};
  final Map<String, int> _replyTotals = <String, int>{};
  final Map<String, int> _replyRequestSerials = <String, int>{};
  bool _isDisposed = false;

  List<OriginDiscussListItem> get items => List.unmodifiable(_items);
  int get totalAll => _totalAll;
  int get currentPage => _currentPage;
  bool get hasLoaded => _hasLoaded;
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  bool get expanded => _expanded;
  Object? get error => _error;
  bool isLikePending(String discussId) => _likePendingIds.contains(discussId);
  bool isReplyLoading(String discussId) => _replyLoadingIds.contains(discussId);

  bool get hasMore => _totalAll > _items.length;
  bool get shouldShowViewMore =>
      _expanded ? hasMore : _totalAll > 2 && _items.isNotEmpty;

  @override
  void dispose() {
    _isDisposed = true;
    _requestSerial += 1;
    _replyRequestSerials.clear();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  List<OriginDiscussListItem> get visibleItems {
    if (_expanded) return items;
    return _items.take(2).toList(growable: false);
  }

  void seedSingleItem(OriginDiscussListItem item) {
    if (_isDisposed) return;
    _requestSerial += 1;
    _items
      ..clear()
      ..add(item);
    _totalAll = 1;
    _currentPage = 1;
    _hasLoaded = true;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _expanded = true;
    _error = null;
    _likePendingIds.clear();
    _replyLoadingIds.clear();
    _progressLoadingKeys.clear();
    _progressCompletedKeys.clear();
    _progressResults.clear();
    _replyCurrentPages.clear();
    _replyTotals.clear();
    _replyRequestSerials.clear();
    notifyListeners();
  }

  bool seedRepliesPage({
    required String rootDiscussId,
    required OriginDiscussRepliesPage page,
  }) {
    if (_isDisposed) return false;
    final comment = page.comment;
    if (comment == null) return false;

    final normalizedRootId = rootDiscussId.trim();
    final rootItem = comment.copyWith(
      replyCount: page.total,
      latestReplies: page.items,
    );
    _requestSerial += 1;
    _items
      ..clear()
      ..add(rootItem);
    _totalAll = 1;
    _currentPage = 1;
    _hasLoaded = true;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _expanded = true;
    _error = null;
    _likePendingIds.clear();
    _replyLoadingIds.clear();
    _progressLoadingKeys.clear();
    _progressCompletedKeys.clear();
    _progressResults.clear();
    _replyCurrentPages
      ..clear()
      ..[normalizedRootId] = page.pn;
    _replyTotals
      ..clear()
      ..[normalizedRootId] = page.total;
    _replyRequestSerials.clear();
    notifyListeners();
    return true;
  }

  void seedItems({
    required String oid,
    required List<OriginDiscussListItem> items,
    required int totalAll,
  }) {
    if (_isDisposed) return;
    _requestSerial += 1;
    _oid = oid.trim();
    _loader = null;
    _items
      ..clear()
      ..addAll(items);
    _totalAll = totalAll;
    _currentPage = 1;
    _hasLoaded = true;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _expanded = false;
    _error = null;
    _likePendingIds.clear();
    _replyLoadingIds.clear();
    _progressLoadingKeys.clear();
    _progressCompletedKeys.clear();
    _progressResults.clear();
    _replyCurrentPages.clear();
    _replyTotals.clear();
    _replyRequestSerials.clear();
    notifyListeners();
  }

  bool hasProgressTarget(OriginDiscussListItem item) {
    return item.authorUid.trim().isNotEmpty &&
        _progressOriginId(item).isNotEmpty;
  }

  void configure({
    required String oid,
    required OriginDiscussPageLoader loader,
  }) {
    if (_isDisposed) return;
    final resolvedOid = oid.trim();
    final changed = resolvedOid != _oid;
    _oid = resolvedOid;
    _loader = loader;
    if (!changed) return;
    _requestSerial += 1;
    _items.clear();
    _totalAll = 0;
    _currentPage = 0;
    _hasLoaded = false;
    _isInitialLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _expanded = false;
    _error = null;
    _likePendingIds.clear();
    _replyLoadingIds.clear();
    _progressLoadingKeys.clear();
    _progressCompletedKeys.clear();
    _progressResults.clear();
    _replyCurrentPages.clear();
    _replyTotals.clear();
    _replyRequestSerials.clear();
    notifyListeners();
  }

  void setLikePending(String discussId, bool pending) {
    if (discussId.isEmpty) return;
    final changed = pending
        ? _likePendingIds.add(discussId)
        : _likePendingIds.remove(discussId);
    if (changed) notifyListeners();
  }

  void applyLikeState({
    required String discussId,
    required bool isLiked,
    required int likeCount,
  }) {
    final normalizedDiscussId = discussId.trim();
    if (normalizedDiscussId.isEmpty) return;
    final normalizedLikeCount = likeCount < 0 ? 0 : likeCount;
    var changed = false;

    for (var index = 0; index < _items.length; index += 1) {
      final item = _items[index];
      if (item.discussId == normalizedDiscussId) {
        _items[index] = item.copyWith(
          isLiked: isLiked,
          likeCount: normalizedLikeCount,
        );
        changed = true;
        continue;
      }

      final replies = item.latestReplies;
      var replyChanged = false;
      final nextReplies = replies
          .map((reply) {
            if (asString(reply['discuss_id']) != normalizedDiscussId) {
              return reply;
            }
            replyChanged = true;
            return {
              ...reply,
              'is_liked': isLiked,
              'like_cnt': normalizedLikeCount,
              'like_count': normalizedLikeCount,
            };
          })
          .toList(growable: false);

      if (replyChanged) {
        _items[index] = item.copyWith(latestReplies: nextReplies);
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  Future<void> loadProgressForItem({
    required OriginDiscussListItem item,
    required Future<Map<String, dynamic>> Function({
      required String uid,
      required String originId,
    })
    loader,
  }) async {
    final uid = item.authorUid.trim();
    final originId = _progressOriginId(item);
    if (uid.isEmpty || originId.isEmpty) return;

    final key = _progressKey(uid: uid, originId: originId);
    final cached = _progressResults[key];
    if (cached != null) {
      _applyProgress(uid: uid, originId: originId, progress: cached);
      return;
    }
    if (_progressCompletedKeys.contains(key) ||
        _progressLoadingKeys.contains(key)) {
      return;
    }

    final serial = _requestSerial;
    _progressLoadingKeys.add(key);
    try {
      final progress = await loader(uid: uid, originId: originId);
      if (serial != _requestSerial) return;
      final worldId = asString(progress['world_id']);
      final storyCount = asInt(progress['tick_cnt'], fallback: item.storyCount);
      final snapshot = _OriginDiscussProgress(
        worldId: worldId,
        storyCount: storyCount,
      );
      _progressResults[key] = snapshot;
      _applyProgress(uid: uid, originId: originId, progress: snapshot);
      _progressCompletedKeys.add(key);
    } catch (_) {
      if (serial == _requestSerial) _progressCompletedKeys.remove(key);
    } finally {
      _progressLoadingKeys.remove(key);
    }
  }

  void _applyProgress({
    required String uid,
    required String originId,
    required _OriginDiscussProgress progress,
    bool notify = true,
  }) {
    var changed = false;
    for (var index = 0; index < _items.length; index += 1) {
      final item = _items[index];
      if (item.authorUid.trim() != uid) continue;
      if (_progressOriginId(item) != originId) continue;
      if (item.worldId == progress.worldId &&
          item.storyCount == progress.storyCount) {
        continue;
      }
      _items[index] = item.copyWith(
        worldId: progress.worldId,
        storyCount: progress.storyCount,
      );
      changed = true;
    }
    if (changed && notify) notifyListeners();
  }

  void _applyCachedProgress({bool notify = true}) {
    var changed = false;
    for (var index = 0; index < _items.length; index += 1) {
      final item = _items[index];
      final uid = item.authorUid.trim();
      final originId = _progressOriginId(item);
      if (uid.isEmpty || originId.isEmpty) continue;
      final progress =
          _progressResults[_progressKey(uid: uid, originId: originId)];
      if (progress == null) continue;
      if (item.worldId == progress.worldId &&
          item.storyCount == progress.storyCount) {
        continue;
      }
      _items[index] = item.copyWith(
        worldId: progress.worldId,
        storyCount: progress.storyCount,
      );
      changed = true;
    }
    if (changed && notify) notifyListeners();
  }

  String _progressOriginId(OriginDiscussListItem item) {
    final bizId = item.bizId.trim();
    return bizId.isEmpty ? _oid : bizId;
  }

  String _progressKey({required String uid, required String originId}) {
    return '$uid\u0001$originId';
  }

  void adjustReplyCount(String discussId, int delta) {
    _replaceItem(
      discussId,
      (item) => item.copyWith(
        replyCount: (item.replyCount + delta) < 0 ? 0 : item.replyCount + delta,
      ),
    );
  }

  void insertReply(String discussId, Map<String, dynamic> reply) {
    final normalizedDiscussId = discussId.trim();
    if (normalizedDiscussId.isEmpty) return;
    final normalizedReply = Map<String, dynamic>.from(reply);
    _replaceItem(normalizedDiscussId, (item) {
      final replyId = asString(normalizedReply['discuss_id']);
      final existing = item.latestReplies
          .where((current) {
            if (replyId.isEmpty) return true;
            return asString(current['discuss_id']) != replyId;
          })
          .map((current) => Map<String, dynamic>.from(current))
          .toList(growable: true);
      return item.copyWith(
        replyCount: item.replyCount + 1,
        latestReplies: [normalizedReply, ...existing],
      );
    });
    final currentTotal = _replyTotals[normalizedDiscussId];
    if (currentTotal != null) {
      _replyTotals[normalizedDiscussId] = currentTotal + 1;
    }
  }

  bool hasLoadedReplies(String discussId) {
    return _replyCurrentPages.containsKey(discussId);
  }

  int replyButtonCount(OriginDiscussListItem item) {
    final discussId = item.replyRootDiscussId;
    if (!hasLoadedReplies(discussId)) {
      if (item.latestReplies.isEmpty) return item.replyCount;
      final visibleCount = math.min(item.latestReplies.length, 2);
      return item.replyCount > visibleCount ? item.replyCount : 0;
    }
    final total = _replyTotals[discussId] ?? item.replyCount;
    return math.max(0, total - item.latestReplies.length);
  }

  bool hasMoreReplies(OriginDiscussListItem item) {
    return replyButtonCount(item) > 0;
  }

  Future<void> loadMoreReplies({
    required String rootDiscussId,
    required Future<OriginDiscussRepliesPage> Function({
      required String rootDiscussId,
      required int pn,
      required int rn,
    })
    loader,
  }) async {
    final normalizedRootId = rootDiscussId.trim();
    if (normalizedRootId.isEmpty ||
        _replyLoadingIds.contains(normalizedRootId)) {
      return;
    }
    final nextPage = (_replyCurrentPages[normalizedRootId] ?? 0) + 1;
    final serial = (_replyRequestSerials[normalizedRootId] ?? 0) + 1;
    _replyRequestSerials[normalizedRootId] = serial;
    _replyLoadingIds.add(normalizedRootId);
    notifyListeners();

    try {
      final page = await loader(
        rootDiscussId: normalizedRootId,
        pn: nextPage,
        rn: originDiscussRepliesPageSize,
      );
      if (_replyRequestSerials[normalizedRootId] != serial) return;
      _applyRepliesPage(normalizedRootId, page);
    } finally {
      if (_replyRequestSerials[normalizedRootId] == serial) {
        _replyLoadingIds.remove(normalizedRootId);
        notifyListeners();
      }
    }
  }

  void _applyRepliesPage(String rootDiscussId, OriginDiscussRepliesPage page) {
    final index = _items.indexWhere(
      (item) => item.replyRootDiscussId == rootDiscussId,
    );
    if (index < 0) return;
    final item = _items[index];
    final nextReplies = page.pn <= 1
        ? page.items
        : _mergeReplyAppend(item.latestReplies, page.items);
    final rootItem = page.comment ?? item;
    _items[index] = rootItem.copyWith(
      replyCount: page.total,
      latestReplies: nextReplies,
    );
    _replyCurrentPages[rootDiscussId] = page.pn;
    _replyTotals[rootDiscussId] = page.total;
  }

  List<Map<String, dynamic>> _mergeReplyAppend(
    List<Map<String, dynamic>> existing,
    List<Map<String, dynamic>> incoming,
  ) {
    final existingIds = existing
        .map((item) => asString(item['discuss_id']))
        .where((id) => id.isNotEmpty)
        .toSet();
    final appendedIds = <String>{};
    return [
      ...existing.map((item) => Map<String, dynamic>.from(item)),
      ...incoming
          .where((item) {
            final id = asString(item['discuss_id']);
            if (id.isEmpty) return true;
            return !existingIds.contains(id) && appendedIds.add(id);
          })
          .map((item) => Map<String, dynamic>.from(item)),
    ];
  }

  void _replaceItem(
    String discussId,
    OriginDiscussListItem Function(OriginDiscussListItem item) update,
  ) {
    if (discussId.isEmpty) return;
    final index = _items.indexWhere((item) => item.discussId == discussId);
    if (index < 0) return;
    _items[index] = update(_items[index]);
    notifyListeners();
  }

  Future<void> loadInitialIfNeeded() {
    if (_hasLoaded || _isInitialLoading || _oid.isEmpty) return Future.value();
    return _loadPage(1, _LoadMode.initial);
  }

  Future<void> retryInitial() => _loadPage(1, _LoadMode.initial);

  Future<void> refreshFirstPage() => _loadPage(1, _LoadMode.refresh);

  Future<void> viewMore() {
    if (!_expanded) {
      _expanded = true;
      notifyListeners();
      return Future.value();
    }
    if (!hasMore) return Future.value();
    return loadNextPage();
  }

  Future<void> loadNextPage() {
    if (_isInitialLoading || _isLoadingMore || _isRefreshing || !hasMore) {
      return Future.value();
    }
    return _loadPage(_currentPage + 1, _LoadMode.append);
  }

  Future<void> _loadPage(int pageNumber, _LoadMode mode) async {
    if (_isDisposed) return;
    final loader = _loader;
    final oid = _oid;
    if (loader == null || oid.isEmpty) return;

    final serial = ++_requestSerial;
    _error = null;
    switch (mode) {
      case _LoadMode.initial:
        _isInitialLoading = _items.isEmpty;
        break;
      case _LoadMode.append:
        _isLoadingMore = true;
        break;
      case _LoadMode.refresh:
        _isRefreshing = true;
        break;
    }
    notifyListeners();

    try {
      final page = await loader(
        oid: oid,
        pn: pageNumber,
        rn: originDiscussPageSize,
      );
      if (_isDisposed || serial != _requestSerial || oid != _oid) return;
      _mergePage(page, mode);
      _totalAll = page.topTotal;
      _currentPage = mode == _LoadMode.refresh
          ? (_currentPage < page.pn ? page.pn : _currentPage)
          : page.pn;
      _hasLoaded = true;
    } catch (error) {
      if (_isDisposed || serial != _requestSerial || oid != _oid) return;
      _error = error;
    } finally {
      if (!_isDisposed && serial == _requestSerial && oid == _oid) {
        _isInitialLoading = false;
        _isLoadingMore = false;
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  void _mergePage(OriginDiscussPage page, _LoadMode mode) {
    switch (mode) {
      case _LoadMode.initial:
        _items
          ..clear()
          ..addAll(page.items);
        break;
      case _LoadMode.append:
        _mergeAppend(page.items);
        break;
      case _LoadMode.refresh:
        _mergeFirstPage(page.items);
        break;
    }
    _applyCachedProgress(notify: false);
  }

  void _mergeAppend(List<OriginDiscussListItem> incoming) {
    final existingIds = _items
        .map((item) => item.discussId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final incomingById = {
      for (final item in incoming)
        if (item.discussId.isNotEmpty) item.discussId: item,
    };
    for (var index = 0; index < _items.length; index += 1) {
      final replacement = incomingById.remove(_items[index].discussId);
      if (replacement != null) _items[index] = replacement;
    }
    final appendedIds = <String>{};
    _items.addAll(
      incoming.where((item) {
        final id = item.discussId;
        if (id.isEmpty) return true;
        return !existingIds.contains(id) && appendedIds.add(id);
      }),
    );
  }

  void _mergeFirstPage(List<OriginDiscussListItem> incoming) {
    final incomingIds = incoming
        .map((item) => item.discussId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final previousRest = _items
        .where((item) => !incomingIds.contains(item.discussId))
        .toList(growable: false);
    _items
      ..clear()
      ..addAll(incoming)
      ..addAll(previousRest);
  }
}

enum _LoadMode { initial, append, refresh }

class _OriginDiscussProgress {
  const _OriginDiscussProgress({
    required this.worldId,
    required this.storyCount,
  });

  final String worldId;
  final int storyCount;
}
