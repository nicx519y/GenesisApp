import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/dio_http_transport.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/io_http_transport.dart';
import 'package:genesis_flutter_android/network/multipart_body.dart';

void main() {
  test('routes HTTPS to HTTP/2 adapter and plain HTTP to IO adapter', () async {
    final httpsAdapter = _RecordingAdapter(protocolVersion: '2.0');
    final otherAdapter = _RecordingAdapter(protocolVersion: '1.1');
    final adapter = SchemeRoutingHttpClientAdapter(
      httpsAdapter: httpsAdapter,
      otherAdapter: otherAdapter,
    );

    final httpsResponse = await adapter.fetch(
      RequestOptions(path: 'https://api.worldo.ai/api/v1/health'),
      null,
      null,
    );
    final httpResponse = await adapter.fetch(
      RequestOptions(path: 'http://127.0.0.1:8080/health'),
      null,
      null,
    );

    expect(httpsAdapter.requestedUris, [
      Uri.parse('https://api.worldo.ai/api/v1/health'),
    ]);
    expect(otherAdapter.requestedUris, [
      Uri.parse('http://127.0.0.1:8080/health'),
    ]);
    expect(httpsResponse.extra[HttpClientAdapter.extraKeyHttpVersion], '2.0');
    expect(httpResponse.extra[HttpClientAdapter.extraKeyHttpVersion], '1.1');

    adapter.close(force: true);
    expect(httpsAdapter.forceClosed, true);
    expect(otherAdapter.forceClosed, true);
  });

  test('rejects an HTTPS response that did not negotiate HTTP/2', () async {
    final dio = Dio()
      ..httpClientAdapter = _RecordingAdapter(protocolVersion: '1.1');
    final transport = DioHttpTransport(
      dio: dio,
      performanceMetricUrlFilter: (_) => false,
    );

    await expectLater(
      transport.send(
        TransportRequest(
          method: 'GET',
          uri: Uri.parse('https://api.worldo.ai/api/v1/health'),
          headers: const {},
          bodyBytes: null,
          timeoutMs: 5000,
        ),
      ),
      throwsA(
        isA<DioException>().having(
          (error) => error.message,
          'message',
          contains('negotiated protocol was 1.1'),
        ),
      ),
    );
  });

  test('records negotiated HTTP/2 on HTTPS responses', () async {
    final dio = Dio()
      ..httpClientAdapter = _RecordingAdapter(protocolVersion: '2.0');
    final transport = DioHttpTransport(
      dio: dio,
      performanceMetricUrlFilter: (_) => false,
    );

    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse('https://api.worldo.ai/api/v1/health'),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 5000,
      ),
    );

    expect(response.statusCode, 200);
    expect(response.body, 'ok');
    expect(response.httpProtocolVersion, 'h2');
  });

  test('records each Tilemap image as a Firebase HTTP metric', () async {
    final dio = Dio()
      ..httpClientAdapter = _RecordingAdapter(protocolVersion: '2.0');
    final metrics = <_FakePerformanceMetric>[];
    final transport = DioHttpTransport(
      dio: dio,
      performanceMetricReady: () => true,
      performanceMetricFactory: (url, method) {
        final metric = _FakePerformanceMetric(url: url, method: method);
        metrics.add(metric);
        return metric;
      },
    );

    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse(
          'https://cdn-001.worldo.ai/predata/tiles/L2/tile.webp'
          '?x-oss-process=image/resize,w_512,image/format,webp',
        ),
        headers: const <String, String>{},
        bodyBytes: null,
        timeoutMs: 5000,
      ),
    );

    expect(response.statusCode, 200);
    expect(metrics, hasLength(1));
    final metric = metrics.single;
    expect(metric.url, 'https://cdn-001.worldo.ai/predata/tiles/L2/tile.webp');
    expect(metric.method, HttpMethod.Get);
    expect(metric.started, true);
    expect(metric.stopped, true);
    expect(metric.httpResponseCode, 200);
    expect(metric.responsePayloadSize, 2);
    expect(metric.attributes, const <String, String>{'network_protocol': 'h2'});
  });

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
      performanceMetricReady: () => true,
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

  test('skips metrics while Firebase Performance is not ready', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = 200
        ..write('ok');
      await request.response.close();
    });

    final metrics = <_FakePerformanceMetric>[];
    final transport = DioHttpTransport(
      performanceMetricUrlFilter: (_) => true,
      performanceMetricReady: () => false,
      performanceMetricFactory: (url, method) {
        final metric = _FakePerformanceMetric(url: url, method: method);
        metrics.add(metric);
        return metric;
      },
    );

    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse('http://127.0.0.1:${server.port}/ping'),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 5000,
      ),
    );

    expect(response.statusCode, 200);
    expect(response.body, 'ok');
    expect(metrics, isEmpty);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.protocolVersion});

  final String protocolVersion;
  final List<Uri> requestedUris = <Uri>[];
  bool forceClosed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedUris.add(options.uri);
    return ResponseBody.fromString(
      'ok',
      200,
      headers: const <String, List<String>>{
        'content-type': <String>['text/plain'],
      },
    )..extra[HttpClientAdapter.extraKeyHttpVersion] = protocolVersion;
  }

  @override
  void close({bool force = false}) {
    forceClosed = force;
  }
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

  final Map<String, String> attributes = <String, String>{};

  @override
  void putAttribute(String name, String value) {
    attributes[name] = value;
  }

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
