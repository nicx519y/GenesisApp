import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/qa/fixtures/http/mock_response_registry.dart';
import 'package:genesis_flutter_android/network/http_transport.dart';

void main() {
  test('dispatch skips undeclared methods and released snapshot entries', () async {
    final calls = <String>[];
    const response = TransportResponse(statusCode: 200, headers: {}, body: 'owned');
    final readOnly = registerQaHook('test:tick-read', (_) async {
      calls.add('read');
      return response;
    });
    late QaMockResponderRegistration released;
    final submit = registerQaHook('test:tick-submit', (_) async {
      calls.add('submit');
      released.close();
      return response;
    }, methods: {'POST'});
    released = registerQaHook('test:tick-released', (_) async {
      calls.add('released');
      return response;
    }, methods: {'POST'});
    final request = TransportRequest(
      method: 'POST',
      uri: Uri.parse('https://qa.invalid/tick'),
      headers: const {},
      bodyBytes: null,
      timeoutMs: 1000,
    );
    try {
      expect(await dispatchQaMockResponders(request), same(response));
      expect(calls, ['submit']);
    } finally {
      readOnly.close();
      submit.close();
      released.close();
    }
    expect(await dispatchQaMockResponders(request), isNull);
    expect(calls, ['submit']);
  });
}
