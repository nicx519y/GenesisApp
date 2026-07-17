import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/startup/startup_network_gate.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

void main() {
  test('holds requests until opened', () async {
    final gate = StartupNetworkGate();
    final request = TransportRequest(
      method: 'GET',
      uri: Uri.parse('https://api.worldo.ai/api/v1/origin/list'),
      headers: const <String, String>{},
      bodyBytes: null,
      timeoutMs: 15000,
    );
    var sent = false;

    final response = gate.wrap(null)(request, (request) async {
      sent = true;
      return const TransportResponse(
        statusCode: 200,
        headers: <String, String>{},
        body: '{}',
      );
    });

    await Future<void>.delayed(Duration.zero);
    expect(sent, isFalse);

    gate.open();
    await expectLater(response, completes);
    expect(sent, isTrue);
  });

  test('open gate sends immediately', () async {
    final gate = StartupNetworkGate.open();
    var sent = false;

    await gate.wrap(null)(
      TransportRequest(
        method: 'GET',
        uri: Uri.parse('https://api.worldo.ai/api/v1/origin/list'),
        headers: const <String, String>{},
        bodyBytes: null,
        timeoutMs: 15000,
      ),
      (request) async {
        sent = true;
        return const TransportResponse(
          statusCode: 200,
          headers: <String, String>{},
          body: '{}',
        );
      },
    );

    expect(sent, isTrue);
  });
}
