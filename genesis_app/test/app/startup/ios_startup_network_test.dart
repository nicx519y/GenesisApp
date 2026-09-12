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

  testWidgets('startup continues before native cancellation finishes', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final client = _CleanupProbeClient();
    final startup = waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.iOS,
      clientFactory: () => client,
    );

    await tester.pump(const Duration(seconds: 8));
    await startup;
    expect(client.abortRequested, isTrue);
    expect(client.closeCalls, 0);

    client.completeCancellation();
    await tester.pump();
    expect(client.closeCalls, 1);
  });

  testWidgets('response headers allow startup before response cleanup', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final client = _CleanupProbeClient();
    final startup = waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.iOS,
      clientFactory: () => client,
    );

    client.respond();
    await tester.pump();
    await startup;
    expect(client.closeCalls, 0);

    client.completeBody();
    await tester.pump();
    expect(client.closeCalls, 1);
  });

  testWidgets('a response arriving after timeout is still drained and closed', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final client = _CleanupProbeClient();
    final startup = waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.iOS,
      clientFactory: () => client,
    );

    await tester.pump(const Duration(seconds: 8));
    await startup;
    client.respond();
    await tester.pump();
    expect(client.body.hasListener, isTrue);
    expect(client.closeCalls, 0);

    client.completeBody();
    await tester.pump();
    expect(client.closeCalls, 1);
  });

  testWidgets('client cleanup errors cannot fail startup', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final client = _CleanupProbeClient(failClose: true);
    final startup = waitForIosStartupNetwork(
      probeUri: _probeUri,
      platform: TargetPlatform.iOS,
      clientFactory: () => client,
    );

    client.respond();
    client.completeBody();
    await tester.pump();
    await startup;
    expect(client.closeCalls, 1);
    expect(tester.takeException(), isNull);
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

class _CleanupProbeClient extends http.BaseClient {
  _CleanupProbeClient({this.failClose = false});

  final bool failClose;
  final response = Completer<http.StreamedResponse>();
  final body = StreamController<List<int>>();
  var running = true;
  var abortRequested = false;
  var closeCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final abortable = request as http.AbortableRequest;
    unawaited(abortable.abortTrigger!.then((_) => abortRequested = true));
    return response.future;
  }

  void respond() => response.complete(http.StreamedResponse(body.stream, 200));

  void completeBody() {
    running = false;
    unawaited(body.close());
  }

  void completeCancellation() {
    running = false;
    response.completeError(http.RequestAbortedException());
    unawaited(body.close());
  }

  @override
  void close() {
    closeCalls++;
    if (running) throw StateError('cannot close with running requests');
    if (failClose) throw StateError('Native cleanup failed');
  }
}
