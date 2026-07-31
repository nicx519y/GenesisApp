import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable, visibleForTesting;

import '../network/genesis_http_cache_manager.dart';

const List<int> genesisMessageImageWidthTiers = <int>[
  45,
  90,
  180,
  360,
  720,
  1080,
  1440,
  2160,
  2880,
  4320,
];

@immutable
class GenesisMessageImageTier {
  const GenesisMessageImageTier(this.width);

  final int width;

  int get height => width * 2;
}

typedef GenesisMessageImageInfoLoader =
    Future<Object?> Function(String infoUrl);
typedef GenesisMessageImageOriginalSizeLoader =
    Future<ui.Size?> Function(String imageUrl);

@visibleForTesting
GenesisMessageImageInfoLoader? debugGenesisMessageImageInfoLoader;

@visibleForTesting
GenesisMessageImageOriginalSizeLoader?
debugGenesisMessageImageOriginalSizeLoader;

final Map<String, Future<ui.Size?>> _messageImageSizeRequests =
    <String, Future<ui.Size?>>{};

ui.Size fitGenesisMessageImageSize({
  required ui.Size sourceSize,
  required double maxWidth,
}) {
  if (!_validDimension(sourceSize.width) ||
      !_validDimension(sourceSize.height) ||
      !_validDimension(maxWidth)) {
    return ui.Size.zero;
  }
  final maxHeight = maxWidth * 2;
  final scale = math.min(
    1,
    math.min(maxWidth / sourceSize.width, maxHeight / sourceSize.height),
  );
  return ui.Size(sourceSize.width * scale, sourceSize.height * scale);
}

GenesisMessageImageTier selectGenesisMessageImageTier({
  required ui.Size displaySize,
  required double devicePixelRatio,
}) {
  final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  final requiredTierWidth = math.max(
    displaySize.width * ratio,
    displaySize.height * ratio / 2,
  );
  for (final width in genesisMessageImageWidthTiers) {
    if (requiredTierWidth <= width) {
      return GenesisMessageImageTier(width);
    }
  }
  return GenesisMessageImageTier(genesisMessageImageWidthTiers.last);
}

String resizeGenesisMessageImageUrl(
  String source, {
  required ui.Size displaySize,
  required double devicePixelRatio,
}) {
  final normalized = source.trim();
  if (normalized.isEmpty ||
      normalized.startsWith('assets/') ||
      !isGenesisMessageImageOssUrl(normalized)) {
    return normalized;
  }
  final tier = selectGenesisMessageImageTier(
    displaySize: displaySize,
    devicePixelRatio: devicePixelRatio,
  );
  final baseUrl = _stripUrlParams(normalized);
  return '$baseUrl?x-oss-process='
      'image/resize,m_lfit,w_${tier.width},h_${tier.height}/format,webp';
}

