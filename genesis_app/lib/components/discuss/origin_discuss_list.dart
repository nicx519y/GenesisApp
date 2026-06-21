import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/json_utils.dart';
import '../../routers/app_router.dart';
import '../../ui/components/genesis_avatar.dart';
import '../../ui/components/genesis_list_image.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
import '../../ui/tokens/genesis_image_radii.dart';
import '../../utils/display_name_formatter.dart';
import '../../utils/entity_deleted.dart';
import '../../utils/stat_count_formatter.dart';
import '../common/genesis_center_toast.dart';
import '../common/genesis_image_viewer_overlay.dart';
import '../common/genesis_timestamp_text.dart';
import 'discuss_post_input.dart';
import 'origin_discuss_replies_list.dart';
import 'story_badge.dart';
import '../auth/login_guard.dart';

typedef OriginDiscussPageLoader =
    Future<OriginDiscussPage> Function({
      required String oid,
      required int pn,
      required int rn,
    });
typedef OriginDiscussReplyTap =
    void Function(OriginDiscussListItem item, Map<String, dynamic> reply);
typedef OriginDiscussItemTap = void Function(OriginDiscussListItem item);

const int originDiscussPageSize = 20;
const int originDiscussRepliesPageSize = 20;
const String _discussLikeFilledAsset =
    'assets/custom-icons/png/discuss_like_filled.png';
const String _discussLikeOutlineAsset =
    'assets/custom-icons/png/discuss_like_outline.png';
const String _discussReplyAsset = 'assets/custom-icons/png/discuss_reply.png';
const double _discussAvatarSize = 36;

Future<OriginDiscussPage> loadOriginDiscussPage(
  BuildContext context,
  String oid, {
  int pn = 1,
  int rn = originDiscussPageSize,
}) async {
  final resolvedOid = oid.trim();
  if (resolvedOid.isEmpty) return OriginDiscussPage.empty(pn: pn, rn: rn);

  final api = AppServicesScope.read(context).api.v1;
  final data = await api.discuss.list(bizId: resolvedOid, pn: pn, rn: rn);
  return OriginDiscussPage.fromJson(data);
}

class OriginDiscussRepliesPage {
  const OriginDiscussRepliesPage({
    required this.items,
    required this.total,
    required this.pn,
    required this.rn,
  });

  factory OriginDiscussRepliesPage.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'];
    final items = rawList is List
        ? rawList
              .whereType<Map>()
              .map((raw) => asJsonMap(raw))
              .where((item) {
                final content = asString(item['content']).trim();
                final images = _imageUrlsFrom(item['images']);
                return content.isNotEmpty || images.isNotEmpty;
              })
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return OriginDiscussRepliesPage(
      items: items,
      total: asInt(json['total'], fallback: items.length),
      pn: asInt(json['pn'], fallback: 1),
      rn: asInt(json['rn'], fallback: originDiscussRepliesPageSize),
    );
  }

  final List<Map<String, dynamic>> items;
  final int total;
  final int pn;
  final int rn;
}

class OriginDiscussPage {
  const OriginDiscussPage({
    required this.items,
    required this.topTotal,
    required this.totalAll,
    required this.pn,
    required this.rn,
  });

  factory OriginDiscussPage.empty({
    int pn = 1,
    int rn = originDiscussPageSize,
  }) {
    return OriginDiscussPage(
      items: const <OriginDiscussListItem>[],
      topTotal: 0,
      totalAll: 0,
      pn: pn,
      rn: rn,
    );
  }

  factory OriginDiscussPage.fromJson(Map<String, dynamic> json) {
    final rawList = json['list'];
    final items = rawList is List
        ? rawList
              .whereType<Map>()
              .map((raw) => asJsonMap(raw))
              .map(OriginDiscussListItem.fromEnvelopeJson)
              .where((item) => item.level <= 1)
              .where((item) => item.content.trim().isNotEmpty)
              .toList(growable: false)
        : const <OriginDiscussListItem>[];
    return OriginDiscussPage(
      items: items,
      topTotal: asInt(json['top_total'], fallback: items.length),
      totalAll: asInt(json['total_all'], fallback: items.length),
      pn: asInt(json['pn'], fallback: 1),
      rn: asInt(json['rn'], fallback: originDiscussPageSize),
    );
  }

