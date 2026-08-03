import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_background_preloader.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

void main() {
  test(
    'preloads unique XL CDN previews with at most two active loads',
    () async {
      final resource = GenesisImageResourceRegistry.register(
        const GenesisImageResource(
          smUrl: 'https://cdn.example.com/location-sm.webp',
          xlUrl: 'https://cdn.example.com/location-xl.webp',
        ),
      );
      final startedUrls = <String>[];
      final completions = <String, Completer<void>>{};
      final preloader = LocationChatBackgroundPreloader(
        loadFile: (url) {
          startedUrls.add(url);
          return completions.putIfAbsent(url, Completer<void>.new).future;
        },
      );

      preloader.preload([
        resource.xlUrl,
        resource.xlUrl,
        'https://cdn.example.com/location-2.webp',
        'https://cdn.example.com/location-3.webp',
      ]);
      await _flushMicrotasks();

      expect(startedUrls, hasLength(2));
      expect(preloader.activeCount, 2);
      expect(startedUrls, isNot(contains(contains('location-sm.webp'))));
      expect(
        startedUrls.first,
        'https://cdn.example.com/location-xl.webp'
        '?x-oss-process=image/resize,w_180,image/format,webp',
      );

      completions[startedUrls.first]!.complete();
      await _flushMicrotasks();

      expect(startedUrls, hasLength(3));
      expect(preloader.activeCount, 2);

      for (final completion in completions.values) {
        if (!completion.isCompleted) completion.complete();
      }
      await _flushMicrotasks();
      preloader.dispose();
    },
  );

  test(
    'a newly entered Tilemap replaces background loads not yet started',
    () async {
      final startedUrls = <String>[];
      final completions = <String, Completer<void>>{};
      final preloader = LocationChatBackgroundPreloader(
        maxConcurrent: 1,
        loadFile: (url) {
          startedUrls.add(url);
          return completions.putIfAbsent(url, Completer<void>.new).future;
        },
      );

      preloader.preload(const [
        'https://cdn.example.com/old-1.webp',
        'https://cdn.example.com/old-2.webp',
      ]);
      await _flushMicrotasks();
      expect(startedUrls, hasLength(1));

      preloader.preload(const ['https://cdn.example.com/new-1.webp']);
      completions[startedUrls.single]!.complete();
      await _flushMicrotasks();

      expect(startedUrls, hasLength(2));
      expect(startedUrls.last, contains('new-1.webp'));
      expect(startedUrls, isNot(contains(contains('old-2.webp'))));

      completions[startedUrls.last]!.complete();
      await _flushMicrotasks();
      preloader.dispose();
    },
  );

  test(
    'a failed background preview can be retried on the next entry',
    () async {
      var attempts = 0;
      final preloader = LocationChatBackgroundPreloader(
        maxConcurrent: 1,
        loadFile: (_) async {
          attempts += 1;
          if (attempts == 1) throw StateError('preload failed');
        },
      );

      preloader.preload(const ['https://cdn.example.com/retry.webp']);
      await _flushMicrotasks();
      expect(attempts, 1);

      preloader.preload(const ['https://cdn.example.com/retry.webp']);
      await _flushMicrotasks();
      expect(attempts, 2);

      preloader.dispose();
    },
  );
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
