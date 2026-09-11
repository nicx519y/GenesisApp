import 'package:flutter/foundation.dart';

import '../../components/me/user_profile_content.dart';
import '../../network/models/paged_response.dart';

/// Independent paging state for one Me collection. Refresh/reset supersedes
/// outstanding pages so stale responses cannot append to a new list/account.
class MeCollectionController<T>
    extends ValueNotifier<UserProfileCollectionState<T>> {
  MeCollectionController({required this.loadPage, required this.itemId})
    : super(UserProfileCollectionState<T>(items: <T>[], isLoading: false));

  final Future<PagedResponse<T>> Function(int offset) loadPage;
  final String Function(T item) itemId;
  int _revision = 0;
  int _nextOffset = 0;
  bool _disposed = false;
  bool get hasLoaded => value.total != null;

  Future<void> refresh() => _load(append: false);

  Future<void> loadMore() async {
    if (_disposed || value.isLoading || value.isLoadingMore || !value.hasMore) {
      return;
    }
    await _load(append: true);
  }

  Future<void> _load({required bool append}) async {
    if (_disposed) return;
    final revision = ++_revision;
    final previous = value;
    value = UserProfileCollectionState<T>(
      items: previous.items,
      total: previous.total,
      isLoading: !append,
      isLoadingMore: append,
      hasMore: previous.hasMore,
    );
    try {
      final page = await loadPage(append ? _nextOffset : 0);
      if (_disposed || revision != _revision) return;
      final itemsById = <String, T>{
        if (append)
          for (final item in previous.items) itemId(item): item,
        for (final item in page.data) itemId(item): item,
      };
      _nextOffset = page.offset + page.limit;
      value = UserProfileCollectionState<T>(
        items: itemsById.values.toList(growable: false),
        total: page.total,
        isLoading: false,
        hasMore:
            page.data.isNotEmpty && page.offset + page.data.length < page.total,
      );
    } catch (_) {
      if (_disposed || revision != _revision) return;
      value = UserProfileCollectionState<T>(
        items: previous.items,
        total: previous.total,
        isLoading: false,
        hasMore: previous.hasMore,
        loadMoreFailed: append,
      );
    }
  }

  void reset() {
    if (_disposed) return;
    ++_revision;
    _nextOffset = 0;
    value = UserProfileCollectionState<T>(items: <T>[], isLoading: false);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revision;
    super.dispose();
  }
}