bool isGenesisMessageImageOssUrl(String source) {
  final uri = Uri.tryParse(source.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
  final host = uri.host.toLowerCase();
  if (uri.queryParameters.containsKey('x-oss-process')) return true;
  return host.endsWith('.aliyuncs.com') ||
      host.contains('.oss-') ||
      host == 'cdn.worldo.ai' ||
      (host.startsWith('cdn-') && host.endsWith('.worldo.ai'));
}

ui.Size? genesisMessageImageSizeFromUrl(String source) {
  final uri = Uri.tryParse(source.trim());
  if (uri != null) {
    final width =
        double.tryParse(uri.queryParameters['width'] ?? '') ??
        double.tryParse(uri.queryParameters['w'] ?? '');
    final height =
        double.tryParse(uri.queryParameters['height'] ?? '') ??
        double.tryParse(uri.queryParameters['h'] ?? '');
    if (_validDimension(width) && _validDimension(height)) {
      return ui.Size(width!, height!);
    }
  }

  final filename = _stripUrlParams(source).split('/').last;
  final patterns = <RegExp>[
    RegExp(r'(?:^|[_-])(\d{2,5})[xX](\d{2,5})(?=[_.-])'),
    RegExp(r'(?:^|[_-])(\d{2,5})_(\d{2,5})(?=[_.-])'),
  ];
  for (final pattern in patterns) {
    final matches = pattern.allMatches(filename).toList(growable: false);
    if (matches.isEmpty) continue;
    final match = matches.last;
    final width = double.tryParse(match.group(1)!);
    final height = double.tryParse(match.group(2)!);
    if (_validDimension(width) && _validDimension(height)) {
      return ui.Size(width!, height!);
    }
  }
  return null;
}

Future<ui.Size?> resolveGenesisMessageImageSourceSize(String source) {
  final normalized = source.trim();
  if (normalized.isEmpty || normalized.startsWith('assets/')) {
    return Future<ui.Size?>.value(null);
  }
  final fromUrl = genesisMessageImageSizeFromUrl(normalized);
  if (fromUrl != null) return Future<ui.Size?>.value(fromUrl);
  final cacheKey = _stripUrlParams(normalized);
  final request = _messageImageSizeRequests.putIfAbsent(
    cacheKey,
    () => _resolveRemoteMessageImageSourceSize(normalized),
  );
  request.then((size) {
    if (size == null &&
        identical(_messageImageSizeRequests[cacheKey], request)) {
      _messageImageSizeRequests.remove(cacheKey);
    }
  });
  return request;
}

Future<ui.Size?> _resolveRemoteMessageImageSourceSize(String source) async {
  if (isGenesisMessageImageOssUrl(source)) {
    try {
      final info = await _loadMessageImageInfo(
        '${_stripUrlParams(source)}?x-oss-process=image/info',
      );
      final size = _sizeFromImageInfo(info);
      if (size != null) return size;
    } catch (_) {
      // Fall back to decoding the original image below.
    }
  }
  try {
    final override = debugGenesisMessageImageOriginalSizeLoader;
    if (override != null) return override(source);
    final file = await GenesisHttpCacheManager()
        .getSingleFile(source)
        .timeout(const Duration(seconds: 10));
    final bytes = await file.readAsBytes();
    return genesisMessageImageSizeFromEncodedBytes(bytes);
  } catch (_) {
    return null;
  }
}

/// Reads dimensions from encoded image headers without decoding image pixels.
///
/// Message images can be tens of megapixels. Using Flutter's image codec just
/// to read their dimensions would allocate the full decoded image and can
/// exhaust the process heap. The supported formats below all expose dimensions
/// in a bounded header structure, so no width-by-height pixel buffer is needed.
ui.Size? genesisMessageImageSizeFromEncodedBytes(Uint8List bytes) {
  try {
    final dimensions =
        _jpegDimensions(bytes) ??
        _pngDimensions(bytes) ??
        _webPDimensions(bytes) ??
        _gifDimensions(bytes);
    if (dimensions == null || dimensions.width <= 0 || dimensions.height <= 0) {
      return null;
    }
    return ui.Size(dimensions.width.toDouble(), dimensions.height.toDouble());
  } catch (_) {
    return null;
  }
}

_EncodedImageDimensions? _jpegDimensions(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) {
    return null;
  }

  var offset = 2;
  int? width;
  int? height;
  int? orientation;
  while (offset < bytes.length) {
    if (bytes[offset] != 0xff) return null;
    while (offset < bytes.length && bytes[offset] == 0xff) {
      offset += 1;
    }
    if (offset >= bytes.length) return null;

    final marker = bytes[offset];
    offset += 1;
    if (marker == 0xd9) return null;
    if (marker == 0x00) return null;
    if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      continue;
    }
    if (!_hasBytes(bytes, offset, 2)) return null;
    final segmentLength = _readUint16BigEndian(bytes, offset);
    if (segmentLength < 2) return null;
    final segmentDataOffset = offset + 2;
    final segmentDataLength = segmentLength - 2;
    if (!_hasBytes(bytes, segmentDataOffset, segmentDataLength)) return null;

    if (marker == 0xda) {
      if (width == null || height == null || segmentDataLength < 6) {
        return null;
      }
      final componentCount = bytes[segmentDataOffset];
      if (componentCount <= 0 ||
          segmentDataLength < 1 + componentCount * 2 + 3) {
        return null;
      }
      break;
    }
    if (_isJpegStartOfFrame(marker)) {
      if (segmentDataLength < 6) return null;
      final componentCount = bytes[segmentDataOffset + 5];
      if (componentCount <= 0 || segmentDataLength < 6 + componentCount * 3) {
        return null;
      }
      height = _readUint16BigEndian(bytes, segmentDataOffset + 1);
      width = _readUint16BigEndian(bytes, segmentDataOffset + 3);
      if (width <= 0 || height <= 0) return null;
    } else if (marker == 0xe1) {
      orientation ??= _jpegExifOrientation(
        bytes,
        segmentDataOffset,
        segmentDataLength,
      );
    }
    offset = segmentDataOffset + segmentDataLength;
  }

  if (width == null || height == null) return null;
  final swapsAxes = orientation != null && orientation >= 5 && orientation <= 8;
  return _EncodedImageDimensions(
    swapsAxes ? height : width,
    swapsAxes ? width : height,
  );
}

