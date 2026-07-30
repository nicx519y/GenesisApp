import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/genesis_message_image.dart';

void main() {
  tearDown(() {
    debugGenesisMessageImageInfoLoader = null;
    debugGenesisMessageImageOriginalSizeLoader = null;
    clearGenesisMessageImageSizeCache();
  });

  group('fitGenesisMessageImageSize', () {
    test('keeps an image at its original size inside the bounds', () {
      expect(
        fitGenesisMessageImageSize(
          sourceSize: const Size(120, 240),
          maxWidth: 300,
        ),
        const Size(120, 240),
      );
    });

    test('scales a wide image down to max width', () {
      expect(
        fitGenesisMessageImageSize(
          sourceSize: const Size(1200, 600),
          maxWidth: 300,
        ),
        const Size(300, 150),
      );
    });

    test('scales a tall image down to twice max width', () {
      expect(
        fitGenesisMessageImageSize(
          sourceSize: const Size(200, 2000),
          maxWidth: 300,
        ),
        const Size(60, 600),
      );
    });

    test('does not upscale a small image', () {
      expect(
        fitGenesisMessageImageSize(
          sourceSize: const Size(30, 60),
          maxWidth: 300,
        ),
        const Size(30, 60),
      );
    });
  });

  group('message image tiers', () {
    test('keeps an exact tier instead of jumping to the next tier', () {
      expect(
        selectGenesisMessageImageTier(
          displaySize: const Size(360, 100),
          devicePixelRatio: 1,
        ).width,
        360,
      );
    });

    test('uses both rendered width and rendered height', () {
      expect(
        selectGenesisMessageImageTier(
          displaySize: const Size(60, 600),
          devicePixelRatio: 2,
        ).width,
        720,
      );
    });

    test('caps requests at the largest tier', () {
      final tier = selectGenesisMessageImageTier(
        displaySize: const Size(5000, 10000),
        devicePixelRatio: 2,
      );
      expect(tier.width, 4320);
      expect(tier.height, 8640);
    });

    test('builds an OSS lfit URL with the selected two-dimensional tier', () {
      expect(
        resizeGenesisMessageImageUrl(
          'https://cdn-001.worldo.ai/chat/image.png?old=true#fragment',
          displaySize: const Size(300, 150),
          devicePixelRatio: 3,
        ),
        'https://cdn-001.worldo.ai/chat/image.png'
        '?x-oss-process=image/resize,m_lfit,w_1080,h_2160/format,webp',
      );
    });

    test('does not add OSS parameters to an unrelated host', () {
      const source = 'https://images.example.com/chat/image.png';
      expect(
        resizeGenesisMessageImageUrl(
          source,
          displaySize: const Size(300, 150),
          devicePixelRatio: 3,
        ),
        source,
      );
    });
  });

  group('remote source dimensions', () {
    test(
      'reads dimensions embedded in the URL without a network call',
      () async {
        var infoCalls = 0;
        debugGenesisMessageImageInfoLoader = (_) async {
          infoCalls += 1;
          return null;
        };

        expect(
          await resolveGenesisMessageImageSourceSize(
            'https://images.example.com/opening_320x640.webp',
          ),
          const Size(320, 640),
        );
        expect(infoCalls, 0);
      },
    );

    test('loads and caches OSS image info', () async {
      var infoCalls = 0;
      debugGenesisMessageImageInfoLoader = (url) async {
        infoCalls += 1;
        expect(
          url,
          'https://cdn-001.worldo.ai/chat/opening.webp'
          '?x-oss-process=image/info',
        );
        return {
          'ImageWidth': {'value': '400'},
          'ImageHeight': {'value': '900'},
        };
      };
      const source =
          'https://cdn-001.worldo.ai/chat/opening.webp?old=true#fragment';

      expect(
        await resolveGenesisMessageImageSourceSize(source),
        const Size(400, 900),
      );
      expect(
        await resolveGenesisMessageImageSourceSize(source),
        const Size(400, 900),
      );
      expect(infoCalls, 1);
    });

    test(
      'falls back to original image dimensions when OSS info fails',
      () async {
        var originalCalls = 0;
        debugGenesisMessageImageInfoLoader = (_) async {
          throw StateError('metadata unavailable');
        };
        debugGenesisMessageImageOriginalSizeLoader = (url) async {
          originalCalls += 1;
          expect(url, 'https://cdn-001.worldo.ai/chat/opening.webp');
          return const Size(240, 480);
        };

        expect(
          await resolveGenesisMessageImageSourceSize(
            'https://cdn-001.worldo.ai/chat/opening.webp',
          ),
          const Size(240, 480),
        );
        expect(originalCalls, 1);
      },
    );

    test('does not permanently cache a failed size lookup', () async {
      var originalCalls = 0;
      debugGenesisMessageImageInfoLoader = (_) async {
        throw StateError('metadata unavailable');
      };
      debugGenesisMessageImageOriginalSizeLoader = (_) async {
        originalCalls += 1;
        return originalCalls == 1 ? null : const Size(200, 400);
      };
      const source = 'https://cdn-001.worldo.ai/chat/retry.webp';

      expect(await resolveGenesisMessageImageSourceSize(source), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(
        await resolveGenesisMessageImageSourceSize(source),
        const Size(200, 400),
      );
      expect(originalCalls, 2);
    });
  });
}
