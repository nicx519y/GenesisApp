import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/paged_response.dart';
import 'package:genesis_flutter_android/pages/me/me_collection_controller.dart';

PagedResponse<String> page(List<String> items, int total, {int offset = 0}) =>
    PagedResponse(data: items, total: total, limit: 2, offset: offset);

void main() {
  test(
    'keeps API total, deduplicates page boundaries and stops at total',
    () async {
      final offsets = <int>[];
      final controller = MeCollectionController<String>(
        itemId: (item) => item,
        loadPage: (offset) async {
          offsets.add(offset);
          return switch (offset) {
            0 => page(['a', 'b'], 5),
            2 => page(['b', 'c'], 5, offset: 2),
            _ => page(['d'], 5, offset: 4),
          };
        },
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.value.count, 5);
      expect(controller.value.items, ['a', 'b']);
      await controller.loadMore();
      expect(controller.value.items, ['a', 'b', 'c']);
      await controller.loadMore();
      await controller.loadMore();
      expect(controller.value.items, ['a', 'b', 'c', 'd']);
      expect(controller.value.count, 5);
      expect(controller.value.hasMore, isFalse);
      expect(offsets, [0, 2, 4]);
    },
  );

  test(
    'concurrent pagination is deduplicated and failure retries same page',
    () async {
      final pending = Completer<PagedResponse<String>>();
      final offsets = <int>[];
      final controller = MeCollectionController<String>(
        itemId: (item) => item,
        loadPage: (offset) async {
          offsets.add(offset);
          if (offset == 0) return page(['a', 'b'], 3);
          if (offsets.length == 2) return pending.future;
          return page(['c'], 3, offset: offset);
        },
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      final loading = controller.loadMore();
      await controller.loadMore();
      expect(offsets, [0, 2]);
      expect(controller.value.items, ['a', 'b']);
      pending.completeError(StateError('offline'));
      await loading;
      expect(controller.value.loadMoreFailed, isTrue);
      expect(controller.value.total, 3);
      expect(controller.value.items, ['a', 'b']);
      await controller.loadMore();
      expect(offsets, [0, 2, 2]);
      expect(controller.value.items, ['a', 'b', 'c']);
      expect(controller.value.loadMoreFailed, isFalse);
    },
  );

  test(
    'refresh supersedes an in-flight next page and resets pagination',
    () async {
      final pending = Completer<PagedResponse<String>>();
      var firstPages = 0;
      final offsets = <int>[];
      final controller = MeCollectionController<String>(
        itemId: (item) => item,
        loadPage: (offset) async {
          offsets.add(offset);
          if (offset != 0) return pending.future;
          return ++firstPages == 1 ? page(['a', 'b'], 4) : page(['new'], 1);
        },
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      final old = controller.loadMore();
      await controller.refresh();
      pending.complete(page(['c', 'd'], 4, offset: 2));
      await old;
      expect(offsets, [0, 2, 0]);
      expect(controller.value.items, ['new']);
      expect(controller.value.total, 1);
      expect(controller.value.hasMore, isFalse);
    },
  );

  test(
    'empty pages stop loading even when server total remains larger',
    () async {
      final controller = MeCollectionController<String>(
        itemId: (item) => item,
        loadPage: (offset) async =>
            offset == 0 ? page(['a', 'b'], 10) : page([], 10, offset: offset),
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.value.items, ['a', 'b']);
      expect(controller.value.count, 10);
      expect(controller.value.hasMore, isFalse);
    },
  );

  test(
    'refresh failure preserves loaded pages, total and next offset',
    () async {
      var failRefresh = false;
      final offsets = <int>[];
      final controller = MeCollectionController<String>(
        itemId: (item) => item,
        loadPage: (offset) async {
          offsets.add(offset);
          if (failRefresh && offset == 0) throw StateError('offline');
          return page(['$offset', '${offset + 1}'], 6, offset: offset);
        },
      );
      addTearDown(controller.dispose);
      await controller.refresh();
      await controller.loadMore();
      failRefresh = true;
      await controller.refresh();
      expect(controller.value.items, ['0', '1', '2', '3']);
      expect(controller.value.total, 6);
      await controller.loadMore();
      expect(offsets, [0, 2, 0, 4]);
    },
  );

  for (final dispose in [false, true]) {
    test(
      '${dispose ? 'dispose' : 'account reset'} ignores pending responses',
      () async {
        final pending = Completer<PagedResponse<String>>();
        final controller = MeCollectionController<String>(
          itemId: (item) => item,
          loadPage: (_) => pending.future,
        );
        var notifications = 0;
        controller.addListener(() => notifications++);
        final loading = controller.refresh();
        if (dispose) {
          controller.dispose();
        } else {
          controller.reset();
        }
        final expectedNotifications = notifications;
        pending.complete(page(['old account'], 1));
        await loading;
        expect(notifications, expectedNotifications);
        if (!dispose) {
          expect(controller.value.items, isEmpty);
          expect(controller.hasLoaded, isFalse);
          controller.dispose();
        }
      },
    );
  }
}
