import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_http2_cache_manager.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

void main() {
  test('image transport pool warms every connection once per origin', () async {
    const response = TransportResponse(
      statusCode: 200,
      headers: <String, String>{},
      body: '',
      httpProtocolVersion: '2.0',
    );
    final transports = List<_RecordingTransport>.generate(
      genesisImageHttp2ConnectionCount,
      (_) => _RecordingTransport(response),
    );
    final pool = GenesisImageHttp2TransportPool(transports: transports);
    final warmUpUri = Uri.parse('https://cdn-001.worldo.ai/robots.txt');

    await Future.wait<void>([pool.warmUp(warmUpUri), pool.warmUp(warmUpUri)]);

    for (final transport in transports) {
      expect(transport.requests, hasLength(1));
      final request = transport.requests.single;
      expect(request.method, 'HEAD');
      expect(request.uri, warmUpUri);
      expect(request.headers, const <String, String>{'accept': '*/*'});
      expect(request.timeoutMs, 10000);
    }
  });

  test(
    'image transport pool distributes requests over three connections',
    () async {
      const response = TransportResponse(
        statusCode: 200,
        headers: <String, String>{},
        body: '',
        httpProtocolVersion: '2.0',
      );
      final transports = List<_RecordingTransport>.generate(
        genesisImageHttp2ConnectionCount,
        (_) => _RecordingTransport(response),
      );
      final pool = GenesisImageHttp2TransportPool(transports: transports);

      await Future.wait([
        for (var index = 0; index < 7; index += 1)
          pool.send(
            TransportRequest(
              method: 'GET',
              uri: Uri.parse('https://cdn.example.com/tile-$index.webp'),
              headers: const <String, String>{},
              bodyBytes: null,
              timeoutMs: 1000,
            ),
          ),
      ]);

      expect(
        transports.map(
          (transport) =>
              transport.requests.map((request) => request.uri.path).toList(),
        ),
        [
          ['/tile-0.webp', '/tile-3.webp', '/tile-6.webp'],
          ['/tile-1.webp', '/tile-4.webp'],
          ['/tile-2.webp', '/tile-5.webp'],
        ],
      );
    },
  );

  test('image file service sends downloads through shared transport', () async {
    final transport = _RecordingTransport(
      TransportResponse(
        statusCode: 200,
        headers: const <String, String>{
          'Cache-Control': 'public, max-age=60',
          'Content-Length': '5',
          'Content-Type': 'image/webp',
          'ETag': 'image-v1',
        },
        body: 'image',
        bodyBytes: utf8.encode('image'),
        responsePayloadSizeBytes: 5,
        httpProtocolVersion: '2.0',
      ),
    );
    final service = GenesisHttp2FileService(
      transport: transport,
      timeoutMs: 4321,
    );
    expect(
      service.concurrentFetches,
      genesisImageHttp2ConnectionCount *
          genesisImageConcurrentFetchesPerConnection,
    );
    final beforeRequest = DateTime.now();

    final response = await service.get(
      'https://cdn.example.com/image.webp',
      headers: const <String, String>{'if-none-match': 'image-v0'},
    );

    final request = transport.requests.single;
    expect(request.method, 'GET');
    expect(request.uri, Uri.parse('https://cdn.example.com/image.webp'));
    expect(request.headers['if-none-match'], 'image-v0');
    expect(request.timeoutMs, 4321);
    expect(await response.content.expand((chunk) => chunk).toList(), [
      ...utf8.encode('image'),
    ]);
    expect(response.statusCode, 200);
    expect(response.contentLength, 5);
    expect(response.eTag, 'image-v1');
    expect(response.fileExtension, '.webp');
    final validTill = response.validTill;
    expect(
      validTill.isBefore(beforeRequest.add(const Duration(seconds: 60))),
      false,
    );
    expect(
      validTill.isBefore(DateTime.now().add(const Duration(seconds: 61))),
      true,
    );
  });

  test('no-cache image response expires immediately', () {
    final beforeResponse = DateTime.now();
    final response = GenesisHttp2FileServiceResponse(
      const TransportResponse(
        statusCode: 200,
        headers: <String, String>{'cache-control': 'no-cache'},
        body: '',
      ),
    );

    final validTill = response.validTill;
    expect(validTill.isBefore(beforeResponse), false);
    expect(
      validTill.isAfter(DateTime.now().add(const Duration(seconds: 1))),
      false,
    );
  });
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