  final List<OriginDiscussListItem> items;
  final int topTotal;
  final int totalAll;
  final int pn;
  final int rn;
}

class OriginDiscussListItem {
  const OriginDiscussListItem({
    required this.discussId,
    this.rootDiscussId = '',
    this.bizId = '',
    this.worldId = '',
    this.authorUid = '',
    this.authorDeleted = false,
    required this.authorName,
    required this.avatar,
    required this.content,
    this.imageUrls = const <String>[],
    this.storyCount = 0,
    required this.replyCount,
    this.likeCount = 0,
    this.isLiked = false,
    this.level = 1,
    required this.createdAt,
    required this.seed,
    required this.latestReplies,
  });

  factory OriginDiscussListItem.fromEnvelopeJson(Map<String, dynamic> json) {
    final comment = json['comment'] is Map ? asJsonMap(json['comment']) : json;
    final latestReplies = json['latest_replies'] is List
        ? asJsonList(json['latest_replies'])
              .whereType<Map>()
              .map((raw) => asJsonMap(raw))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    return OriginDiscussListItem.fromJson(
      comment,
      latestReplies: latestReplies,
    );
  }

  factory OriginDiscussListItem.fromJson(
    Map<String, dynamic> json, {
    List<Map<String, dynamic>> latestReplies = const <Map<String, dynamic>>[],
  }) {
    final author = json['author'] is Map ? asJsonMap(json['author']) : null;
    final uid = asString(author?['uid'], fallback: asString(json['uid']));
    final name = asString(
      author?['name'] ??
          author?['user_name'] ??
          author?['nickname'] ??
          author?['display_name'] ??
          json['author_name'] ??
          json['user_name'],
      fallback: formatUidForDisplay(uid, fallback: 'User'),
    );
    return OriginDiscussListItem(
      discussId: asString(json['discuss_id']),
      rootDiscussId: asString(json['root_discuss_id']),
      bizId: asString(json['biz_id']),
      worldId: asString(
        json['world_id'],
        fallback: asString(
          json['wid'],
          fallback: asString(json['display_wid_str']),
        ),
      ),
      authorUid: uid,
      authorDeleted: entityDeleted(author?['deleted']),
      authorName: formatUidForDisplay(name, fallback: 'User'),
      avatar: asImageUrl(author?['avatar'] ?? author?['avatar_url']),
      content: asString(json['content']),
      imageUrls: _imageUrlsFrom(json['images'] ?? json['image_urls']),
      storyCount: asInt(
        json['story_cnt'],
        fallback: asInt(json['tick_cnt'], fallback: asInt(json['connect_cnt'])),
      ),
      replyCount: asInt(json['reply_cnt']),
      likeCount: asInt(json['like_cnt'], fallback: asInt(json['like_count'])),
      isLiked: asBool(json['is_liked']),
      level: asInt(json['level'], fallback: 1),
      createdAt: _parseDateTime(json['created_at']),
      seed: uid.isEmpty ? name : uid,
      latestReplies: latestReplies,
    );
  }

  final String discussId;
  final String rootDiscussId;
  final String bizId;
  final String worldId;
  final String authorUid;
  final bool authorDeleted;
  final String authorName;
  final String avatar;
  final String content;
  final List<String> imageUrls;
  final int storyCount;
  final int replyCount;
  final int likeCount;
  final bool isLiked;
  final int level;
  final DateTime? createdAt;
  final String seed;
  final List<Map<String, dynamic>> latestReplies;

  String get replyRootDiscussId {
    final rootId = rootDiscussId.trim();
    return rootId.isEmpty ? discussId : rootId;
  }