bool _isJpegStartOfFrame(int marker) {
  return marker >= 0xc0 &&
      marker <= 0xcf &&
      marker != 0xc4 &&
      marker != 0xc8 &&
      marker != 0xcc;
}

int? _jpegExifOrientation(Uint8List bytes, int offset, int length) {
  const exifSignature = <int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
  if (length < exifSignature.length + 8) return null;
  for (var index = 0; index < exifSignature.length; index += 1) {
    if (bytes[offset + index] != exifSignature[index]) return null;
  }

  final tiffOffset = offset + exifSignature.length;
  final tiffLength = length - exifSignature.length;
  final littleEndian =
      bytes[tiffOffset] == 0x49 && bytes[tiffOffset + 1] == 0x49;
  final bigEndian = bytes[tiffOffset] == 0x4d && bytes[tiffOffset + 1] == 0x4d;
  if (!littleEndian && !bigEndian) return null;
  if (_readUint16(bytes, tiffOffset + 2, littleEndian) != 42) return null;

  final ifdRelativeOffset = _readUint32(bytes, tiffOffset + 4, littleEndian);
  if (ifdRelativeOffset > tiffLength - 2) return null;
  final ifdOffset = tiffOffset + ifdRelativeOffset;
  final entryCount = _readUint16(bytes, ifdOffset, littleEndian);
  final entriesOffset = ifdOffset + 2;
  if (entryCount > (tiffOffset + tiffLength - entriesOffset) ~/ 12) {
    return null;
  }

  for (var index = 0; index < entryCount; index += 1) {
    final entryOffset = entriesOffset + index * 12;
    final tag = _readUint16(bytes, entryOffset, littleEndian);
    if (tag != 0x0112) continue;
    final type = _readUint16(bytes, entryOffset + 2, littleEndian);
    final count = _readUint32(bytes, entryOffset + 4, littleEndian);
    if (type != 3 || count == 0) return null;

    int valueOffset;
    if (count == 1) {
      valueOffset = entryOffset + 8;
    } else {
      final relativeValueOffset = _readUint32(
        bytes,
        entryOffset + 8,
        littleEndian,
      );
      if (relativeValueOffset > tiffLength - 2) return null;
      valueOffset = tiffOffset + relativeValueOffset;
    }
    final orientation = _readUint16(bytes, valueOffset, littleEndian);
    return orientation >= 1 && orientation <= 8 ? orientation : null;
  }
  return null;
}

_EncodedImageDimensions? _pngDimensions(Uint8List bytes) {
  const signature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 33) return null;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return null;
  }
  if (_readUint32BigEndian(bytes, 8) != 13 ||
      bytes[12] != 0x49 ||
      bytes[13] != 0x48 ||
      bytes[14] != 0x44 ||
      bytes[15] != 0x52) {
    return null;
  }
  return _EncodedImageDimensions(
    _readUint32BigEndian(bytes, 16),
    _readUint32BigEndian(bytes, 20),
  );
}

