import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/local_image_crop_page.dart';
import 'package:genesis_flutter_android/pages/me/me_page.dart';

void main() {
  test('profile avatar crop output is capped at 1080 physical pixels', () {
    final size = calculateLocalImageCropOutputSize(
      sourceRect: const Rect.fromLTWH(0, 0, 2400, 2400),
      cropSize: meProfileAvatarUploadSize,
      maxOutputSize: meProfileAvatarUploadSize,
    );

    expect(meProfileAvatarUploadSize, const Size.square(1080));
    expect(size, (width: 1080, height: 1080));
  });

  test('profile avatar crop does not enlarge a small source', () {
    final size = calculateLocalImageCropOutputSize(
      sourceRect: const Rect.fromLTWH(0, 0, 640, 640),
      cropSize: meProfileAvatarUploadSize,
      maxOutputSize: meProfileAvatarUploadSize,
    );

    expect(size, (width: 640, height: 640));
  });
}
