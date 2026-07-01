import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'image_format_guards.dart';

const int uploadJpegQuality = 85;

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
}) {
  return prepareImageForUpload(
    bytes: bytes,
    filename: filename,
    contentType: contentType,
    maxWidth: maxWidth,
  );
}

Future<ProcessedUploadImage> prepareImageForUpload({
  required Uint8List bytes,
  required String filename,
  required String contentType,
  int maxWidth = 0,
}) async {
  throwIfGifImage(bytes: bytes, filename: filename, contentType: contentType);

  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Image decode failed');
  }

  var outputImage = img.bakeOrientation(decoded);
  final shouldKeepPng =
      _isPngImage(bytes: bytes, filename: filename, contentType: contentType) &&
      _hasTransparentPixels(outputImage);

  if (maxWidth > 0 && outputImage.width > maxWidth) {
    final targetWidth = maxWidth;
    final targetHeight = math.max(
      1,
      (outputImage.height * targetWidth / outputImage.width).round(),
    );
    outputImage = img.copyResize(
      outputImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
  }

  if (shouldKeepPng) {
    final pngBytes = Uint8List.fromList(img.encodePng(outputImage));
    return ProcessedUploadImage(
      bytes: pngBytes,
      filename: _pngFilenameFor(filename),
      contentType: 'image/png',
    );
  }

  final jpegBytes = img.encodeJpg(outputImage, quality: uploadJpegQuality);
  return ProcessedUploadImage(
    bytes: jpegBytes,
    filename: _jpegFilenameFor(filename),
    contentType: 'image/jpeg',
  );
}

String _pngFilenameFor(String filename) {
  final normalized = filename.trim();
  if (normalized.isEmpty) return 'upload.png';
  final withoutExtension = normalized.replaceFirst(RegExp(r'\.[^.]+$'), '');
  final base = withoutExtension.trim().isEmpty ? 'upload' : withoutExtension;
  return '$base.png';
}

String _jpegFilenameFor(String filename) {
  final normalized = filename.trim();
  if (normalized.isEmpty) return 'upload.jpg';
  final withoutExtension = normalized.replaceFirst(RegExp(r'\.[^.]+$'), '');
  final base = withoutExtension.trim().isEmpty ? 'upload' : withoutExtension;
  return '$base.jpg';
}

bool _isPngImage({
  required Uint8List bytes,
  required String filename,
  required String contentType,
}) {
  final normalizedContentType = contentType.trim().toLowerCase();
  final normalizedFilename = filename.trim().toLowerCase();
  return normalizedContentType == 'image/png' ||
      normalizedFilename.endsWith('.png') ||
      _isPngImageBytes(bytes);
}

bool _isPngImageBytes(Uint8List bytes) {
  const signature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}

bool _hasTransparentPixels(img.Image image) {
  if (!image.hasAlpha) return false;
  for (final pixel in image) {
    if (pixel.a < 255) return true;
  }
  return false;
}
