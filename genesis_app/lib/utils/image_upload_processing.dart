import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'image_format_guards.dart';

class ProcessedUploadImage {
  const ProcessedUploadImage({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String contentType;
}

Future<ProcessedUploadImage> resizeImageToMaxWidth({
  required Uint8List bytes,
  required String filename,
  required String contentType,
  required int maxWidth,
}) async {
  throwIfGifImage(bytes: bytes, filename: filename, contentType: contentType);
  if (maxWidth <= 0) {
    return ProcessedUploadImage(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
  }

  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  try {
    if (image.width <= maxWidth) {
      return ProcessedUploadImage(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      );
    }

    final targetWidth = maxWidth;
    final targetHeight = math.max(
      1,
      (image.height * targetWidth / image.width).round(),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(targetWidth, targetHeight);
    final byteData = await resizedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    resizedImage.dispose();
    picture.dispose();
    final resizedBytes = byteData?.buffer.asUint8List();
    if (resizedBytes == null || resizedBytes.isEmpty) {
      throw StateError('Image resize failed');
    }
    return ProcessedUploadImage(
      bytes: resizedBytes,
      filename: _pngFilenameFor(filename),
      contentType: 'image/png',
    );
  } finally {
    image.dispose();
    codec.dispose();
  }
}

String _pngFilenameFor(String filename) {
  final normalized = filename.trim();
  if (normalized.isEmpty) return 'upload.png';
  final withoutExtension = normalized.replaceFirst(RegExp(r'\.[^.]+$'), '');
  final base = withoutExtension.trim().isEmpty ? 'upload' : withoutExtension;
  return '$base.png';
}
