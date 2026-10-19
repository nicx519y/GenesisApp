import 'dart:async';
import '../../../network/mini_phone/mini_phone_api.dart';
import '../state/mini_phone_requests.dart';

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
  List<PhonePost> posts = [];
  PhonePage<PhoneNotification>? notifications;
  final details = <int, PhonePostDetail>{};
  int _interactionRevision = 0;
  int get interactionRevision => _interactionRevision;
  final comments = <int, List<PhoneComment>>{};
  final commentPreviews = <int, List<PhoneComment>>{};
  final _previewCounts = <int, int>{};
  int _previewRevision = 0;
  int get previewRevision => _previewRevision;
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
    _authorFilter = null;
    posts = [];
    postAuthorIds = [];
    notifications = null;
    details.clear();
    _interactionRevision++;
    comments.clear();
    commentPreviews.clear();
    _previewCounts.clear();
    _previewRevision++;
    _deferredPostReads.clear();
    _likeIntent.clear();
    _likeRunning.clear();
    likeTargets.clear();
  }

  bool _postReadOnLoad = false;
  String? _authorFilter;
  String? get authorFilter => _authorFilter;
  set authorFilter(String? charId) {
    final value = charId == '' ? null : charId;
    if (_authorFilter == value) return;
    _authorFilter = value;
    // Invalidate in-flight pages before another author's first page starts.
    requests.versions['posts'] = (requests.versions['posts'] ?? 0) + 1;
    posts = [];
    pages.remove('posts');
    hasMore.remove('posts');
    errors.remove('posts');
    busy.remove('posts');
  }

  Future<bool> refreshPostAuthors() => load(
    'postAuthors',
    () => api.postAuthors(worldId),
    (ids) => postAuthorIds = ids,
  );

  Future<bool> refreshPosts({bool next = false, bool markRead = false}) async {
    if (next && (busy.contains('posts') || hasMore['posts'] != true)) {
      return false;
    }
    if (markRead) _postReadOnLoad = true;
    final authorsRefresh = next ? null : refreshPostAuthors();
    final pn = next ? (pages['posts'] ?? 1) + 1 : 1;
    final ok = await load(
      'posts',
      () => api.posts(worldId, pn: pn, charId: authorFilter),
      (page) {
        posts = <int, PhonePost>{
          if (next)
            for (final p in posts) p.id: p,
          for (final p in page.list) p.id: p,
        }.values.toList();
        for (final p in page.list) {
          // A fresh feed supersedes interaction details cached before entry.
          details.remove(p.id);
          _previewCounts.remove(p.id);
          if (p.commentCount == 0) commentPreviews.remove(p.id);
          final previewKey = 'commentPreview:${p.id}';
          requests.versions[previewKey] =
              (requests.versions[previewKey] ?? 0) + 1;
          // Superseded loads cannot clear busy in their version-guarded
          // completion. Release it here so the visible row can load again.
          busy.remove(previewKey);
          _previewRevision++;
          if (p.author.type == 1) users[p.author.id] = p.author;
        }
        pages['posts'] = pn;
        hasMore['posts'] = page.hasMore;
      },
      requestKey: '$pn:$authorFilter',
    );
    if (ok && _postReadOnLoad && postsVisible && phoneVisible && foreground) {
      _postReadOnLoad = false;
      final read = await load(
        'readPosts',
        () => api.readPosts(worldId),
        (_) {},
      );
      if (read) {
        await refreshPostSummary(afterWrite: true);
        if (notificationsVisible) await refreshNotifications();
      }
    }
    await authorsRefresh;
    return ok;
  }

  /// Fetch only visible feed previews, independently of detail pagination.
  /// The feed API may omit comments_preview; never fetch full post details here.
  void ensureCommentPreviews(List<PhonePost> visiblePosts) {
    if (!postsVisible || !phoneVisible || !foreground || requests.uid == null) {
      return;
    }
    for (final post in visiblePosts) {
      final count = details[post.id]?.commentCount ?? post.commentCount;
      if (count == 0 ||
          post.commentsPreview.length >= (count < 3 ? count : 3) ||
          _previewCounts[post.id] == count) {
        continue;
      }
      if (busy.where((key) => key.startsWith('commentPreview:')).length >= 2) {
        break;
      }
      final key = 'commentPreview:${post.id}';
      if (busy.contains(key)) continue;
      final generation = requests.generation;
      _previewCounts[post.id] = count;
      unawaited(
        load(key, () => api.comments(worldId, post.id, rn: 3), (page) {
          commentPreviews[post.id] = List.unmodifiable(page.list.take(3));
          _previewRevision++;
        }).whenComplete(() {
          if (requests.isCurrent(generation)) {
            _previewRevision++;
            requests.notify();
          }
        }),
      );
    }
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

  Future<bool> refreshDetail(int id, {bool afterWrite = false}) {
    Future<bool> read() =>
        load('detail:$id', () => api.detail(worldId, id), (d) {
          details[id] = d;
          _interactionRevision++;
        }, deduplicate: !afterWrite);
    return afterWrite ? _confirmPostRead('detail:$id', read) : read();
  }

  Future<bool> refreshComments(
    int id, {
    bool next = false,
    bool afterWrite = false,
  }) {
    final key = 'comments:$id',
        pn = next ? (pages['comments:$id'] ?? 1) + 1 : 1;
    Future<bool> read() => load(
      key,
      () => api.comments(worldId, id, pn: pn),
      (page) {
        comments[id] = <int, PhoneComment>{
          if (next)
            for (final c in comments[id] ?? <PhoneComment>[]) c.id: c,
          for (final c in page.list) c.id: c,
        }.values.toList();
        pages[key] = pn;
        hasMore[key] = page.hasMore;
      },
      requestKey: '$pn',
      deduplicate: !afterWrite,
    );
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
