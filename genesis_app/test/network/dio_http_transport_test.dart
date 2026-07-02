import 'dart:convert';
import 'dart:io';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/dio_http_transport.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/io_http_transport.dart';
import 'package:genesis_flutter_android/network/multipart_body.dart';

void main() {
  test('sends request and maps response without throwing on status', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/search');
      expect(request.uri.queryParameters['keyword'], 'worldo');
      expect(await utf8.decodeStream(request), '{"q":"worldo"}');
      final responseBody = utf8.encode('{"message":"accepted"}');
      request.response
        ..statusCode = 202
        ..headers.contentType = ContentType.json
        ..contentLength = responseBody.length
        ..add(responseBody);
      await request.response.close();
    });

    final metrics = <_FakePerformanceMetric>[];
    final body = utf8.encode('{"q":"worldo"}');
    final transport = DioHttpTransport(
      performanceMetricUrlFilter: (_) => true,
      performanceMetricFactory: (url, method) {
        final metric = _FakePerformanceMetric(url: url, method: method);
        metrics.add(metric);
        return metric;
      },
    );

    final response = await transport.send(
      TransportRequest(
        method: 'POST',
        uri: Uri.parse(
          'http://127.0.0.1:${server.port}/api/v1/search?keyword=worldo',
        ),
        headers: const {'content-type': 'application/json'},
        bodyBytes: body,
        timeoutMs: 5000,
      ),
    );

    expect(response.statusCode, 202);
    expect(response.body, '{"message":"accepted"}');
    expect(response.responsePayloadSizeBytes, response.body.length);
    expect(metrics, hasLength(1));
    final metric = metrics.single;
    expect(metric.url, 'http://127.0.0.1:${server.port}/api/v1/search');
    expect(metric.method, HttpMethod.Post);
    expect(metric.started, true);
    expect(metric.stopped, true);
    expect(metric.requestPayloadSize, body.length);
    expect(metric.httpResponseCode, 202);
    expect(metric.responseContentType, 'application/json; charset=utf-8');
    expect(metric.responsePayloadSize, utf8.encode(response.body).length);
  });

  test('returns non-2xx responses for ApiClient to process', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = 401
        ..write('unauthorized');
      await request.response.close();
    });

    final transport = DioHttpTransport(
      performanceMetricUrlFilter: (_) => false,
    );

    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse('http://127.0.0.1:${server.port}/private'),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 5000,
      ),
    );

    expect(response.statusCode, 401);
    expect(response.body, 'unauthorized');
  });

  test('sends multipart body bytes unchanged through ApiClient', () async {
    final expectedBody = MultipartBody.singleFile(
      boundary: 'test-boundary',
      bytes: utf8.encode('image-bytes'),
      filename: 'avatar.png',
      contentType: 'image/png',
      fields: const {'scene': 'avatar'},
    ).toBytes();

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/upload/image');
      expect(
        request.headers.value('content-type'),
        'multipart/form-data; boundary=test-boundary',
      );
      expect(
        await request.fold<List<int>>(<int>[], (out, chunk) {
          out.addAll(chunk);
          return out;
        }),
        expectedBody,
      );
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('{"err_no":0,"data":{"xl_url":"https://cdn/x.webp"}}');
      await request.response.close();
    });

    final client = ApiClient(
      baseUrl: 'http://127.0.0.1:${server.port}/api/',
      transport: DioHttpTransport(performanceMetricUrlFilter: (_) => false),
    );
    final progressEvents = <({int sentBytes, int totalBytes})>[];

    final response = await client.post<Object?>(
      'v1/upload/image',
      body: MultipartBody.singleFile(
        boundary: 'test-boundary',
        bytes: utf8.encode('image-bytes'),
        filename: 'avatar.png',
        contentType: 'image/png',
        fields: const {'scene': 'avatar'},
      ),
      onSendProgress: (sentBytes, totalBytes) {
        progressEvents.add((sentBytes: sentBytes, totalBytes: totalBytes));
      },
    );

    expect(response, isA<Map<String, dynamic>>());
    expect(progressEvents, isNotEmpty);
    expect(progressEvents.last.sentBytes, expectedBody.length);
    expect(progressEvents.last.totalBytes, expectedBody.length);
  });

  test(
    'reports receive progress and returns raw bytes through ApiClient',
    () async {
      final responseBody = <int>[0, 1, 2, 250, 255];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.binary
          ..contentLength = responseBody.length;
        request.response.add(responseBody.sublist(0, 2));
        await request.response.flush();
        request.response.add(responseBody.sublist(2));
        await request.response.close();
      });

      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}/',
        transport: DioHttpTransport(performanceMetricUrlFilter: (_) => false),
      );
      final progressEvents = <({int receivedBytes, int totalBytes})>[];

      final bytes = await client.getBytes(
        '/asset.bin',
        onReceiveProgress: (receivedBytes, totalBytes) {
          progressEvents.add((
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ));
        },
      );

      expect(bytes, responseBody);
      expect(progressEvents, isNotEmpty);
      expect(progressEvents.last.receivedBytes, responseBody.length);
      expect(progressEvents.last.totalBytes, responseBody.length);
    },
  );
}

class _FakePerformanceMetric implements HttpRequestPerformanceMetric {
  _FakePerformanceMetric({required this.url, required this.method});

  final String url;
  final HttpMethod method;

  bool started = false;
  bool stopped = false;

  @override
  int? httpResponseCode;

  @override
  int? requestPayloadSize;

  @override
  String? responseContentType;

  @override
  int? responsePayloadSize;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
