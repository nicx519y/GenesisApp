import 'dart:typed_data';
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

    test('builds an OSS lfit URL with image DPR capped at 2', () {
      expect(
        resizeGenesisMessageImageUrl(
          'https://cdn-001.worldo.ai/chat/image.png?old=true#fragment',
          displaySize: const Size(300, 150),
          devicePixelRatio: 3,
        ),
        'https://cdn-001.worldo.ai/chat/image.png'
        '?x-oss-process=image/resize,m_lfit,w_720,h_1440/format,webp',
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

  group('encoded image dimensions', () {
    test('reads a 48MP JPEG header without decoding pixels', () {
      expect(
        genesisMessageImageSizeFromEncodedBytes(
          _jpegHeader(width: 8000, height: 6000),
        ),
        const Size(8000, 6000),
      );
    });

    test('reads a 48MP PNG header without decoding pixels', () {
      expect(
        genesisMessageImageSizeFromEncodedBytes(
          _pngHeader(width: 8000, height: 6000),
        ),
        const Size(8000, 6000),
      );
    });

    test('swaps JPEG dimensions for EXIF orientation 6', () {
      expect(
        genesisMessageImageSizeFromEncodedBytes(
          _jpegHeader(width: 8000, height: 6000, orientation: 6),
        ),
        const Size(6000, 8000),
      );
    });

    test('reads WebP VP8X dimensions from its canvas header', () {
      expect(
        genesisMessageImageSizeFromEncodedBytes(
          Uint8List.fromList(<int>[
            0x52, 0x49, 0x46, 0x46, // RIFF
            0x16, 0x00, 0x00, 0x00, // Remaining RIFF size
            0x57, 0x45, 0x42, 0x50, // WEBP
            0x56, 0x50, 0x38, 0x58, // VP8X
            0x0a, 0x00, 0x00, 0x00, // Chunk size
            0x00, 0x00, 0x00, 0x00, // Flags and reserved
            0x3f, 0x1f, 0x00, // Canvas width minus one
            0x6f, 0x17, 0x00, // Canvas height minus one
          ]),
        ),
        const Size(8000, 6000),
      );
    });

    test('reads GIF89a logical screen dimensions', () {
      expect(
        genesisMessageImageSizeFromEncodedBytes(
          Uint8List.fromList(<int>[
            0x47,
            0x49,
            0x46,
            0x38,
            0x39,
            0x61,
            0x40,
            0x01,
            0x80,
            0x02,
            0x00,
            0x00,
            0x00,
          ]),
        ),
        const Size(320, 640),
      );
    });

    test('rejects truncated and malformed headers', () {
      expect(
        genesisMessageImageSizeFromEncodedBytes(
          Uint8List.fromList(<int>[
            0xff,
            0xd8,
            0xff,
            0xc0,
            0x00,
            0x11,
            0x08,
            0x17,
            0x70,
          ]),
        ),
        isNull,
      );
      expect(
        genesisMessageImageSizeFromEncodedBytes(
          Uint8List.fromList(<int>[
            0x89,
            0x50,
            0x4e,
            0x47,
            0x0d,
            0x0a,
            0x1a,
            0x0a,
          ]),
        ),
        isNull,
      );
      expect(
        genesisMessageImageSizeFromEncodedBytes(
          Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03]),
        ),
        isNull,
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

Uint8List _jpegHeader({
  required int width,
  required int height,
  int? orientation,
}) {
  final bytes = <int>[0xff, 0xd8];
  if (orientation != null) {
    final exif = <int>[
      0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // Exif\0\0
      0x4d, 0x4d, 0x00, 0x2a, // Big-endian TIFF header
      0x00, 0x00, 0x00, 0x08, // First IFD offset
      0x00, 0x01, // Entry count
      0x01, 0x12, // Orientation tag
      0x00, 0x03, // SHORT
      0x00, 0x00, 0x00, 0x01, // One value
      0x00, orientation, 0x00, 0x00,
    ];
    bytes
      ..addAll(<int>[0xff, 0xe1])
      ..addAll(_uint16BigEndian(exif.length + 2))
      ..addAll(exif);
  }
  bytes
    ..addAll(<int>[0xff, 0xc0, 0x00, 0x11, 0x08])
    ..addAll(_uint16BigEndian(height))
    ..addAll(_uint16BigEndian(width))
    ..addAll(<int>[
      0x03,
      0x01,
      0x11,
      0x00,
      0x02,
      0x11,
      0x00,
      0x03,
      0x11,
      0x00,
      0xff,
      0xda,
      0x00,
      0x0c,
      0x03,
      0x01,
      0x00,
      0x02,
      0x00,
      0x03,
      0x00,
      0x00,
      0x3f,
      0x00,
    ]);
  return Uint8List.fromList(bytes);
}

Uint8List _pngHeader({required int width, required int height}) {
  return Uint8List.fromList(<int>[
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    0x00,
    0x00,
    0x00,
    0x0d,
    0x49,
    0x48,
    0x44,
    0x52,
    ..._uint32BigEndian(width),
    ..._uint32BigEndian(height),
    0x08,
    0x02,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
  ]);
}

List<int> _uint16BigEndian(int value) {
  return <int>[(value >> 8) & 0xff, value & 0xff];
}

List<int> _uint32BigEndian(int value) {
  return <int>[
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}
