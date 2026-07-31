import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'http_transport.dart';
import 'static_image_network_config.dart';

const MethodChannel _iosHttpProtocolChannel = MethodChannel(
  'com.worldo.ai/network',
);

typedef IosHttpProtocolProbe = Future<String?> Function(Uri uri);
typedef IosHttpTransportBuilder = HttpTransport Function();

Future<String?> probeIosHttpProtocol(Uri uri) async {
  if (!Platform.isIOS) return null;
  final protocol = await _iosHttpProtocolChannel
      .invokeMethod<String>('probeHttpProtocol', <String, Object?>{
        'url': uri.toString(),
      })
      .timeout(const Duration(seconds: 12));
  return normalizeHttpProtocolVersion(protocol);
}

class IosAdaptiveHttpTransport
    implements HttpTransport, OriginWarmableHttpTransport {
  IosAdaptiveHttpTransport({
    required IosHttpTransportBuilder http3TransportBuilder,
    required IosHttpTransportBuilder http2TransportBuilder,
    IosHttpProtocolProbe protocolProbe = probeIosHttpProtocol,
    Set<String> http3CapableHosts = genesisHttp3CapableHosts,
    int http2ConnectionCount = 3,
  }) : _http3TransportBuilder = http3TransportBuilder,
       _http2TransportBuilder = http2TransportBuilder,
       _protocolProbe = protocolProbe,
       _http3CapableHosts = <String>{
         for (final host in http3CapableHosts) host.toLowerCase(),
       },
       _http2ConnectionCount = http2ConnectionCount {
    if (http2ConnectionCount < 1) {
      throw ArgumentError.value(
        http2ConnectionCount,
        'http2ConnectionCount',
        'Must be greater than zero.',
      );
    }
  }

  final IosHttpTransportBuilder _http3TransportBuilder;
  final IosHttpTransportBuilder _http2TransportBuilder;
  final IosHttpProtocolProbe _protocolProbe;
  final Set<String> _http3CapableHosts;
  final int _http2ConnectionCount;
  final Map<String, Future<String?>> _protocolRequests =
      <String, Future<String?>>{};
  final Map<String, Future<void>> _warmUpRequests = <String, Future<void>>{};

  HttpTransport? _http3Transport;
  List<HttpTransport>? _http2Transports;
  int _nextHttp2TransportIndex = 0;

  HttpTransport get _nativeHttp3Transport =>
      _http3Transport ??= _http3TransportBuilder();

  List<HttpTransport> get _fallbackHttp2Transports =>
      _http2Transports ??= List<HttpTransport>.generate(
        _http2ConnectionCount,
        (_) => _http2TransportBuilder(),
        growable: false,
      );

  @visibleForTesting
  int get initializedHttp2ConnectionCount => _http2Transports?.length ?? 0;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    request.cancellationToken?.throwIfCancelled();
    final originKey = _originKey(request.uri);
    final warmUp = _warmUpRequests[originKey];
    if (warmUp != null) {
      await warmUp;
      request.cancellationToken?.throwIfCancelled();
    }

    final transport = await _transportFor(request.uri);
    request.cancellationToken?.throwIfCancelled();
    return transport.send(request);
  }

  @override
  Future<void> warmUp(Uri uri) {
    final originKey = _originKey(uri);
    final existing = _warmUpRequests[originKey];
    if (existing != null) return existing;

    final request = _warmUpOrigin(uri);
    _warmUpRequests[originKey] = request;
    return request;
  }

  Future<void> _warmUpOrigin(Uri uri) async {
    try {
      final protocol = await _protocolFor(uri);
      final transports = !_shouldProbe(uri) || protocol == 'h3'
          ? <HttpTransport>[_nativeHttp3Transport]
          : _fallbackHttp2Transports;
      await Future.wait<void>([
        for (final transport in transports)
          transport
              .send(
                TransportRequest(
                  method: 'HEAD',
                  uri: uri,
                  headers: const <String, String>{'accept': '*/*'},
                  bodyBytes: null,
                  timeoutMs: 10000,
                ),
              )
              .then((_) {}),
      ]);
    } catch (_) {
      _warmUpRequests.remove(_originKey(uri));
      rethrow;
    }
  }

  Future<HttpTransport> _transportFor(Uri uri) async {
    if (!_shouldProbe(uri)) return _nativeHttp3Transport;
    final protocol = await _protocolFor(uri);
    if (protocol == 'h3') return _nativeHttp3Transport;

    final transports = _fallbackHttp2Transports;
    final transport = transports[_nextHttp2TransportIndex];
    _nextHttp2TransportIndex =
        (_nextHttp2TransportIndex + 1) % transports.length;
    return transport;
  }

  Future<String?> _protocolFor(Uri uri) {
    if (!_shouldProbe(uri)) return Future<String?>.value(null);
    final originKey = _originKey(uri);
    return _protocolRequests.putIfAbsent(
      originKey,
      () => _probeOrigin(uri, originKey),
    );
  }

  Future<String?> _probeOrigin(Uri uri, String originKey) async {
    final probeUri = Uri(
      scheme: 'https',
      host: uri.host,
      port: uri.hasPort ? uri.port : 443,
      path: '/robots.txt',
    );
    try {
      final protocol = normalizeHttpProtocolVersion(
        await _protocolProbe(probeUri),
      );
      debugPrint(
        '[Network][HTTP3][iOS] $originKey negotiated '
        '${protocol ?? 'unknown'}; '
        '${protocol == 'h3' ? 'using one QUIC transport' : 'using the three-connection HTTP/2 fallback'}',
      );
      return protocol;
    } catch (error, stackTrace) {
      debugPrint(
        '[Network][HTTP3][iOS] protocol probe failed for $originKey; '
        'using the three-connection HTTP/2 fallback: $error',
      );
      debugPrint('[Network][HTTP3][iOS] stacktrace:\n$stackTrace');
      return null;
    }
  }

  bool _shouldProbe(Uri uri) {
    return uri.scheme.toLowerCase() == 'https' &&
        _http3CapableHosts.contains(uri.host.toLowerCase());
  }

  String _originKey(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final port = uri.hasPort
        ? uri.port
        : scheme == 'https'
        ? 443
        : 80;
    return '$scheme://$host:$port';
  }
}
