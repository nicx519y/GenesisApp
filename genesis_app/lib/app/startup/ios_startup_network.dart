import 'dart:async';

import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// Trigger the iOS wireless-data prompt before starting business requests.
///
/// URLSession waits for connectivity while the user answers the prompt. The
/// foreground timeout only handles offline/denied access; time spent inactive
/// in a system prompt or in Settings never consumes that timeout.
Future<void> waitForIosStartupNetwork({
  required Uri probeUri,
  TargetPlatform? platform,
  http.Client Function()? clientFactory,
  Duration foregroundTimeout = const Duration(seconds: 8),
}) async {
  if ((platform ?? defaultTargetPlatform) != TargetPlatform.iOS) return;

  http.Client client;
  try {
    client = (clientFactory ?? _createConnectivityClient)();
  } catch (error) {
    debugPrint('[Startup] iOS network preparation unavailable: $error');
    return;
  }

  final binding = WidgetsBinding.instance;
  var lifecycle = binding.lifecycleState;
  var receivedResponse = false;
  var requestInFlight = false;
  var retryAfterResume = false;
  var clientClosed = false;
  final ready = Completer<void>();
  final abort = Completer<void>();
  Timer? foregroundTimer;

  bool canContinue() =>
      lifecycle == null ||
      lifecycle == AppLifecycleState.detached ||
      lifecycle == AppLifecycleState.resumed;

  void finish() {
    if (!ready.isCompleted) ready.complete();
  }

  void closeClient() {
    if (clientClosed) return;
    clientClosed = true;
    try {
      client.close();
    } catch (error) {
      debugPrint('[Startup] iOS network cleanup failed: $error');
    }
  }

  void updateForegroundWait() {
    foregroundTimer?.cancel();
    if (ready.isCompleted || !canContinue()) return;
    if (receivedResponse) {
      finish();
      return;
    }
    foregroundTimer = Timer(foregroundTimeout, () {
      debugPrint('[Startup] iOS network unavailable; continuing offline');
      finish();
    });
  }

  Future<void> probe() async {
    if (ready.isCompleted || requestInFlight) return;
    requestInFlight = true;
    retryAfterResume = false;
    try {
      // A HEAD response, including 4xx/5xx, proves connectivity without
      // depending on Gateway registration, authentication or a response body.
      final request = http.AbortableRequest(
        'HEAD',
        probeUri,
        abortTrigger: abort.future,
      )..followRedirects = false;
      final response = await client.send(request);
      if (!ready.isCompleted) {
        receivedResponse = true;
        if (canContinue()) finish();
      }
      // Headers can arrive before URLSession removes the running task. Drain
      // late responses too so cleanup waits for completion or cancellation.
      await response.stream.drain<void>();
    } catch (error) {
      if (!ready.isCompleted) {
        debugPrint('[Startup] iOS network preparation pending: $error');
      }
    } finally {
      requestInFlight = false;
      if (ready.isCompleted) closeClient();
      // The prompt may close before the pre-authorization request fails.
      // In that order, still issue the pending post-authorization probe.
      if (!ready.isCompleted && retryAfterResume && !receivedResponse) {
        unawaited(probe());
      }
    }
  }

  final observer = AppLifecycleListener(
    binding: binding,
    onStateChange: (state) {
      lifecycle = state;
      updateForegroundWait();
      if (state == AppLifecycleState.resumed && !receivedResponse) {
        if (requestInFlight) {
          retryAfterResume = true;
        } else {
          unawaited(probe());
        }
      }
    },
  );

  try {
    updateForegroundWait();
    unawaited(probe());
    await ready.future;
  } finally {
    foregroundTimer?.cancel();
    observer.dispose();
    abort.complete();
    // Aborting is asynchronous. Let probe() close the client after the native
    // task finishes; cleanup must not delay or throw out of startup.
    if (!requestInFlight) closeClient();
  }
}

http.Client _createConnectivityClient() {
  final configuration = URLSessionConfiguration.ephemeralSessionConfiguration()
    ..waitsForConnectivity = true
    ..timeoutIntervalForRequest = const Duration(seconds: 8);
  return CupertinoClient.fromSessionConfiguration(configuration);
}
