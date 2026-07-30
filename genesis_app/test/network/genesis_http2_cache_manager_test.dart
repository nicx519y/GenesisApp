import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/genesis_http2_cache_manager.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

void main() {
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
