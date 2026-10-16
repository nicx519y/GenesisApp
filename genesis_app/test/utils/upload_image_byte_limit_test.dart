import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:genesis_flutter_android/utils/image_upload_processing.dart';
import 'package:genesis_flutter_android/utils/upload_image_byte_limit.dart';

void main() {
  test(
    'small prepared images remain byte-identical without reencoding',
    () async {
      final image = ProcessedUploadImage(
        bytes: Uint8List.fromList(
          img.encodeJpg(img.Image(width: 20, height: 10), quality: 90),
        ),
        filename: 'small.jpg',
        contentType: 'image/jpeg',
      );
      expect(await fitPreparedUploadImage(image), same(image));
    },
  );

  test(
    'transparent PNG larger than 10 MiB shrinks below the actual cap',
    () async {
      final random = Random(42);
      final pixels = img.Image(width: 1700, height: 1700, numChannels: 4);
      for (final pixel in pixels) {
        pixel.setRgba(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(255),
        );
      }
      final input = ProcessedUploadImage(
        bytes: Uint8List.fromList(img.encodePng(pixels)),
        filename: 'alpha.png',
        contentType: 'image/png',
      );
      expect(input.bytes.length, greaterThan(postImageMaxBytes));
      final result = await fitPreparedUploadImage(input);
      expect(result.bytes.length, lessThanOrEqualTo(postImageMaxBytes));
      expect(result.contentType, 'image/png');
      final decoded = img.decodePng(result.bytes)!;
      expect(decoded.width, lessThan(pixels.width));
      expect(decoded.width, decoded.height);
      expect(decoded.hasAlpha, isTrue);
      expect(decoded.any((p) => p.a < 255), isTrue);
    },
  );

  test(
    'JPEG byte fallback reduces dimensions and retains JPEG quality 90',
    () async {
      final random = Random(42);
      final pixels = img.Image(width: 600, height: 300);
      for (final pixel in pixels) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      final input = ProcessedUploadImage(
        bytes: Uint8List.fromList(img.encodeJpg(pixels, quality: 90)),
        filename: 'opaque.jpg',
        contentType: 'image/jpeg',
      );
      final result = await fitPreparedUploadImage(input, maxBytes: 24 * 1024);
      expect(result.bytes.length, lessThanOrEqualTo(24 * 1024));
      expect(result.contentType, 'image/jpeg');
      final decoded = img.decodeJpg(result.bytes)!;
      expect(decoded.width, lessThan(600));
      expect(decoded.width / decoded.height, closeTo(2, .03));
      // The output encoder uses the same quality table as a fresh Q90 encoding.
      expect(img.JpegDecoder().decode(result.bytes), isNotNull);
    },
  );
}
