import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';
import 'package:genesis_flutter_android/network/io_http_transport.dart';

void main() {
  test('records Firebase HTTP metric data for completed requests', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/search');
      expect(request.uri.queryParameters['keyword'], 'worldo');
      await utf8.decodeStream(request);
      final responseBody = utf8.encode('{"ok":true}');
      request.response
        ..statusCode = 201
        ..headers.contentType = ContentType.json
        ..contentLength = responseBody.length
        ..add(responseBody);
      await request.response.close();
    });

    final metrics = <_FakePerformanceMetric>[];
    final transport = IoHttpTransport(
      performanceMetricUrlFilter: (_) => true,
      performanceMetricFactory: (url, method) {
        final metric = _FakePerformanceMetric(url: url, method: method);
        metrics.add(metric);
        return metric;
      },
    );
    final body = utf8.encode('{"q":"worldo"}');

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

    expect(response.statusCode, 201);
    expect(metrics, hasLength(1));
    final metric = metrics.single;
    expect(metric.url, 'http://127.0.0.1:${server.port}/api/v1/search');
    expect(metric.method, HttpMethod.Post);
    expect(metric.started, true);
    expect(metric.stopped, true);
    expect(metric.requestPayloadSize, body.length);
    expect(metric.httpResponseCode, 201);
    expect(metric.responseContentType, 'application/json; charset=utf-8');
    expect(metric.responsePayloadSize, utf8.encode('{"ok":true}').length);
  });

  test('skips manual metrics for non-business hosts by default', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = 200
        ..write('ok');
      await request.response.close();
    });

    final metrics = <_FakePerformanceMetric>[];
    final transport = IoHttpTransport(
      performanceMetricFactory: (url, method) {
        final metric = _FakePerformanceMetric(url: url, method: method);
        metrics.add(metric);
        return metric;
      },
    );

    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse('http://127.0.0.1:${server.port}/collect'),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 5000,
      ),
    );

    expect(response.statusCode, 200);
    expect(metrics, isEmpty);
  });

  test('records business metric URL without adding port zero', () async {
    final metrics = <_FakePerformanceMetric>[];
    final transport = IoHttpTransport(
      client: _FakeHttpClient(
        statusCode: 200,
        responseBody: '{"ok":true}',
        contentType: ContentType.json,
      ),
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
          'https://api.worldo.ai/api/v1/origin/list?scene=foryou&pn=1&rn=20',
        ),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 5000,
      ),
    );

    expect(response.statusCode, 200);
    expect(metrics, hasLength(1));
    expect(metrics.single.url, 'https://api.worldo.ai/api/v1/origin/list');
    expect(metrics.single.url, isNot(contains(':0')));
  });

  test('continues request when metric creation fails', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response
        ..statusCode = 200
        ..write('ok');
      await request.response.close();
    });

    final transport = IoHttpTransport(
      performanceMetricUrlFilter: (_) => true,
      performanceMetricFactory: (_, _) => throw StateError('metric failed'),
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
  });

  test('reports receive progress and keeps raw response bytes', () async {
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

    final progressEvents = <({int receivedBytes, int totalBytes})>[];
    final transport = IoHttpTransport(performanceMetricUrlFilter: (_) => false);

    final response = await transport.send(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse('http://127.0.0.1:${server.port}/asset.bin'),
        headers: const {},
        bodyBytes: null,
        timeoutMs: 5000,
        onReceiveProgress: (receivedBytes, totalBytes) {
          progressEvents.add((
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          ));
        },
      ),
    );

    expect(response.statusCode, 200);
    expect(response.bodyBytes, responseBody);
    expect(progressEvents, isNotEmpty);
    expect(progressEvents.last.receivedBytes, responseBody.length);
    expect(progressEvents.last.totalBytes, responseBody.length);
  });
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

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({
    required this.statusCode,
    required this.responseBody,
    required this.contentType,
  });

  final int statusCode;
  final String responseBody;
  final ContentType contentType;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(
      statusCode: statusCode,
      responseBody: responseBody,
      contentType: contentType,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({
    required this.statusCode,
    required this.responseBody,
    required this.contentType,
  });

  final int statusCode;
  final String responseBody;
  final ContentType contentType;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(
      statusCode: statusCode,
      body: responseBody,
      contentType: contentType,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.statusCode,
    required String body,
    required ContentType contentType,
  }) : _bodyBytes = utf8.encode(body),
       headers = _FakeHttpHeaders(contentType: contentType);

  final List<int> _bodyBytes;

  @override
  final int statusCode;

  @override
  final HttpHeaders headers;

  @override
  int get contentLength => _bodyBytes.length;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bodyBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  _FakeHttpHeaders({ContentType? contentType}) : _contentType = contentType;

  final ContentType? _contentType;
  final Map<String, List<String>> _values = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = <String>['$value'];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    if (_contentType != null) {
      action(HttpHeaders.contentTypeHeader, <String>[_contentType.toString()]);
    }
    _values.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
