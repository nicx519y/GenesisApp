import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

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
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        if (image.width <= 0 || image.height <= 0) return null;
        return ui.Size(image.width.toDouble(), image.height.toDouble());
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
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
