import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../../../network/genesis_http_cache_manager.dart';
import '../../../../ui/components/genesis_static_network_image.dart';

/// A lease-local image for the mock seed's example-domain tile. Real URLs and
/// other worlds are unchanged. The application still fetches and decodes bytes.
class WorldMapImage {
  WorldMapImage._(this._server, this._releaseCache);
  static const asset = 'assets/images/map_default/root_default.webp';
  final HttpServer _server;
  final Future<void> Function(String) _releaseCache;
  final Set<String> _requested = {};
  bool closed = false;
  late final String url = 'http://127.0.0.1:${_server.port}/world-tile.webp';

  static Future<WorldMapImage> open({
    required Future<void> Function() requireOwner,
    Future<Uint8List> Function()? load,
    Future<void> Function(String)? releaseCache,
  }) async {
    final bytes = await (load?.call() ?? rootBundle.load(asset).then(
      (data) => data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    ));
    if (bytes.isEmpty) throw StateError('Empty mock map image');
    await requireOwner();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final image = WorldMapImage._(server, releaseCache ?? (url) async {
      await GenesisStaticNetworkImageProvider(imageUrl: url).evict();
      await GenesisHttpCacheManager().removeFile(url);
    });
    server.listen((request) async {
      try {
        if (image.closed || request.method != 'GET' ||
            request.uri.path != '/world-tile.webp') {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          await requireOwner();
          if (image.closed) throw StateError('Map image lease closed');
          image._requested.add(image.url +
              (request.uri.hasQuery ? '?${request.uri.query}' : ''));
          request.response.headers.contentType = ContentType('image', 'webp');
          request.response.headers.set('cache-control', 'no-store');
          request.response.add(bytes);
        }
      } catch (_) {
        request.response.statusCode = HttpStatus.forbidden;
      } finally {
        await request.response.close();
      }
    });
    return image;
  }

  Future<void> close() async {
    if (!closed) {
      await _server.close(force: true);
      closed = true;
    }
    // Keep failed releases for a subsequent cleanup attempt.
    for (final url in _requested.toList()) {
      await _releaseCache(url);
      _requested.remove(url);
    }
  }
}
