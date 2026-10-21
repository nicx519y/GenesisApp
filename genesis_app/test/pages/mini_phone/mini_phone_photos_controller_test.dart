import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/mini_phone/photos/mini_phone_photos_controller.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';

import '../../support/mini_phone_chat_backend.dart';

Map<String, dynamic> photo(int id, {String? desc}) => {
  'asset_id': id,
  'world_id': 'w',
  'image_url': 'https://cdn.test/$id.png',
  'thumbnail_url': '',
  'desc': desc ?? 'Photo $id',
  'created_at': '2026-10-21',
};

void main() {
  test('album requests the server maximum and reuses unchanged data', () async {
    final backend = PhoneBackend();
    final requests = MiniPhoneRequests(() {})..uid = 'u';
    final controller = MiniPhonePhotosController(
      api: backend.api,
      worldId: 'w',
      requests: requests,
    );
    backend.respond = (_) => ok(page([photo(1), photo(2)], rn: 100));
    await controller.refresh();
    expect(backend.calls('album').single.uri.queryParameters['rn'], '100');
    final cached = controller.album;
    await controller.refresh();
    expect(controller.album, same(cached));
    backend.respond = (_) =>
        ok(page([photo(3), photo(2, desc: 'Updated')], rn: 100));
    await controller.refresh();
    expect(controller.album.map((p) => p.id), [3, 2]);
    expect(controller.album.last.description, 'Updated');
  });

  test(
    'first-page refresh keeps cached tail but resets the confirmed boundary',
    () async {
      final backend = PhoneBackend();
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final controller = MiniPhonePhotosController(
        api: backend.api,
        worldId: 'w',
        requests: requests,
      );
      var first = [for (var id = 1; id <= 100; id++) photo(id)];
      var second = [for (var id = 101; id <= 200; id++) photo(id)];
      backend.respond = (r) {
        final pn = int.parse(r.uri.queryParameters['pn']!);
        return ok(page(pn == 1 ? first : second, pn: pn, rn: 100, total: 300));
      };
      await controller.refresh();
      await controller.refresh(next: true);
      final cached = controller.album;
      final unchanged = cached[1];
      first = [photo(300), ...first.skip(1)];
      await controller.refresh();
      expect(controller.album.length, 200);
      expect(controller.album.first.id, 300);
      expect(controller.album[1], same(unchanged));
      expect(controller.album.last, same(cached.last));
      expect(controller.confirmedAlbum.length, 100);
      expect(requests.pages['album'], 1);
      second = [photo(301), ...second.skip(1)];
      await controller.refresh(next: true);
      expect(backend.calls('album').last.uri.queryParameters['pn'], '2');
      expect(controller.album[100].id, 301);
      expect(controller.album.any((p) => p.id == 101), isFalse);
      expect(controller.confirmedAlbum.length, 200);
      backend.respond = (_) => ok(page([photo(2)], rn: 100));
      await controller.refresh();
      expect(controller.album.map((p) => p.id), [2]);
      expect(requests.hasMore['album'], isFalse);
    },
  );

  test(
    'failed refresh and superseded pagination cannot replace the cache',
    () async {
      final backend = PhoneBackend();
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final controller = MiniPhonePhotosController(
        api: backend.api,
        worldId: 'w',
        requests: requests,
      );
      backend.respond = (_) => ok(page([photo(1)], rn: 100, total: 300));
      await controller.refresh();
      final cached = controller.album;
      backend.respond = (_) => {'err_no': 5001, 'err_msg': 'Unavailable'};
      expect(await controller.refresh(), isFalse);
      expect(controller.album, same(cached));
      final pending = Completer<Object?>();
      backend.respond = (r) => r.uri.queryParameters['pn'] == '2'
          ? pending.future
          : ok(page([photo(3)], rn: 100));
      final next = controller.refresh(next: true);
      await Future<void>.delayed(Duration.zero);
      await controller.refresh();
      pending.complete(ok(page([photo(2)], pn: 2, rn: 100, total: 300)));
      expect(await next, isFalse);
      expect(controller.album.map((p) => p.id), [3]);
      requests.reset();
      controller.reset();
      expect(controller.album, isEmpty);
      expect(controller.confirmedAlbum, isEmpty);
    },
  );
}
