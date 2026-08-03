import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../network/genesis_http_cache_manager.dart';
import 'location_chat_page.dart';

typedef LocationChatBackgroundFileLoader = Future<void> Function(String url);

class LocationChatBackgroundPreloader {
  LocationChatBackgroundPreloader({
    LocationChatBackgroundFileLoader? loadFile,
    this.maxConcurrent = 2,
  }) : assert(maxConcurrent > 0),
       _loadFile = loadFile ?? _loadBackgroundFile;

  final LocationChatBackgroundFileLoader _loadFile;
  final int maxConcurrent;
  final Queue<String> _pendingUrls = Queue<String>();
  final Set<String> _pendingUrlSet = <String>{};
  final Set<String> _inFlightUrls = <String>{};
  final Set<String> _completedUrls = <String>{};
  int _activeCount = 0;
  bool _disposed = false;

  @visibleForTesting
  int get activeCount => _activeCount;

  @visibleForTesting
  int get pendingCount => _pendingUrls.length;

  void preload(Iterable<Object?> imageUrls) {
    if (_disposed) return;

    final nextUrls = <String>{};
    for (final imageUrl in imageUrls) {
      final previewUrl = resolveLocationChatBackgroundPreviewUrl(
        imageUrl,
      ).trim();
      if (previewUrl.isEmpty || previewUrl.startsWith('assets/')) continue;
      nextUrls.add(previewUrl);
    }

    // A newly entered Tilemap takes priority over work that has not started.
    // Downloads already in flight are allowed to finish and populate the
    // shared file cache.
    _pendingUrls.clear();
    _pendingUrlSet.clear();
    for (final url in nextUrls) {
      if (_completedUrls.contains(url) || _inFlightUrls.contains(url)) {
        continue;
      }
      if (_pendingUrlSet.add(url)) _pendingUrls.addLast(url);
    }
    _drain();
  }

  void _drain() {
    if (_disposed) return;
    while (_activeCount < maxConcurrent && _pendingUrls.isNotEmpty) {
      final url = _pendingUrls.removeFirst();
      _pendingUrlSet.remove(url);
      if (_completedUrls.contains(url) || !_inFlightUrls.add(url)) continue;
      _activeCount += 1;
      unawaited(_load(url));
    }
  }

  Future<void> _load(String url) async {
    try {
      await _loadFile(url);
      if (!_disposed) _completedUrls.add(url);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[LocationChat] background preview preload failed '
          'url="$url": $error',
        );
      }
    } finally {
      _inFlightUrls.remove(url);
      _activeCount -= 1;
      _drain();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pendingUrls.clear();
    _pendingUrlSet.clear();
  }
}

Future<void> _loadBackgroundFile(String url) async {
  await GenesisHttpCacheManager().getSingleFile(url);
}
