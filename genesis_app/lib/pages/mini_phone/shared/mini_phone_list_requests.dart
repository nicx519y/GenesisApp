import 'dart:async';
import 'package:flutter/material.dart';
import '../state/mini_phone_requests.dart';

/// A shared paging gate; callers own feature loading and route visibility.
class MiniPhoneListRequests {
  MiniPhoneListRequests(this.requests, {this.isActive});
  final MiniPhoneRequests requests;
  final bool Function()? isActive;
  final _refreshingPhoneLists = <String>{};
  Future<void> refresh(String key, Future<dynamic> Function() load) async {
    if (!_refreshingPhoneLists.add(key)) return;
    try {
      await load();
    } finally {
      _refreshingPhoneLists.remove(key);
    }
  }

  void loadNext(String key, Future<dynamic> Function() next) {
    if (requests.disposed ||
        !requests.foreground ||
        isActive?.call() == false ||
        requests.hasMore[key] != true ||
        requests.busy.contains(key) ||
        requests.errors.containsKey(key) ||
        _refreshingPhoneLists.contains(key)) {
      return;
    }
    unawaited(next());
  }

  /// Only fill a viewport that cannot scroll. Near-bottom paging is user driven.
  void fillViewport(
    String key,
    ScrollMetrics metrics,
    Future<dynamic> Function() next,
  ) {
    if (metrics.maxScrollExtent <= metrics.minScrollExtent) loadNext(key, next);
  }

  Widget build(String key, Future<dynamic> Function() next, Widget child) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical &&
              notification.metrics.extentAfter < 160 &&
              ((notification is ScrollUpdateNotification &&
                      (notification.scrollDelta ?? 0) > 0) ||
                  (notification is OverscrollNotification &&
                      notification.overscroll > 0))) {
            loadNext(key, next);
          }
          return false;
        },
        child: child,
      );
}
