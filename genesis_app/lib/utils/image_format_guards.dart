import 'dart:typed_data';

const String unsupportedGifImageMessage = 'GIF animations are not supported.';

class UnsupportedGifImageException implements Exception {
  const UnsupportedGifImageException();

  @override
  String toString() => unsupportedGifImageMessage;
}

bool isGifImageBytes(Uint8List bytes) {
  if (bytes.length < 6) return false;
  return _matchesAscii(bytes, 'GIF87a') || _matchesAscii(bytes, 'GIF89a');
}

void throwIfGifImage({
  required Uint8List bytes,
  String filename = '',
  String contentType = '',
}) {
  final normalizedContentType = contentType.trim().toLowerCase();
  final normalizedFilename = filename.trim().toLowerCase();
  if (normalizedContentType == 'image/gif' ||
      normalizedFilename.endsWith('.gif') ||
      isGifImageBytes(bytes)) {
    throw const UnsupportedGifImageException();
  }
}

bool _matchesAscii(Uint8List bytes, String value) {
  if (bytes.length < value.length) return false;
  for (var index = 0; index < value.length; index += 1) {
    if (bytes[index] != value.codeUnitAt(index)) return false;
  }
  return true;
}
