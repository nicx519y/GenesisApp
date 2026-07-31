import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/ios_adaptive_http_transport.dart';

void main() {
  const h3Response = TransportResponse(
    statusCode: 200,
    headers: <String, String>{},
    body: 'h3',
    httpProtocolVersion: 'h3',
  );
  const h2Response = TransportResponse(
    statusCode: 200,
    headers: <String, String>{},
    body: 'h2',
    httpProtocolVersion: 'h2',
  );

  test('confirmed HTTP/3 uses one native transport for the origin', () async {
    var probeCount = 0;
    var http3BuildCount = 0;
    var http2BuildCount = 0;
    final http3 = _RecordingTransport(h3Response);
    final transport = IosAdaptiveHttpTransport(
      protocolProbe: (uri) async {
        probeCount += 1;
        expect(uri, Uri.parse('https://cdn-001.worldo.ai/robots.txt'));
        return 'h3';
      },
      http3TransportBuilder: () {
        http3BuildCount += 1;
        return http3;
      },
      http2TransportBuilder: () {
        http2BuildCount += 1;
        return _RecordingTransport(h2Response);
      },
    );

    await Future.wait([
      for (var index = 0; index < 6; index += 1)
        transport.send(_request('https://cdn-001.worldo.ai/tile-$index.webp')),
    ]);

    expect(probeCount, 1);
    expect(http3BuildCount, 1);
    expect(http2BuildCount, 0);
    expect(http3.requests, hasLength(6));
  });

  test('HTTP/2 result distributes requests over three transports', () async {
    var probeCount = 0;
    var http3BuildCount = 0;
    final http2Transports = <_RecordingTransport>[];
    final transport = IosAdaptiveHttpTransport(
      protocolProbe: (_) async {
        probeCount += 1;
        return 'h2';
      },
      http3TransportBuilder: () {
        http3BuildCount += 1;
        return _RecordingTransport(h3Response);
      },
      http2TransportBuilder: () {
        final fallback = _RecordingTransport(h2Response);
        http2Transports.add(fallback);
        return fallback;
      },
    );

    await Future.wait([
      for (var index = 0; index < 6; index += 1)
        transport.send(_request('https://cdn-001.worldo.ai/tile-$index.webp')),
    ]);

    expect(probeCount, 1);
    expect(http3BuildCount, 0);
    expect(http2Transports, hasLength(3));
    expect(http2Transports.map((fallback) => fallback.requests.length), <int>[
      2,
      2,
      2,
    ]);
  });

  test('HTTP/2 warm-up opens all fallbacks before queued requests', () async {
    final probeCompleter = Completer<String?>();
    final http2Transports = <_RecordingTransport>[];
    final transport = IosAdaptiveHttpTransport(
      protocolProbe: (_) => probeCompleter.future,
      http3TransportBuilder: () => _RecordingTransport(h3Response),
      http2TransportBuilder: () {
        final fallback = _RecordingTransport(h2Response);
        http2Transports.add(fallback);
        return fallback;
      },
    );
    final warmUpUri = Uri.parse('https://cdn-001.worldo.ai/robots.txt');

    final warmUp = transport.warmUp(warmUpUri);
    final queuedRequest = transport.send(
      _request('https://cdn-001.worldo.ai/tile.webp'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(http2Transports, isEmpty);
    probeCompleter.complete('h2');
    await warmUp;
    await queuedRequest;

    expect(http2Transports, hasLength(3));
    expect(
      http2Transports.fold<int>(
        0,
        (total, fallback) => total + fallback.requests.length,
      ),
      4,
    );
    for (final fallback in http2Transports) {
      expect(fallback.requests.first.method, 'HEAD');
      expect(fallback.requests.first.uri, warmUpUri);
    }
  });

  test('failed protocol probe safely uses HTTP/2 fallbacks', () async {
    final http2Transports = <_RecordingTransport>[];
    final transport = IosAdaptiveHttpTransport(
      protocolProbe: (_) async => throw StateError('UDP unavailable'),
      http3TransportBuilder: () => _RecordingTransport(h3Response),
      http2TransportBuilder: () {
        final fallback = _RecordingTransport(h2Response);
        http2Transports.add(fallback);
        return fallback;
      },
    );

    final response = await transport.send(
      _request('https://cdn-001.worldo.ai/tile.webp'),
    );

    expect(response.httpProtocolVersion, 'h2');
    expect(http2Transports, hasLength(3));
    expect(http2Transports.first.requests, hasLength(1));
  });

  test('unknown HTTPS origins retain native automatic negotiation', () async {
    var probeCount = 0;
    final http3 = _RecordingTransport(h3Response);
    final transport = IosAdaptiveHttpTransport(
      protocolProbe: (_) async {
        probeCount += 1;
        return 'h2';
      },
      http3TransportBuilder: () => http3,
      http2TransportBuilder: () => _RecordingTransport(h2Response),
    );

    await transport.send(_request('https://example.com/image.webp'));

    expect(probeCount, 0);
    expect(http3.requests, hasLength(1));
  });

  test('unknown HTTPS origin warm-up uses native negotiation', () async {
    var probeCount = 0;
    final http3 = _RecordingTransport(h3Response);
    final transport = IosAdaptiveHttpTransport(
      protocolProbe: (_) async {
        probeCount += 1;
        return 'h2';
      },
      http3TransportBuilder: () => http3,
      http2TransportBuilder: () => _RecordingTransport(h2Response),
    );

    await transport.warmUp(Uri.parse('https://example.com/robots.txt'));

    expect(probeCount, 0);
    expect(http3.requests, hasLength(1));
    expect(http3.requests.single.method, 'HEAD');
  });
}

TransportRequest _request(String url) {
  return TransportRequest(
    method: 'GET',
    uri: Uri.parse(url),
    headers: const <String, String>{},
    bodyBytes: null,
    timeoutMs: 1000,
  );
}

class _RecordingTransport implements HttpTransport {
  _RecordingTransport(this.response);

  final TransportResponse response;
  final List<TransportRequest> requests = <TransportRequest>[];

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    requests.add(request);
    return response;
  }
}