  OriginDiscussListItem copyWith({
    String? rootDiscussId,
    String? worldId,
    int? storyCount,
    int? replyCount,
    int? likeCount,
    bool? isLiked,
    List<Map<String, dynamic>>? latestReplies,
  }) {
    return OriginDiscussListItem(
      discussId: discussId,
      rootDiscussId: rootDiscussId ?? this.rootDiscussId,
      bizId: bizId,
      worldId: worldId ?? this.worldId,
      authorUid: authorUid,
      authorDeleted: authorDeleted,
      authorName: authorName,
      avatar: avatar,
      content: content,
      imageUrls: imageUrls,
      storyCount: storyCount ?? this.storyCount,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      level: level,
      createdAt: createdAt,
      seed: seed,
      latestReplies: latestReplies ?? this.latestReplies,
    );
  }
}

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

  List<OriginDiscussListItem> get visibleItems {
    if (_expanded) return items;
    return _items.take(2).toList(growable: false);
  }

  void seedSingleItem(OriginDiscussListItem item) {
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

  void seedItems({
    required String oid,
    required List<OriginDiscussListItem> items,
    required int totalAll,
  }) {
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
    _items[index] = item.copyWith(
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
      if (serial != _requestSerial || oid != _oid) return;
      _mergePage(page, mode);
      _totalAll = page.topTotal;
      _currentPage = mode == _LoadMode.refresh
          ? (_currentPage < page.pn ? page.pn : _currentPage)
          : page.pn;
      _hasLoaded = true;
    } catch (error) {
      if (serial != _requestSerial || oid != _oid) return;
      _error = error;
    } finally {
      if (serial == _requestSerial && oid == _oid) {
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

class OriginDiscussList extends StatelessWidget {
  const OriginDiscussList({
    super.key,
    required this.controller,
    this.count,
    this.showHeader = true,
    this.enableViewMore = true,
    this.collapseInitialItems = true,
    this.showActions = false,
    this.showReplies = false,
    this.imageTapOpensViewer = false,
    this.disableAvatarProfileTap = false,
    this.onAuthorTap,
    this.onViewMoreTap,
    this.onItemReplyTap,
    this.onReplyTap,
    this.onViewAllRepliesTap,
  });

  final OriginDiscussListController controller;
  final int? count;
  final bool showHeader;
  final bool enableViewMore;
  final bool collapseInitialItems;
  final bool showActions;
  final bool showReplies;
  final bool imageTapOpensViewer;
  final bool disableAvatarProfileTap;
  final OriginDiscussItemTap? onAuthorTap;
  final Future<void> Function()? onViewMoreTap;
  final OriginDiscussItemTap? onItemReplyTap;
  final OriginDiscussReplyTap? onReplyTap;
  final OriginDiscussItemTap? onViewAllRepliesTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final comments = collapseInitialItems
            ? controller.visibleItems
            : controller.items;
        final shouldShowViewMore = collapseInitialItems
            ? controller.shouldShowViewMore
            : controller.hasMore;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) _DiscussHeader(count: count ?? controller.totalAll),
            if (controller.isInitialLoading && comments.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: showHeader ? 12 : 0),
                child: const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (controller.error != null && comments.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: showHeader ? 12 : 0),
                child: TextButton(
                  onPressed: controller.retryInitial,
                  child: const Text('Retry'),
                ),
              )
            else if (comments.isEmpty)
              SizedBox(height: showHeader ? 12 : 0)
            else
              Padding(
                padding: EdgeInsets.only(top: showHeader ? 12 : 0),
                child: Column(
                  children: [
                    for (final entry in comments.indexed) ...[
                      OriginDiscussCommentRow(
                        controller: controller,
                        item: entry.$2,
                        showActions: showActions,
                        showReplies: showReplies,
                        imageTapOpensViewer: imageTapOpensViewer,
                        disableAvatarProfileTap: disableAvatarProfileTap,
                        onAuthorTap: onAuthorTap,
                        onViewMoreTap: onViewMoreTap,
                        onItemReplyTap: onItemReplyTap,
                        onReplyTap: onReplyTap,
                        onViewAllRepliesTap: onViewAllRepliesTap,
                      ),
                      if (entry.$1 != comments.length - 1)
                        const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            if (enableViewMore && shouldShowViewMore) ...[
              const SizedBox(height: 16),
              _ViewMoreButton(
                controller: controller,
                onTap: collapseInitialItems
                    ? onViewMoreTap ?? controller.viewMore
                    : controller.loadNextPage,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ViewMoreButton extends StatelessWidget {
  const _ViewMoreButton({required this.controller, required this.onTap});

  final OriginDiscussListController controller;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        key: const ValueKey('origin-discuss-view-more'),
        behavior: HitTestBehavior.opaque,
        onTap: controller.isLoadingMore ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: controller.isLoadingMore
              ? const SizedBox.square(
                  key: ValueKey('origin-discuss-view-more-loading'),
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'View More >',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF888888),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DiscussHeader extends StatelessWidget {
  const _DiscussHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          discussIconAsset,
          width: 16,
          height: 16,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: 6),
        Text(
          'Discuss (${formatStatCount(count)})',
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class OriginDiscussCommentRow extends StatefulWidget {
  const OriginDiscussCommentRow({
    super.key,
    required this.controller,
    required this.item,
    required this.showActions,
    required this.showReplies,
    required this.imageTapOpensViewer,
    this.disableAvatarProfileTap = false,
    this.onAuthorTap,
    this.onViewMoreTap,
    this.onItemReplyTap,
    this.onReplyTap,
    this.onViewAllRepliesTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final bool showActions;
  final bool showReplies;
  final bool imageTapOpensViewer;
  final bool disableAvatarProfileTap;
  final OriginDiscussItemTap? onAuthorTap;
  final Future<void> Function()? onViewMoreTap;
  final OriginDiscussItemTap? onItemReplyTap;
  final OriginDiscussReplyTap? onReplyTap;
  final OriginDiscussItemTap? onViewAllRepliesTap;

  @override
  State<OriginDiscussCommentRow> createState() =>
      _OriginDiscussCommentRowState();
}

class _OriginDiscussCommentRowState extends State<OriginDiscussCommentRow> {
  static const double _progressPrefetchExtent = 600;

  ScrollPosition? _scrollPosition;
  bool _viewportCheckScheduled = false;
  bool _progressRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachScrollPosition();
      _scheduleViewportCheck();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachScrollPosition();
    _scheduleViewportCheck();
  }

  @override
  void didUpdateWidget(covariant OriginDiscussCommentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.discussId != widget.item.discussId ||
        oldWidget.item.authorUid != widget.item.authorUid ||
        oldWidget.item.bizId != widget.item.bizId) {
      _progressRequested = false;
    }
    _attachScrollPosition();
    _scheduleViewportCheck();
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleScroll);
    super.dispose();
  }

  void _attachScrollPosition() {
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _scrollPosition)) return;
    _scrollPosition?.removeListener(_handleScroll);
    _scrollPosition = position;
    _scrollPosition?.addListener(_handleScroll);
  }

  void _handleScroll() {
    _scheduleViewportCheck();
  }

  void _scheduleViewportCheck() {
    if (_progressRequested || _viewportCheckScheduled) return;
    _viewportCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _viewportCheckScheduled = false;
      _maybeLoadProgress();
    });
  }

  void _maybeLoadProgress() {
    if (_progressRequested) return;
    if (!_isInOrNearViewport()) return;
    if (!widget.controller.hasProgressTarget(widget.item)) return;
    _progressRequested = true;
    final api = AppServicesScope.read(context).api.v1.world;
    unawaited(
      widget.controller.loadProgressForItem(
        item: widget.item,
        loader: ({required uid, required originId}) {
          return api.originProgress(uid: uid, originId: originId);
        },
      ),
    );
  }

  bool _isInOrNearViewport() {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return true;

    final rowRenderObject = context.findRenderObject();
    final viewportRenderObject = scrollable.context.findRenderObject();
    if (rowRenderObject is! RenderBox ||
        viewportRenderObject is! RenderBox ||
        !rowRenderObject.hasSize ||
        !viewportRenderObject.hasSize) {
      return false;
    }

    final rowTop = rowRenderObject
        .localToGlobal(Offset.zero, ancestor: viewportRenderObject)
        .dy;
    final rowBottom = rowTop + rowRenderObject.size.height;
    return rowBottom >= -_progressPrefetchExtent &&
        rowTop <= viewportRenderObject.size.height + _progressPrefetchExtent;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscussAvatarLink(
          item: widget.item,
          disabled: widget.disableAvatarProfileTap,
          onTap: widget.onAuthorTap,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiscussPreviewMeta(
                item: widget.item,
                disabled: widget.disableAvatarProfileTap,
                onAuthorTap: widget.onAuthorTap,
              ),
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onItemReplyTap == null
                    ? null
                    : () => widget.onItemReplyTap!(widget.item),
                child: Text(
                  widget.item.content,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (widget.item.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 6),
                _DiscussImageThumbnails(
                  urls: widget.item.imageUrls,
                  onTap: (index) => _handleImageTap(context, index),
                ),
              ],
              if (widget.showActions) ...[
                const SizedBox(height: 12),
                _DiscussActions(
                  controller: widget.controller,
                  item: widget.item,
                  onReplyTap: widget.onItemReplyTap,
                ),
              ],
              if (widget.showReplies &&
                  (widget.item.latestReplies.isNotEmpty ||
                      widget.controller.hasMoreReplies(widget.item))) ...[
                const SizedBox(height: 12),
                _DiscussReplyPreview(
                  controller: widget.controller,
                  item: widget.item,
                  onReplyTap: widget.onReplyTap,
                  onViewAllTap: widget.onViewAllRepliesTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _handleImageTap(BuildContext context, int index) {
    if (widget.imageTapOpensViewer) {
      showGenesisImageViewer(
        context,
        imageUrls: widget.item.imageUrls,
        initialIndex: index,
      );
      return;
    }
    final itemHandler = widget.onItemReplyTap;
    if (itemHandler != null) {
      itemHandler(widget.item);
      return;
    }
    final viewMoreHandler = widget.onViewMoreTap;
    if (viewMoreHandler != null) {
      unawaited(viewMoreHandler());
    }
  }
}

class _DiscussImageThumbnails extends StatelessWidget {
  const _DiscussImageThumbnails({required this.urls, required this.onTap});

  final List<String> urls;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in urls.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _DiscussImageThumbnail(
                url: entry.$2,
                onTap: () => onTap(entry.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscussActions extends StatelessWidget {
  const _DiscussActions({
    required this.controller,
    required this.item,
    this.onReplyTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final OriginDiscussItemTap? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final likePending = controller.isLikePending(item.discussId);
    final activeColor = item.isLiked
        ? const Color(0xFFFF2344)
        : const Color(0xFF7D8178);
    return Row(
      children: [
        GestureDetector(
          key: ValueKey('origin-discuss-like-${item.discussId}'),
          behavior: HitTestBehavior.opaque,
          onTap: likePending ? null : () => _toggleLike(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              item.isLiked ? _discussLikeFilledAsset : _discussLikeOutlineAsset,
              width: 21,
              height: 21,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '${item.likeCount}',
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: activeColor,
          ),
        ),
        const SizedBox(width: 28),
        GestureDetector(
          key: ValueKey('origin-discuss-reply-${item.discussId}'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final handler = onReplyTap;
            if (handler != null) {
              handler(item);
              return;
            }
            unawaited(
              showOriginDiscussReplyComposer(
                context: context,
                controller: controller,
                item: item,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Image.asset(
              _discussReplyAsset,
              width: 20,
              height: 20,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '${item.replyCount}',
          style: _subtleStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Future<void> _toggleLike(BuildContext context) async {
    final discussId = item.discussId.trim();
    if (discussId.isEmpty || controller.isLikePending(discussId)) return;
    if (!await ensureGenesisLogin(context)) return;
    if (!context.mounted) return;

    final previousLiked = item.isLiked;
    final previousCount = item.likeCount;
    final nextLiked = !previousLiked;
    final nextCount = previousLiked ? previousCount - 1 : previousCount + 1;

    controller.applyLikeState(
      discussId: discussId,
      isLiked: nextLiked,
      likeCount: nextCount,
    );
    controller.setLikePending(discussId, true);
    try {
      final api = AppServicesScope.read(context).api.v1.discuss;
      if (nextLiked) {
        await api.like(discussId: discussId);
      } else {
        await api.unlike(discussId: discussId);
      }
    } catch (_) {
      controller.applyLikeState(
        discussId: discussId,
        isLiked: previousLiked,
        likeCount: previousCount,
      );
      if (context.mounted) showGenesisToast(context, 'Like failed');
    } finally {
      controller.setLikePending(discussId, false);
    }
  }
}

class _DiscussReplyPreview extends StatelessWidget {
  const _DiscussReplyPreview({
    required this.controller,
    required this.item,
    this.onReplyTap,
    this.onViewAllTap,
  });

  final OriginDiscussListController controller;
  final OriginDiscussListItem item;
  final OriginDiscussReplyTap? onReplyTap;
  final OriginDiscussItemTap? onViewAllTap;

  @override
  Widget build(BuildContext context) {
    final hasLoadedReplies = controller.hasLoadedReplies(item.discussId);
    final replies = hasLoadedReplies
        ? item.latestReplies
        : item.latestReplies.take(2).toList(growable: false);
    return OriginDiscussRepliesList(
      discussId: item.discussId,
      replies: replies,
      remainingReplyCount: controller.replyButtonCount(item),
      isLoading: controller.isReplyLoading(item.discussId),
      onLoadMore: () {
        final viewAllHandler = onViewAllTap;
        if (viewAllHandler != null) {
          viewAllHandler(item);
          return;
        }
        unawaited(_loadMoreReplies(context));
      },
      onReplyTap: onReplyTap == null
          ? null
          : (reply) => onReplyTap!(item, reply),
    );
  }

  Future<void> _loadMoreReplies(BuildContext context) async {
    try {
      await controller.loadMoreReplies(
        rootDiscussId: item.replyRootDiscussId,
        loader: ({required rootDiscussId, required pn, required rn}) async {
          final data = await AppServicesScope.read(context).api.v1.discuss
              .replies(rootDiscussId: rootDiscussId, pn: pn, rn: rn);
          return OriginDiscussRepliesPage.fromJson(data);
        },
      );
    } catch (_) {
      if (context.mounted) showGenesisToast(context, 'Load replies failed');
    }
  }
}

Future<bool> showOriginDiscussReplyComposer({
  required BuildContext context,
  required OriginDiscussListController controller,
  required OriginDiscussListItem item,
  String? parentDiscussId,
  String? replyToUid,
  String? replyToUsername,
  String? placeholder,
}) async {
  final discussId = item.discussId.trim();
  final bizId = item.bizId.trim();
  if (discussId.isEmpty || bizId.isEmpty) return false;

  return showDiscussPostComposer(
    context: context,
    title: 'Reply',
    placeholder: placeholder ?? 'Write a reply',
    submitter: (content, images) => submitOriginDiscussReply(
      context: context,
      controller: controller,
      item: item,
      content: content,
      images: images,
      parentDiscussId: parentDiscussId,
      replyToUid: replyToUid,
      replyToUsername: replyToUsername,
    ),
  );
}

Future<void> submitOriginDiscussReply({
  required BuildContext context,
  required OriginDiscussListController controller,
  required OriginDiscussListItem item,
  required String content,
  required List<String> images,
  String? parentDiscussId,
  String? replyToUid,
  String? replyToUsername,
}) async {
  final discussId = item.discussId.trim();
  final bizId = item.bizId.trim();
  final resolvedParentDiscussId = parentDiscussId?.trim().isNotEmpty == true
      ? parentDiscussId!.trim()
      : discussId;
  final resolvedReplyToUid = replyToUid?.trim().isNotEmpty == true
      ? replyToUid!.trim()
      : item.authorUid;
  final resolvedReplyToUsername = replyToUsername?.trim().isNotEmpty == true
      ? replyToUsername!.trim()
      : item.authorName;
  if (discussId.isEmpty || bizId.isEmpty) return;

  final services = AppServicesScope.read(context);
  final created = await services.api.v1.discuss.post(
    bizId: bizId,
    content: content,
    images: images,
    rootDiscussId: discussId,
    parentDiscussId: resolvedParentDiscussId,
  );
  final userInfo = await services.sessionStore.readUserInfo();
  controller.insertReply(
    discussId,
    _localReplyJson(
      created: created,
      content: content,
      images: images,
      bizId: bizId,
      rootDiscussId: discussId,
      parentDiscussId: resolvedParentDiscussId,
      replyToUid: resolvedReplyToUid,
      replyToUsername: resolvedReplyToUsername,
      userInfo: userInfo,
    ),
  );
}

Map<String, dynamic> _localReplyJson({
  required Map<String, dynamic> created,
  required String content,
  required List<String> images,
  required String bizId,
  required String rootDiscussId,
  required String parentDiscussId,
  required String replyToUid,
  required String replyToUsername,
  required Map<String, dynamic>? userInfo,
}) {
  final user = userInfo == null
      ? const <String, dynamic>{}
      : asJsonMap(userInfo);
  final userMap = user['user'] is Map ? asJsonMap(user['user']) : user;
  final uid = asString(userMap['uid']);
  final name = asString(
    userMap['name'] ??
        userMap['user_name'] ??
        userMap['nickname'] ??
        userMap['display_name'],
    fallback: 'User',
  );
  return {
    'discuss_id': asString(created['discuss_id']),
    'biz_type': 1,
    'biz_id': bizId,
    'author': {
      'uid': uid,
      'name': name,
      'avatar': asImageUrl(userMap['avatar'] ?? userMap['avatar_url']),
    },
    'content': content,
    'images': images,
    'root_discuss_id': rootDiscussId,
    'parent_discuss_id': parentDiscussId,
    'reply_to_uid': replyToUid,
    'reply_to_username': replyToUsername,
    'level': asInt(created['level'], fallback: 2),
    'reply_cnt': 0,
    'like_cnt': 0,
    'is_liked': false,
    'created_at': DateTime.now().toIso8601String(),
  };
}

class _DiscussImageThumbnail extends StatelessWidget {
  const _DiscussImageThumbnail({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();

    return GestureDetector(
      key: ValueKey('origin-discuss-image-$imageUrl'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: GenesisListImage(
        imageUrl: imageUrl,
        width: 48,
        height: 48,
        borderRadius: GenesisImageRadii.content,
      ),
    );
  }
}

class _DiscussPreviewMeta extends StatelessWidget {
  const _DiscussPreviewMeta({
    required this.item,
    this.disabled = false,
    this.onAuthorTap,
  });

  final OriginDiscussListItem item;
  final bool disabled;
  final OriginDiscussItemTap? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final authorMeta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            item.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 12,
              height: 1.18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        DiscussStoryBadge(count: item.storyCount),
      ],
    );
    final authorTap = onAuthorTap;
    final canOpenAuthor =
        !disabled &&
        (authorTap != null ||
            (item.authorUid.trim().isNotEmpty && !item.authorDeleted));

    return SizedBox(
      key: ValueKey('origin-discuss-meta-${item.discussId}'),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: canOpenAuthor
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (authorTap != null) {
                        authorTap(item);
                        return;
                      }
                      Navigator.of(context).pushNamed(
                        RouteNames.userInfo,
                        arguments: {'uid': item.authorUid},
                      );
                    },
                    child: authorMeta,
                  )
                : authorMeta,
          ),
          if (item.createdAt != null) ...[
            const SizedBox(width: 8),
            GenesisTimestampText(
              timestamp: item.createdAt,
              style: _subtleStyle,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscussAvatarLink extends StatelessWidget {
  const _DiscussAvatarLink({
    required this.item,
    this.disabled = false,
    this.onTap,
  });

  final OriginDiscussListItem item;
  final bool disabled;
  final OriginDiscussItemTap? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = _DiscussAvatar(item: item);
    if (disabled) return avatar;
    final authorTap = onTap;
    if (authorTap == null &&
        (item.authorUid.trim().isEmpty || item.authorDeleted)) {
      return avatar;
    }
    return GestureDetector(
      key: ValueKey('origin-discuss-avatar-${item.authorUid}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (authorTap != null) {
          authorTap(item);
          return;
        }
        Navigator.of(
          context,
        ).pushNamed(RouteNames.userInfo, arguments: {'uid': item.authorUid});
      },
      child: avatar,
    );
  }
}

class _DiscussAvatar extends StatelessWidget {
  const _DiscussAvatar({required this.item});

  final OriginDiscussListItem item;

  @override
  Widget build(BuildContext context) {
    final avatar = item.avatar.trim();
    return GenesisAvatar(
      url: avatar,
      name: item.authorName,
      size: _discussAvatarSize,
      borderRadius: GenesisAvatarRadii.user,
    );
  }
}

const _subtleStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
);

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text) ??
      DateTime.tryParse(text.replaceFirst(' ', 'T'));
}

List<String> _imageUrlsFrom(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
  }
  if (value is! List) return const <String>[];
  return value
      .map((raw) {
        if (raw is Map) {
          final map = asJsonMap(raw);
          return asImageUrl(
            map['url'] ?? map['image_url'] ?? map['image'],
            fallback: raw,
          );
        }
        return asString(raw);
      })
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}
