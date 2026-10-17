import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/mini_phone/photos/mini_phone_photo_thumbnail.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

void main() {
  test('Photos picks the nearest of five widths, preferring larger ties', () {
    for (final (width, expected) in <(double, int)>[
      (60, 90),
      (100, 90),
      (135, 180),
      (240, 180),
      (270, 360),
      (540, 720),
      (900, 1080),
      (1500, 1080),
    ]) {
      final url = resizeGenesisImageUrl(
        'https://cdn.example/photo.png?x-oss-process=image/resize,h_200#old',
        logicalWidth: width,
        devicePixelRatio: 1,
        nearestWidthTiers: miniPhonePhotoThumbnailWidthTiers,
      );
      expect(
        url,
        'https://cdn.example/photo.png?x-oss-process=image/resize,w_$expected/format,webp',
      );
    }
  });

  test('Photos tier matching applies the global DPR cap', () {
    final url = resizeGenesisImageUrl(
      'https://cdn.example/photo-dpr.png',
      logicalWidth: 140,
      devicePixelRatio: 3,
      nearestWidthTiers: miniPhonePhotoThumbnailWidthTiers,
    );
    expect(url, contains('resize,w_360/'));
  });
}
