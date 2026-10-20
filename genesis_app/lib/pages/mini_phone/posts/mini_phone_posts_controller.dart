import 'package:flutter/foundation.dart';

import '../../../network/mini_phone/mini_phone_api.dart';
import '../state/mini_phone_requests.dart';
import 'mini_phone_post_feed_cache.dart';

/// Posts state is independent of DM recovery and never refreshes app lists on push.
class MiniPhonePostsController {
  MiniPhonePostsController({
    required this.api,
    required this.worldId,
    required this.requests,
    required this.users,
    required this.resolveNotificationUsers,
    required this.refreshPostSummary,
  });
  final MiniPhoneApi api;
  final String worldId;
  final MiniPhoneRequests requests;
  final Map<String, PhonePerson> users;
  final void Function(List<PhoneNotification>) resolveNotificationUsers;
  final Future<bool> Function({bool afterWrite}) refreshPostSummary;
  bool notificationsVisible = false,
      postsVisible = false,
      unreadNotificationsOnly = true;
  bool get foreground => requests.foreground;
  bool get phoneVisible => requests.phoneVisible;
  Map<String, int> get pages => requests.pages;
  Map<String, bool> get hasMore => requests.hasMore;
  Map<String, String> get errors => requests.errors;
  Set<String> get busy => requests.busy;
  List<String> postAuthorIds = [];
  final _feeds = <String?, MiniPhonePostFeedCache>{};
  MiniPhonePostFeedCache get _feed =>
      _feeds.putIfAbsent(authorFilter, MiniPhonePostFeedCache.new);
  List<PhonePost> get posts => _feed.posts;
  set posts(List<PhonePost> value) => _feed.posts = value;
  PhonePage<PhoneNotification>? notifications;
  final details = <int, PhonePostDetail>{};
  int _interactionRevision = 0;
  int get interactionRevision => _interactionRevision;
  final comments = <int, List<PhoneComment>>{};
  final _deferredPostReads = <String, Future<bool> Function()>{};
  Future<bool> load<T>(
    String key,
    Future<T> Function() fetch,
    void Function(T) apply, {
    String requestKey = '',
    bool deduplicate = true,
    bool allowBackground = false,
  }) => requests.load(
    key,
    fetch,
    apply,
    requestKey: requestKey,
    deduplicate: deduplicate,
    allowBackground: allowBackground,
  );
  void reset() {
    _postReadOnLoad = false;
    _postReadTask = null;
    _authorFilter = null;
    _feeds.clear();
    postAuthorIds = [];
    notifications = null;
    details.clear();
    _interactionRevision++;
    comments.clear();
    _deferredPostReads.clear();
    _likeIntent.clear();
    _likeRunning.clear();
    likeTargets.clear();
  }

  bool _postReadOnLoad = false;
  Future<bool>? _postReadTask;

  /// Both explicit Posts entry and a successfully opened Home notification use
  /// the world's all-notifications receipt. Never replay it on background events:
  /// there is no server cursor, so replay could consume newly arrived notices.
  Future<bool> markPostsRead() {
    final existing = _postReadTask;
    if (existing != null) return existing;
    final generation = requests.generation;
    late final Future<bool> task;
    task =
        (() async {
          final read = await load(
            'readPosts',
            () => api.readPosts(worldId),
            (_) {},
          );
          if (!read || !requests.isCurrent(generation)) return false;
          await refreshPostSummary(afterWrite: true);
          if (requests.isCurrent(generation) && notificationsVisible) {
            await refreshNotifications();
          }
          return true;
        })().whenComplete(() {
          if (identical(_postReadTask, task)) _postReadTask = null;
        });
    _postReadTask = task;
    return task;
  }

  String? _authorFilter;
  String? get authorFilter => _authorFilter;
  set authorFilter(String? charId) {
    final value = charId == '' ? null : charId;
    if (_authorFilter == value) return;
    _authorFilter = value;
    // Discard superseded requests, but immediately restore this filter's cache.
    requests.versions['posts'] = (requests.versions['posts'] ?? 0) + 1;
    _restoreFeedPagination();
    errors.remove('posts');
    busy.remove('posts');
    requests.notify();
  }

  void _restoreFeedPagination() {
    final feed = _feed;
    if (feed.page case final page?) {
      pages['posts'] = page;
    } else {
      pages.remove('posts');
    }
    if (feed.hasMore case final more?) {
      hasMore['posts'] = more;
    } else {
      hasMore.remove('posts');
    }
  }

  Future<bool> refreshPostAuthors() =>
      load('postAuthors', () => api.postAuthors(worldId), (ids) {
        if (!listEquals(postAuthorIds, ids)) postAuthorIds = ids;
      });

