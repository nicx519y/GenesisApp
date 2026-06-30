import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/utils/image_format_guards.dart';
import 'package:genesis_flutter_android/utils/image_upload_processing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resizeImageToMaxWidth keeps images within max width unchanged',
    () async {
      final bytes = await _solidPng(width: 400, height: 300);

      final result = await resizeImageToMaxWidth(
        bytes: bytes,
        filename: 'small.jpg',
        contentType: 'image/jpeg',
        maxWidth: 800,
      );

      expect(result.bytes, same(bytes));
      expect(result.filename, 'small.jpg');
      expect(result.contentType, 'image/jpeg');
    },
  );

  test('resizeImageToMaxWidth scales wide images proportionally', () async {
    final bytes = await _solidPng(width: 1200, height: 600);

    final result = await resizeImageToMaxWidth(
      bytes: bytes,
      filename: 'wide.jpg',
      contentType: 'image/jpeg',
      maxWidth: 800,
    );

    final size = await _decodeSize(result.bytes);
    expect(size.width, 800);
    expect(size.height, 400);
    expect(result.filename, 'wide.png');
    expect(result.contentType, 'image/png');
  });

  test('resizeImageToMaxWidth rejects GIF uploads', () async {
    final bytes = Uint8List.fromList('GIF89a'.codeUnits);

    await expectLater(
      resizeImageToMaxWidth(
        bytes: bytes,
        filename: 'animated.gif',
        contentType: 'image/gif',
        maxWidth: 800,
      ),
      throwsA(isA<UnsupportedGifImageException>()),
    );
    expect(unsupportedGifImageMessage, 'GIF animations are not supported.');
  });
}

Future<Uint8List> _solidPng({required int width, required int height}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF198B64),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  final bytes = byteData?.buffer.asUint8List();
  if (bytes == null || bytes.isEmpty) {
    throw StateError('Failed to create test image');
  }
  return bytes;
}

Future<({int width, int height})> _decodeSize(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    return (width: image.width, height: image.height);
  } finally {
    image.dispose();
    codec.dispose();
  }
}
