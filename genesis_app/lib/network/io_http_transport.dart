import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'http_transport.dart';

class IoHttpTransport implements HttpTransport {
  IoHttpTransport({HttpClient? client, String? proxy})
    : _client = client ?? createProxyAwareHttpClient(proxy);

  final HttpClient _client;

  @override
  Future<TransportResponse> send(TransportRequest request) async {
    final httpRequest = await _client
        .openUrl(request.method, request.uri)
        .timeout(Duration(milliseconds: request.timeoutMs));

    request.headers.forEach((key, value) {
      httpRequest.headers.set(key, value);
    });

    if (request.bodyBytes != null) {
      httpRequest.add(request.bodyBytes!);
    }

    final httpResponse = await httpRequest.close().timeout(
      Duration(milliseconds: request.timeoutMs),
    );

    final headers = <String, String>{};
    httpResponse.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });

    final body = await utf8
        .decodeStream(httpResponse)
        .timeout(Duration(milliseconds: request.timeoutMs));

    return TransportResponse(
      statusCode: httpResponse.statusCode,
      headers: headers,
      body: body,
    );
  }
}

HttpClient createProxyAwareHttpClient(String? proxy) {
  final client = HttpClient();
  final proxyAddress = _normalizeProxyAddress(proxy);
  if (proxyAddress != null) {
    client.findProxy = (_) => 'PROXY $proxyAddress; DIRECT';
    if (!const bool.fromEnvironment('dart.vm.product')) {
      client.badCertificateCallback = (_, __, ___) => true;
    }
  }
  return client;
}

String? _normalizeProxyAddress(String? proxy) {
  final raw = proxy?.trim();
  if (raw == null || raw.isEmpty) return null;
  final parsed = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
  if (parsed == null || parsed.host.trim().isEmpty || !parsed.hasPort) {
    return raw;
  }
  return '${parsed.host}:${parsed.port}';
}
