class GenesisImageResource {
  const GenesisImageResource({
    this.legacyUrl = '',
    this.smUrl = '',
    this.xlUrl = '',
    this.objectKey = '',
  });

  final String legacyUrl;
  final String smUrl;
  final String xlUrl;
  final String objectKey;

  bool get isEmpty =>
      legacyUrl.trim().isEmpty &&
      smUrl.trim().isEmpty &&
      xlUrl.trim().isEmpty &&
      objectKey.trim().isEmpty;

  String get displayUrl {
    final xl = xlUrl.trim();
    if (xl.isNotEmpty) return xl;
    final sm = smUrl.trim();
    if (sm.isNotEmpty) return sm;
    return legacyUrl.trim();
  }

  static GenesisImageResource fromJson(Object? raw, {Object? fallback}) {
    final parsed = _fromJson(raw);
    if (!parsed.isEmpty) return parsed;
    if (fallback == null) return parsed;
    return _fromJson(fallback);
  }

  static GenesisImageResource _fromJson(Object? raw) {
    if (raw == null) return const GenesisImageResource();
    if (raw is GenesisImageResource) return raw;
    if (raw is Map) {
      final map = raw.map((key, value) => MapEntry('$key', value));
      return GenesisImageResource(
        legacyUrl: _string(
          map['url'] ??
              map['image_url'] ??
              map['image'] ??
              map['avatar'] ??
              map['cover'],
        ),
        smUrl: _string(map['sm_url']),
        xlUrl: _string(map['xl_url']),
        objectKey: _string(map['object_key']),
      );
    }
    return GenesisImageResource(legacyUrl: raw.toString());
  }

  GenesisImageResource mapUrls(String Function(String url) resolver) {
    String resolve(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '' : resolver(trimmed);
    }

    return GenesisImageResource(
      legacyUrl: resolve(legacyUrl),
      smUrl: resolve(smUrl),
      xlUrl: resolve(xlUrl),
      objectKey: objectKey.trim(),
    );
  }

