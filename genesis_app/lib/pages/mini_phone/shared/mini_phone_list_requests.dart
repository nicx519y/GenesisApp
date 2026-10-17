import 'dart:async';
import 'package:flutter/material.dart';
import '../state/mini_phone_store.dart';

class MiniPhoneListRequests {
  MiniPhoneListRequests(this.store);
  final MiniPhoneStore store;
  final _refreshingPhoneLists = <String>{};
  Future<void> refresh(String key, Future<dynamic> Function() load) async {
    _refreshingPhoneLists.add(key);
    try {
      await load();
    } finally {
      _refreshingPhoneLists.remove(key);
    }
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
                      notification.overscroll > 0)) &&
              store.hasMore[key] == true &&
              !store.busy.contains(key) &&
              !store.errors.containsKey(key) &&
              !_refreshingPhoneLists.contains(key)) {
            unawaited(next());
          }
          return false;
        },
        child: child,
      );
}
