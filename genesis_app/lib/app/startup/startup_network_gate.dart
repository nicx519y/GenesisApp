import 'dart:async';

import '../../network/api_client.dart';
import '../../network/http_transport.dart';

class StartupNetworkGate {
  StartupNetworkGate({bool initiallyOpen = false}) {
    if (initiallyOpen) _ready.complete();
  }

  StartupNetworkGate.open() : this(initiallyOpen: true);

  final Completer<void> _ready = Completer<void>();

  bool get isOpen => _ready.isCompleted;

  Future<void> get ready => _ready.future;

  void open() {
    if (_ready.isCompleted) return;
    _ready.complete();
  }

  ApiRequestInterceptor wrap(ApiRequestInterceptor? next) {
    return (request, send) async {
      await _waitUntilReady(request.cancellationToken);
      if (next == null) return send(request);
      return next(request, send);
    };
  }

  Future<void> _waitUntilReady(NetworkCancellationToken? cancellationToken) {
    if (_ready.isCompleted) return Future<void>.value();
    if (cancellationToken == null) return _ready.future;
    cancellationToken.throwIfCancelled();
    final cancelled = Completer<void>();
    late final void Function() removeListener;
    removeListener = cancellationToken.addCancelListener(() {
      if (!cancelled.isCompleted) {
        cancelled.completeError(const NetworkRequestCancelledException());
      }
    });
    return Future.any<void>([
      _ready.future,
      cancelled.future,
    ]).whenComplete(removeListener);
  }
}
