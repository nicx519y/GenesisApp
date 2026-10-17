import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../network/genesis_http_cache_manager.dart';
import '../../../../network/models/miniphone_info.dart';

class CachedMiniPhoneWallpaper {
  const CachedMiniPhoneWallpaper(this.info, this.bytes);
  final MiniphoneInfo info;
  final Uint8List? bytes;
}

abstract interface class MiniPhoneWallpaperCache {
  Future<CachedMiniPhoneWallpaper?> read(String owner, String worldId);
  Future<Uint8List> loadImage(String url);
  Future<void> writeImage(String url, Uint8List bytes, String contentType);
  Future<void> write(String owner, String worldId, MiniphoneInfo info);
}

/// Metadata is account/environment scoped; image files use the app's existing
/// disk cache and HTTP transport. Cache reads never require a network request.
class LocalMiniPhoneWallpaperCache implements MiniPhoneWallpaperCache {
  LocalMiniPhoneWallpaperCache({
    required this.namespace,
    BaseCacheManager? images,
    Future<SharedPreferences> Function()? preferences,
  }) : _images = images ?? GenesisHttpCacheManager(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  final String namespace;
  final BaseCacheManager _images;
  final Future<SharedPreferences> Function() _preferences;

  String _key(String owner) =>
      'miniphone_wallpaper_v1:${Uri.encodeComponent(namespace)}:${Uri.encodeComponent(owner)}';

  @override
  Future<CachedMiniPhoneWallpaper?> read(String owner, String worldId) async {
    final prefs = await _preferences();
    final key = _key(owner);
    final background = prefs.getString('$key:background');
    if (background == null) return null;
    final raw = prefs.getString(
      '$key:catalogue:${Uri.encodeComponent(worldId)}',
    );
    final info = MiniphoneInfo.fromJson({
      'background_image': background,
      'default_background_images': raw == null ? [] : jsonDecode(raw),
    });
    Uint8List? bytes;
    if (background.isNotEmpty) {
      try {
        final cached = await _images.getFileFromCache(background);
        if (cached != null) {
          bytes = await cached.file.readAsBytes();
          await _validateImage(bytes);
        }
      } catch (_) {
        bytes = null;
      }
    }
    return CachedMiniPhoneWallpaper(info, bytes);
  }

  @override
  Future<Uint8List> loadImage(String url) async {
    // An unchanged URL is immutable for this feature. Even an expired disk
    // entry can be displayed offline; a new server URL downloads a new file.
    final cached = await _images.getFileFromCache(url);
    if (cached != null) {
      try {
        final bytes = await cached.file.readAsBytes();
        await _validateImage(bytes);
        return bytes;
      } catch (_) {
        await _images.removeFile(url);
      }
    }
    final file = await _images.getSingleFile(url);
    final bytes = await file.readAsBytes();
    try {
      await _validateImage(bytes);
    } catch (_) {
      await _images.removeFile(url);
      rethrow;
    }
    return bytes;
  }

  Future<void> _validateImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1);
    try {
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  }

  @override
  Future<void> writeImage(
    String url,
    Uint8List bytes,
    String contentType,
  ) async {
    await _validateImage(bytes);
    await _images.putFile(
      url,
      bytes,
      fileExtension: switch (contentType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      },
    );
  }

  @override
  Future<void> write(String owner, String worldId, MiniphoneInfo info) async {
    final prefs = await _preferences();
    final key = _key(owner);
    await prefs.setString('$key:background', info.backgroundImage);
    await prefs.setString(
      '$key:catalogue:${Uri.encodeComponent(worldId)}',
      jsonEncode([
        for (final image in info.wallpapers)
          {'image_url': image.imageUrl, 'title': image.title},
      ]),
    );
  }
}
