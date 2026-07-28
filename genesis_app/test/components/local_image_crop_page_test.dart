import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/local_image_crop_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('calculateLocalImageCropOutputSize', () {
    test('caps a large crop at the opt-in maximum', () {
      final size = calculateLocalImageCropOutputSize(
        sourceRect: const Rect.fromLTWH(0, 0, 1800, 1800),
        cropSize: const Size.square(1080),
        maxOutputSize: const Size.square(1080),
      );

      expect(size, (width: 1080, height: 1080));
    });

    test('does not upscale a small crop with the opt-in maximum', () {
      final size = calculateLocalImageCropOutputSize(
        sourceRect: const Rect.fromLTWH(0, 0, 320, 320),
        cropSize: const Size.square(1080),
        maxOutputSize: const Size.square(1080),
      );

      expect(size, (width: 320, height: 320));
    });

    test('keeps legacy crop sizing when no maximum is provided', () {
      final size = calculateLocalImageCropOutputSize(
        sourceRect: const Rect.fromLTWH(0, 0, 320, 320),
        cropSize: const Size.square(800),
      );

      expect(size, (width: 800, height: 800));
    });
  });

  test('writes a large square crop at 1080 physical pixels', () async {
    final image = await _solidImage(1200, 1200);
    addTearDown(image.dispose);

    final result = await createLocalImageCropResult(
      image: image,
      sourceRect: const Rect.fromLTWH(0, 0, 1200, 1200),
      cropSize: const Size.square(1080),
      maxOutputSize: const Size.square(1080),
      filename: 'avatar.png',
      contentType: 'image/png',
    );

    expect((result.width, result.height), (1080, 1080));
    expect(await _decodeSize(result.bytes), const Size.square(1080));
  });

  test('writes a small square crop without upscaling', () async {
    final image = await _solidImage(320, 320);
    addTearDown(image.dispose);

    final result = await createLocalImageCropResult(
      image: image,
      sourceRect: const Rect.fromLTWH(0, 0, 320, 320),
      cropSize: const Size.square(1080),
      maxOutputSize: const Size.square(1080),
      filename: 'avatar.png',
      contentType: 'image/png',
    );

    expect((result.width, result.height), (320, 320));
    expect(await _decodeSize(result.bytes), const Size.square(320));
  });
}

Future<ui.Image> _solidImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF338960),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Future<Size> _decodeSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final size = Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  codec.dispose();
  return size;
}
