import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'image_upload_processing.dart';

const int postImageMaxBytes = 10 * 1024 * 1024;

/// Native selection already bounds decoding and normalizes orientation/format.
/// Keep JPEG quality and transparency; reduce dimensions if the encoded file
/// still exceeds the byte budget. Run encoding away from the UI isolate.
Future<ProcessedUploadImage> fitPreparedUploadImage(
  ProcessedUploadImage image, {
  int maxBytes = postImageMaxBytes,
}) async {
  if (maxBytes <= 0) throw ArgumentError.value(maxBytes, 'maxBytes');
  if (image.bytes.length <= maxBytes) return image;
  return compute(_fit, (image: image, maxBytes: maxBytes));
}

ProcessedUploadImage _fit(({ProcessedUploadImage image, int maxBytes}) input) {
  final original = input.image;
  var decoded = img.decodeImage(original.bytes);
  if (decoded == null) throw const FormatException('Image decode failed');
  final png = original.contentType == 'image/png';
  var bytes = original.bytes;
  while (bytes.length > input.maxBytes) {
    if (decoded!.width == 1 && decoded.height == 1) {
      throw StateError('Image cannot fit the upload byte limit');
    }
    final scale = math.min(.9, math.sqrt(input.maxBytes / bytes.length) * .9);
    decoded = img.copyResize(
      decoded,
      width: math.max(1, (decoded.width * scale).floor()),
      height: math.max(1, (decoded.height * scale).floor()),
      interpolation: img.Interpolation.average,
    );
    bytes = Uint8List.fromList(
      png
          ? img.encodePng(decoded)
          : img.encodeJpg(decoded, quality: uploadJpegQuality),
    );
  }
  return ProcessedUploadImage(
    bytes: bytes,
    filename: original.filename,
    contentType: original.contentType,
  );
}
