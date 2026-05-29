import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../icons/my_flutter_app_icons.dart';
import '../../network/json_utils.dart';
import '../../utils/stat_count_formatter.dart';
import '../common/genesis_image_viewer_overlay.dart';

typedef OriginDiscussPageLoader =
    Future<OriginDiscussPage> Function({
      required String oid,
      required int pn,
      required int rn,
    });

const int originDiscussPageSize = 20;

Future<OriginDiscussPage> loadOriginDiscussPage(
  BuildContext context,
  String oid, {
  int pn = 1,
  int rn = originDiscussPageSize,
}) async {
  final resolvedOid = oid.trim();
  if (resolvedOid.isEmpty) return OriginDiscussPage.empty(pn: pn, rn: rn);

  final data = await AppServicesScope.read(
    context,
  ).api.v1.discuss.list(bizId: resolvedOid, pn: pn, rn: rn);
  return OriginDiscussPage.fromJson(data);
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
    required this.authorName,
    required this.avatar,
    required this.content,
    this.imageUrls = const <String>[],
    required this.replyCount,
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
      fallback: 'User',
    );
    return OriginDiscussListItem(
      discussId: asString(json['discuss_id']),
      authorName: name,
      avatar: asString(author?['avatar'] ?? author?['avatar_url']),
      content: asString(json['content']),
      imageUrls: _imageUrlsFrom(json['images'] ?? json['image_urls']),
      replyCount: asInt(json['reply_cnt']),
      createdAt: _parseDateTime(json['created_at']),
      seed: uid.isEmpty ? name : uid,
      latestReplies: latestReplies,
    );
  }

  final String discussId;
  final String authorName;
  final String avatar;
  final String content;
  final List<String> imageUrls;
  final int replyCount;
  final DateTime? createdAt;
  final String seed;
  final List<Map<String, dynamic>> latestReplies;
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

  List<OriginDiscussListItem> get items => List.unmodifiable(_items);
  int get totalAll => _totalAll;
  int get currentPage => _currentPage;
  bool get hasLoaded => _hasLoaded;
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  bool get expanded => _expanded;
  Object? get error => _error;

  bool get hasMore => _totalAll > _items.length;
  bool get shouldShowViewMore =>
      _expanded ? hasMore : _totalAll > 2 && _items.isNotEmpty;

  List<OriginDiscussListItem> get visibleItems {
    if (_expanded) return items;
    return _items.take(2).toList(growable: false);
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
      _totalAll = page.totalAll;
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

class OriginDiscussList extends StatelessWidget {
  const OriginDiscussList({
    super.key,
    required this.controller,
    this.count,
    this.showHeader = true,
    this.enableViewMore = true,
  });

  final OriginDiscussListController controller;
  final int? count;
  final bool showHeader;
  final bool enableViewMore;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final comments = controller.visibleItems;
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
                      _DiscussPreviewRow(item: entry.$2),
                      if (entry.$1 != comments.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            if (enableViewMore && controller.shouldShowViewMore) ...[
              const SizedBox(height: 12),
              _ViewMoreButton(controller: controller),
            ],
          ],
        );
      },
    );
  }
}

class _ViewMoreButton extends StatelessWidget {
  const _ViewMoreButton({required this.controller});

  final OriginDiscussListController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        key: const ValueKey('origin-discuss-view-more'),
        behavior: HitTestBehavior.opaque,
        onTap: controller.isLoadingMore ? null : controller.viewMore,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        const Icon(MyFlutterApp.discuss, size: 14, color: Color(0xFF1D1D1D)),
        const SizedBox(width: 6),
        Text(
          'Discuss (${formatStatCount(count)})',
          style: const TextStyle(
            color: Color(0xFF1D1D1D),
            fontSize: 14,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DiscussPreviewRow extends StatelessWidget {
  const _DiscussPreviewRow({required this.item});

  final OriginDiscussListItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DiscussAvatar(item: item),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DiscussPreviewMeta(item: item),
              const SizedBox(height: 5),
              Text(
                item.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1D1D1D),
                  fontSize: 12,
                  height: 1.38,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (item.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DiscussImageThumbnails(urls: item.imageUrls),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscussImageThumbnails extends StatelessWidget {
  const _DiscussImageThumbnails({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in urls.indexed)
          _DiscussImageThumbnail(
            url: entry.$2,
            onTap: () => showGenesisImageViewer(
              context,
              imageUrls: urls,
              initialIndex: entry.$1,
            ),
          ),
      ],
    );
  }
}

class _DiscussImageThumbnail extends StatelessWidget {
  const _DiscussImageThumbnail({required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();
    final fallback = Container(
      color: const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 22,
        color: Color(0xFF999999),
      ),
    );
    final image = imageUrl.isEmpty
        ? fallback
        : imageUrl.startsWith('assets/')
        ? Image.asset(
            imageUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : Image.network(
            imageUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return fallback;
            },
          );

    return GestureDetector(
      key: ValueKey('origin-discuss-image-$imageUrl'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(width: 80, height: 80, child: image),
      ),
    );
  }
}

class _DiscussPreviewMeta extends StatelessWidget {
  const _DiscussPreviewMeta({required this.item});

  final OriginDiscussListItem item;

  @override
  Widget build(BuildContext context) {
    final date = _dateLabel(item.createdAt);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  item.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _metaStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                MyFlutterApp.skipNext,
                size: 15,
                color: Color(0xFF8B8B8B),
              ),
              const SizedBox(width: 4),
              Text('${item.replyCount}', style: _metaStyle),
            ],
          ),
        ),
        if (date.isNotEmpty) ...[const Spacer(), Text(date, style: _metaStyle)],
      ],
    );
  }
}

class _DiscussAvatar extends StatelessWidget {
  const _DiscussAvatar({required this.item});

  final OriginDiscussListItem item;

  @override
  Widget build(BuildContext context) {
    final avatar = item.avatar.trim();
    final fallback = _DiscussAvatarFallback(
      seed: item.seed,
      label: item.authorName,
    );
    if (avatar.isEmpty) return fallback;

    final image = avatar.startsWith('assets/')
        ? Image.asset(
            avatar,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
          )
        : Image.network(
            avatar,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return fallback;
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(width: 30, height: 30, child: image),
    );
  }
}

class _DiscussAvatarFallback extends StatelessWidget {
  const _DiscussAvatarFallback({required this.seed, required this.label});

  final String seed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? '?' : label.trim().characters.first;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _gradientFor(seed)),
        ),
        alignment: Alignment.center,
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

const _metaStyle = TextStyle(
  color: Color(0xFF8B8B8B),
  fontSize: 12,
  height: 1.1,
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

String _dateLabel(DateTime? value) {
  if (value == null) return '';
  return '${value.year}/${value.month}/${value.day}';
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
          return asString(map['url'] ?? map['image_url'] ?? map['image']);
        }
        return asString(raw);
      })
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}

List<Color> _gradientFor(String seed) {
  final hash = seed.codeUnits.fold<int>(
    0,
    (a, b) => (a * 131 + b) & 0x7fffffff,
  );
  int tint(int v) => 0xFF000000 | (v & 0x00FFFFFF) | 0x00303030;
  return [Color(tint(hash)), Color(tint(hash * 17))];
}