_EncodedImageDimensions? _webPDimensions(Uint8List bytes) {
  if (bytes.length < 20 ||
      !_matchesAscii(bytes, 0, 'RIFF') ||
      !_matchesAscii(bytes, 8, 'WEBP')) {
    return null;
  }
  final riffSize = _readUint32LittleEndian(bytes, 4);
  if (riffSize < 12 || riffSize > bytes.length - 8) return null;
  final chunkSize = _readUint32LittleEndian(bytes, 16);
  if (chunkSize > bytes.length - 20 || chunkSize > riffSize - 12) return null;
  if (_matchesAscii(bytes, 12, 'VP8X') &&
      chunkSize >= 10 &&
      bytes.length >= 30) {
    return _EncodedImageDimensions(
      1 + _readUint24LittleEndian(bytes, 24),
      1 + _readUint24LittleEndian(bytes, 27),
    );
  }
  if (_matchesAscii(bytes, 12, 'VP8 ') &&
      chunkSize >= 10 &&
      bytes.length >= 30 &&
      bytes[23] == 0x9d &&
      bytes[24] == 0x01 &&
      bytes[25] == 0x2a) {
    return _EncodedImageDimensions(
      _readUint16LittleEndian(bytes, 26) & 0x3fff,
      _readUint16LittleEndian(bytes, 28) & 0x3fff,
    );
  }
  if (_matchesAscii(bytes, 12, 'VP8L') &&
      chunkSize >= 5 &&
      bytes.length >= 25 &&
      bytes[20] == 0x2f) {
    final packed = _readUint32LittleEndian(bytes, 21);
    return _EncodedImageDimensions(
      1 + (packed & 0x3fff),
      1 + ((packed >> 14) & 0x3fff),
    );
  }
  return null;
}

_EncodedImageDimensions? _gifDimensions(Uint8List bytes) {
  if (bytes.length < 13 ||
      (!_matchesAscii(bytes, 0, 'GIF87a') &&
          !_matchesAscii(bytes, 0, 'GIF89a'))) {
    return null;
  }
  return _EncodedImageDimensions(
    _readUint16LittleEndian(bytes, 6),
    _readUint16LittleEndian(bytes, 8),
  );
}

bool _hasBytes(Uint8List bytes, int offset, int length) {
  return offset >= 0 && length >= 0 && offset <= bytes.length - length;
}

bool _matchesAscii(Uint8List bytes, int offset, String value) {
  if (!_hasBytes(bytes, offset, value.length)) return false;
  for (var index = 0; index < value.length; index += 1) {
    if (bytes[offset + index] != value.codeUnitAt(index)) return false;
  }
  return true;
}

int _readUint16BigEndian(Uint8List bytes, int offset) {
  return (bytes[offset] << 8) | bytes[offset + 1];
}

int _readUint32BigEndian(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

int _readUint16LittleEndian(Uint8List bytes, int offset) {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

int _readUint24LittleEndian(Uint8List bytes, int offset) {
  return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
}

int _readUint32LittleEndian(Uint8List bytes, int offset) {
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

int _readUint16(Uint8List bytes, int offset, bool littleEndian) {
  return littleEndian
      ? _readUint16LittleEndian(bytes, offset)
      : _readUint16BigEndian(bytes, offset);
}

int _readUint32(Uint8List bytes, int offset, bool littleEndian) {
  return littleEndian
      ? _readUint32LittleEndian(bytes, offset)
      : _readUint32BigEndian(bytes, offset);
}

class _EncodedImageDimensions {
  const _EncodedImageDimensions(this.width, this.height);

  final int width;
  final int height;
}

Future<Object?> _loadMessageImageInfo(String infoUrl) async {
  final override = debugGenesisMessageImageInfoLoader;
  if (override != null) return override(infoUrl);
  final file = await GenesisHttpCacheManager()
      .getSingleFile(infoUrl)
      .timeout(const Duration(seconds: 5));
  return jsonDecode(await file.readAsString());
}

ui.Size? _sizeFromImageInfo(Object? raw) {
  if (raw is! Map) return null;
  final width = _nestedImageInfoValue(raw, 'ImageWidth');
  final height = _nestedImageInfoValue(raw, 'ImageHeight');
  if (!_validDimension(width) || !_validDimension(height)) return null;
  return ui.Size(width!, height!);
}

double? _nestedImageInfoValue(Map<dynamic, dynamic> raw, String key) {
  final field = raw[key];
  if (field is Map) return double.tryParse('${field['value'] ?? ''}');
  return double.tryParse('${field ?? ''}');
}

bool _validDimension(double? value) {
  return value != null && value.isFinite && value > 0;
}

String _stripUrlParams(String source) {
  final queryIndex = source.indexOf('?');
  final fragmentIndex = source.indexOf('#');
  final cutPoints = <int>[
    if (queryIndex >= 0) queryIndex,
    if (fragmentIndex >= 0) fragmentIndex,
  ]..sort();
  return cutPoints.isEmpty ? source : source.substring(0, cutPoints.first);
}

@visibleForTesting
void clearGenesisMessageImageSizeCache() {
  _messageImageSizeRequests.clear();
}