  Future<bool> refreshPosts({bool next = false, bool markRead = false}) async {
    if (next && (busy.contains('posts') || hasMore['posts'] != true)) {
      return false;
    }
    if (markRead) _postReadOnLoad = true;
    final authorsRefresh = next ? null : refreshPostAuthors();
    final filter = authorFilter;
    final feed = _feed;
    final pn = next ? (pages['posts'] ?? 1) + 1 : 1;
    final lastPage = next ? pn : (feed.page ?? 1);
    final generation = requests.generation;
    final version = (requests.versions['posts'] ?? 0) + 1;
    void checkCurrent() {
      if (!requests.isCurrent(generation) ||
          requests.versions['posts'] != version) {
        throw const MiniPhoneRequestCancelled();
      }
    }

    final ok = await load(
      'posts',
      () async {
        final incoming = <PhonePost>[];
        // Revalidate the already loaded window without dropping its tail or
        // publishing half a refresh when a later page fails.
        for (var pageNumber = pn; ; pageNumber++) {
          checkCurrent();
          if (!foreground) throw const MiniPhoneRequestCancelled();
          final page = await api.posts(worldId, pn: pageNumber, charId: filter);
          checkCurrent();
          if (page.pn != pageNumber ||
              page.rn <= 0 ||
              (page.list.isEmpty && page.hasMore)) {
            throw const FormatException('Invalid posts pagination');
          }
          incoming.addAll(page.list);
          if (!page.hasMore || pageNumber >= lastPage) {
            return (posts: incoming, page: pageNumber, hasMore: page.hasMore);
          }
        }
      },
      (result) {
        feed.reconcile(
          result.posts,
          append: next,
          page: result.page,
          hasMore: result.hasMore,
        );
        for (final p in result.posts) {
          // A fresh feed supersedes interaction details cached before entry.
          if (details.remove(p.id) != null) _interactionRevision++;
          if (p.author.type == 1) users[p.author.id] = p.author;
        }
        _restoreFeedPagination();
      },
      requestKey: '$next:$pn:$lastPage:$filter',
    );
    if (ok && _postReadOnLoad && postsVisible && phoneVisible && foreground) {
      _postReadOnLoad = false;
      await markPostsRead();
    }
    await authorsRefresh;
    return ok;
  }

  Future<bool> _confirmPostRead(
    String key,
    Future<bool> Function() read,
  ) async {
    final g = requests.generation;
    if (requests.disposed) return false;
    final ok = foreground ? await read() : false;
    if (requests.isCurrent(g) && !ok && !foreground) {
      _deferredPostReads[key] = () => _confirmPostRead(key, read);
    }
    return ok;
  }

  Future<void> retryDeferredReads() async {
    final reads = _deferredPostReads.values.toList();
    _deferredPostReads.clear();
    await Future.wait(reads.map((read) => read()));
  }

  Future<bool> refreshDetail(
    int id, {
    bool afterWrite = false,
    bool onEntry = false,
  }) {
    Future<bool> read() =>
        load('detail:$id', () => api.detail(worldId, id), (d) {
          details[id] = d;
          _interactionRevision++;
        }, deduplicate: !afterWrite && !onEntry);
    return afterWrite ? _confirmPostRead('detail:$id', read) : read();
  }

  Future<bool> refreshComments(
    int id, {
    bool afterWrite = false,
    bool onEntry = false,
  }) {
    final key = 'comments:$id';
    Future<bool> read() {
      final generation = requests.generation;
      final version = (requests.versions[key] ?? 0) + 1;
      void checkCurrent() {
        if (!requests.isCurrent(generation) ||
            requests.versions[key] != version ||
            !foreground) {
          throw const MiniPhoneRequestCancelled();
        }
      }

      return load<List<PhoneComment>>(
        key,
        () async {
          final all = <int, PhoneComment>{};
          var pn = 1;
          while (true) {
            checkCurrent();
            final page = await api.comments(worldId, id, pn: pn, rn: 100);
            checkCurrent();
            if (page.pn != pn ||
                page.rn <= 0 ||
                (page.list.isEmpty && page.hasMore)) {
              throw const FormatException('Invalid comment pagination');
            }
            for (final comment in page.list) {
              all[comment.id] = comment;
            }
            if (!page.hasMore) break;
            pn++;
          }
          return all.values.toList()..sort((a, b) {
            final at = DateTime.tryParse(a.publishedAt);
            final bt = DateTime.tryParse(b.publishedAt);
            final byTime = at != null && bt != null
                ? at.compareTo(bt)
                : a.publishedAt.compareTo(b.publishedAt);
            return byTime != 0 ? byTime : a.id.compareTo(b.id);
          });
        },
        (all) {
          comments[id] = all;
          pages.remove(key);
          hasMore.remove(key);
        },
        deduplicate: !afterWrite && !onEntry,
      );
    }

    return afterWrite ? _confirmPostRead(key, read) : read();
  }

  Future<bool> refreshNotifications({int pn = 1}) => load(
    'notifications',
    () =>
        api.notifications(worldId, pn: pn, unreadOnly: unreadNotificationsOnly),
    (page) {
      notifications = page;
      resolveNotificationUsers(page.list);
    },
    requestKey: '$pn:$unreadNotificationsOnly',
  );
  final _likeIntent = <int, bool>{};
  final likeTargets = <int, bool>{};
  final _likeRunning = <int>{};
  Future<void> setLiked(int id, bool liked) async {
    _likeIntent[id] = liked;
    likeTargets[id] = liked;
    _interactionRevision++;
    requests.notify();
    if (!_likeRunning.add(id)) return;
    final g = requests.generation;
    try {
      while (requests.isCurrent(g) && _likeIntent.containsKey(id)) {
        final desired = _likeIntent.remove(id)!;
        final ok = await load(
          'like:$id',
          () => desired ? api.like(worldId, id) : api.unlike(worldId, id),
          (_) {},
          allowBackground: true,
        );
        if (!requests.isCurrent(g)) return;
        final queried = await refreshDetail(id, afterWrite: true);
        if (!ok && !queried) {
          _likeIntent.remove(id);
          return;
        }
        // Only a newer user intent may run after an uncertain operation.
        if (_likeIntent[id] == details[id]?.isLiked) _likeIntent.remove(id);
      }
    } finally {
      if (requests.isCurrent(g)) {
        _likeRunning.remove(id);
        likeTargets.remove(id);
        _interactionRevision++;
        requests.notify();
      }
    }
  }
}
