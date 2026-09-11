import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/startup/ios_startup_network.dart';
import 'package:http/http.dart' as http;

final _probeUri = Uri.parse('https://api.example.com/apix/v1/time');

void main() {
  testWidgets('Android proceeds without a connectivity request', (
    tester,
  ) async {
    await waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.android,
      clientFactory: () => throw StateError('Must not create a client'),
    );
  });

  testWidgets('permission waiting does not consume config or network timeout', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final client = _ProbeClient();
    var configStarted = false;
    final startup = waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.iOS,
      clientFactory: () => client,
    ).then((_) => configStarted = true);

    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(minutes: 1));
    expect(configStarted, isFalse);
    expect(client.requests.single.method, 'HEAD');
    expect(client.requests.single.url, _probeUri);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(configStarted, isFalse);
    client.respond(0);
    await tester.pump();
    await startup;
    expect(configStarted, isTrue);
    expect(client.closed, isTrue);
  });

  testWidgets('a response while inactive waits for the prompt to close', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final client = _ProbeClient();
    var continued = false;
    final startup = waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.iOS,
      clientFactory: () => client,
    ).then((_) => continued = true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    client.respond(0, statusCode: 405);
    await tester.pump(const Duration(seconds: 30));
    expect(continued, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await startup;
    expect(continued, isTrue);
    expect(client.requests, hasLength(1));
  });

  testWidgets('resume before the old failure still triggers a new probe', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final client = _ProbeClient();
    var continued = false;
    final startup = waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.iOS,
      clientFactory: () => client,
    ).then((_) => continued = true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    client.responses[0].completeError(http.ClientException('Not connected'));
    await tester.pump();
    expect(client.requests, hasLength(2));
    expect(continued, isFalse);

    client.respond(1);
    await tester.pump();
    await startup;
    expect(continued, isTrue);
  });

  testWidgets('denied or offline access does not permanently hold startup', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final client = _ProbeClient();
    var continued = false;
    final startup = waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.iOS,
      clientFactory: () => client,
    ).then((_) => continued = true);
    await tester.pump(const Duration(seconds: 8));
    await startup;
    expect(continued, isTrue);
    expect(client.closed, isTrue);
    expect(await client.aborted, isTrue);
  });
}

class _ProbeClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  final responses = <Completer<http.StreamedResponse>>[];
  bool closed = false;
  Future<bool>? aborted;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    final response = Completer<http.StreamedResponse>();
    responses.add(response);
    if (request is http.AbortableRequest) {
      aborted = request.abortTrigger?.then((_) {
        if (!response.isCompleted) {
          response.completeError(http.RequestAbortedException());
        }
        return true;
      });
    }
    return response.future;
  }

  void respond(int index, {int statusCode = 200}) {
    responses[index].complete(
      http.StreamedResponse(const Stream.empty(), statusCode),
    );
  }

  @override
  void close() => closed = true;
}