  String selectUrl({
    required double? logicalWidth,
    required double? logicalHeight,
    required double devicePixelRatio,
  }) {
    final resizedXlUrl = _resizedXlUrl(
      this,
      logicalWidth: logicalWidth,
      devicePixelRatio: devicePixelRatio,
    );
    if (resizedXlUrl.isNotEmpty) return resizedXlUrl;

    final candidates = <_ImageCandidate>[
      _ImageCandidate(smUrl.trim()),
      _ImageCandidate(xlUrl.trim()),
      _ImageCandidate(legacyUrl.trim()),
    ].where((candidate) => candidate.url.isNotEmpty).toList(growable: false);
    if (candidates.isEmpty) return '';
    if (candidates.length == 1) return candidates.single.url;

    final requiredWidth = _requiredPixels(logicalWidth, devicePixelRatio);
    final requiredHeight = _requiredPixels(logicalHeight, devicePixelRatio);
    if (requiredWidth == null && requiredHeight == null) return displayUrl;

    final sizedCandidates = candidates
        .where((candidate) => candidate.hasKnownSize)
        .toList(growable: false);
    final fitCandidates = sizedCandidates
        .where((candidate) {
          final width = candidate.width;
          final height = candidate.height;
          if (requiredWidth != null && width != null && width < requiredWidth) {
            return false;
          }
          if (requiredHeight != null &&
              height != null &&
              height < requiredHeight) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    if (fitCandidates.isNotEmpty) {
      fitCandidates.sort(_ascendingCandidateSize);
      return fitCandidates.first.url;
    }

    if (sizedCandidates.isNotEmpty) {
      sizedCandidates.sort(_descendingCandidateSize);
      return sizedCandidates.first.url;
    }

    return displayUrl;
  }

  Iterable<String> get keys sync* {
    for (final value in [legacyUrl, smUrl, xlUrl, objectKey, displayUrl]) {
      final key = value.trim();
      if (key.isNotEmpty) yield key;
    }
  }
}

const List<int> _imageResizeWidthTiers = <int>[
  45,
  90,
  180,
  360,
  720,
  1080,
  2160,
];

const String _ossResizeProcessPrefix = '?x-oss-process=image/resize,w_';
const String _ossResizeProcessSuffix = ',image/format,webp';

String _resizedXlUrl(
  GenesisImageResource resource, {
  required double? logicalWidth,
  required double devicePixelRatio,
}) {
  final xl = resource.xlUrl.trim();
  if (xl.isEmpty || xl.startsWith('assets/')) return '';
  final requiredWidth = _requiredPixels(logicalWidth, devicePixelRatio);
  if (requiredWidth == null) return '';
  final width = _ceilImageWidthTier(requiredWidth);
  return '${_stripUrlParams(xl)}$_ossResizeProcessPrefix$width$_ossResizeProcessSuffix';
}

int _ceilImageWidthTier(double requiredWidth) {
  for (final tier in _imageResizeWidthTiers) {
    if (requiredWidth < tier) return tier;
  }
  return _imageResizeWidthTiers.last;
}

String _stripUrlParams(String url) {
  final queryIndex = url.indexOf('?');
  final fragmentIndex = url.indexOf('#');
  final cutPoints = <int>[
    if (queryIndex >= 0) queryIndex,
    if (fragmentIndex >= 0) fragmentIndex,
  ];
  if (cutPoints.isEmpty) return url;
  cutPoints.sort();
  return url.substring(0, cutPoints.first);
}

class GenesisImageResourceRegistry {
  GenesisImageResourceRegistry._();

  static final Map<String, GenesisImageResource> _byKey =
      <String, GenesisImageResource>{};

  static GenesisImageResource register(GenesisImageResource resource) {
    if (resource.isEmpty) return resource;
    for (final key in resource.keys) {
      _byKey[key] = resource;
    }
    return resource;
  }

  static GenesisImageResource resolve(Object? source, {Object? fallback}) {
    if (source is String) {
      final registered = _byKey[source.trim()];
      if (registered != null) return registered;
    }
    final parsed = GenesisImageResource.fromJson(source, fallback: fallback);
    if (!parsed.isEmpty) return register(parsed);
    return parsed;
  }
}

String selectGenesisImageUrl(
  Object? source, {
  Object? fallback,
  required double? logicalWidth,
  required double? logicalHeight,
  required double devicePixelRatio,
}) {
  final resource = GenesisImageResourceRegistry.resolve(
    source,
    fallback: fallback,
  );
  return resource.selectUrl(
    logicalWidth: logicalWidth,
    logicalHeight: logicalHeight,
    devicePixelRatio: devicePixelRatio,
  );
}

double? _requiredPixels(double? logicalValue, double devicePixelRatio) {
  if (logicalValue == null || !logicalValue.isFinite || logicalValue <= 0) {
    return null;
  }
  final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  return logicalValue * ratio;
}

String _string(Object? value) {
  if (value == null) return '';
  return value.toString().trim();
}

int _ascendingCandidateSize(_ImageCandidate a, _ImageCandidate b) {
  return a.sizeScore.compareTo(b.sizeScore);
}

int _descendingCandidateSize(_ImageCandidate a, _ImageCandidate b) {
  return b.sizeScore.compareTo(a.sizeScore);
}

class _ImageCandidate {
  _ImageCandidate(this.url)
    : width = _dimensionsFromUrl(url).$1,
      height = _dimensionsFromUrl(url).$2;

  final String url;
  final int? width;
  final int? height;

  bool get hasKnownSize => width != null || height != null;

  int get sizeScore {
    final w = width ?? 0;
    final h = height ?? 0;
    if (w > 0 && h > 0) return w * h;
    return w + h;
  }
}

(int?, int?) _dimensionsFromUrl(String rawUrl) {
  final url = Uri.tryParse(rawUrl);
  if (url != null) {
    final queryWidth =
        int.tryParse(url.queryParameters['width'] ?? '') ??
        int.tryParse(url.queryParameters['w'] ?? '');
    final queryHeight =
        int.tryParse(url.queryParameters['height'] ?? '') ??
        int.tryParse(url.queryParameters['h'] ?? '');
    if (queryWidth != null || queryHeight != null) {
      return (queryWidth, queryHeight);
    }
  }

  final withoutQuery = rawUrl.split('?').first.split('#').first;
  final filename = withoutQuery.split('/').last;
  final patterns = <RegExp>[
    RegExp(r'(?:^|[_-])(\d{2,5})[xX](\d{2,5})(?=[_.-])'),
    RegExp(r'(?:^|[_-])(\d{2,5})_(\d{2,5})(?=[_.-])'),
  ];
  for (final pattern in patterns) {
    final matches = pattern.allMatches(filename).toList(growable: false);
    if (matches.isEmpty) continue;
    final match = matches.last;
    return (int.tryParse(match.group(1)!), int.tryParse(match.group(2)!));
  }
  return (null, null);
}
