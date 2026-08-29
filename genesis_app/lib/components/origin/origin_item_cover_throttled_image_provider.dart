import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const int originItemCoverMaxConcurrentLoads = 4;
const int originItemCoverMaxPendingLoads = 24;
const Duration originItemCoverLoadTimeout = Duration(seconds: 15);

class OriginItemCoverLoadCancelledException implements Exception {
  const OriginItemCoverLoadCancelledException();

  @override
  String toString() => 'Origin item cover load was cancelled or superseded';
}

class OriginItemCoverLoadCancellationToken {
  final Set<VoidCallback> _listeners = <VoidCallback>{};
  var _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    final listeners = List<VoidCallback>.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }
}

/// Limits first-frame image work shared by all cards on the Worldo lists.
class OriginItemCoverLoadLimiter {
  OriginItemCoverLoadLimiter({
    required this.maxConcurrentLoads,
    this.maxPendingLoads = originItemCoverMaxPendingLoads,
  }) : assert(maxConcurrentLoads > 0),
       assert(maxPendingLoads >= 0);

  final int maxConcurrentLoads;
  final int maxPendingLoads;
  final Queue<_OriginItemCoverLoadJob> _waiters =
      Queue<_OriginItemCoverLoadJob>();
  var _activeLoads = 0;

  @visibleForTesting
  int get activeLoadCount => _activeLoads;

  @visibleForTesting
  int get pendingLoadCount => _waiters.length;

  Future<T> schedule<T>(
    Future<T> Function() load, {
    OriginItemCoverLoadCancellationToken? cancellationToken,
  }) {
    final job = _TypedOriginItemCoverLoadJob<T>(load);
    void handleCancellation() {
      if (job.hasStarted) return;
      _waiters.remove(job);
      job.cancel();
    }

    job.onSettled = cancellationToken == null
        ? null
        : () => cancellationToken.removeListener(handleCancellation);
    cancellationToken?.addListener(handleCancellation);
    if (job.isCancelled) return job.future;

    if (_activeLoads < maxConcurrentLoads) {
      _start(job);
      return job.future;
    }

    if (maxPendingLoads == 0) {
      job.cancel();
      return job.future;
    }
    while (_waiters.length >= maxPendingLoads) {
      _waiters.removeFirst().cancel();
    }
    _waiters.addLast(job);
    return job.future;
  }

  void _start(_OriginItemCoverLoadJob job) {
    _activeLoads += 1;
    unawaited(job.run().whenComplete(_release));
  }

  void _release() {
    _activeLoads -= 1;
    while (_waiters.isNotEmpty) {
      // Newer requests are more likely to still be close to the viewport.
      final next = _waiters.removeLast();
      if (next.isCancelled) continue;
      _start(next);
      return;
    }
  }
}

abstract interface class _OriginItemCoverLoadJob {
  bool get isCancelled;

  bool get hasStarted;

  set onSettled(VoidCallback? callback);

  Future<void> run();

  void cancel();
}

class _TypedOriginItemCoverLoadJob<T> implements _OriginItemCoverLoadJob {
  _TypedOriginItemCoverLoadJob(this._load);

  final Future<T> Function() _load;
  final Completer<T> _completer = Completer<T>();
  var _started = false;
  var _cancelled = false;
  var _settled = false;

  @override
  VoidCallback? onSettled;

  Future<T> get future => _completer.future;

  @override
  bool get isCancelled => _cancelled;

  @override
  bool get hasStarted => _started;

  @override
  void cancel() {
    if (_started || _cancelled) return;
    _cancelled = true;
    _completer.completeError(const OriginItemCoverLoadCancelledException());
    _notifySettled();
  }

  @override
  Future<void> run() async {
    if (_cancelled) return;
    _started = true;
    try {
      final result = await _load();
      if (!_completer.isCompleted) _completer.complete(result);
    } catch (error, stackTrace) {
      if (!_completer.isCompleted) {
        _completer.completeError(error, stackTrace);
      }
    } finally {
      _notifySettled();
    }
  }

  void _notifySettled() {
    if (_settled) return;
    _settled = true;
    onSettled?.call();
    onSettled = null;
  }
}

final OriginItemCoverLoadLimiter _sharedOriginItemCoverLoadLimiter =
    OriginItemCoverLoadLimiter(
      maxConcurrentLoads: originItemCoverMaxConcurrentLoads,
    );

/// Resolves an Origin list cover only after entering the shared four-slot
/// loading queue. The decoded frame is cached under this provider's key, so
/// the source provider is loaded directly without adding a duplicate image
/// cache entry.
@immutable
class OriginItemCoverThrottledImageProvider
    extends ImageProvider<OriginItemCoverThrottledImageProvider> {
  OriginItemCoverThrottledImageProvider({
    required this.sourceProvider,
    OriginItemCoverLoadLimiter? loadLimiter,
    this.cancellationToken,
    this.loadTimeout = originItemCoverLoadTimeout,
  }) : assert(loadTimeout > Duration.zero),
       loadLimiter = loadLimiter ?? _sharedOriginItemCoverLoadLimiter;

  final ImageProvider<Object> sourceProvider;
  final OriginItemCoverLoadLimiter loadLimiter;
  final OriginItemCoverLoadCancellationToken? cancellationToken;
  final Duration loadTimeout;

  @override
  Future<OriginItemCoverThrottledImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<OriginItemCoverThrottledImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    OriginItemCoverThrottledImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      key.loadLimiter.schedule(
        () => key._loadFirstFrame(decode),
        cancellationToken: key.cancellationToken,
      ),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider<Object>>(
          'Origin item cover source',
          key.sourceProvider,
        ),
        IntProperty(
          'Maximum concurrent loads',
          key.loadLimiter.maxConcurrentLoads,
        ),
        IntProperty('Maximum pending loads', key.loadLimiter.maxPendingLoads),
        DiagnosticsProperty<Duration>('Load timeout', key.loadTimeout),
      ],
    );
  }

  Future<ImageInfo> _loadFirstFrame(ImageDecoderCallback decode) async {
    final token = cancellationToken;
    if (token?.isCancelled ?? false) {
      throw const OriginItemCoverLoadCancelledException();
    }
    const configuration = ImageConfiguration.empty;
    final sourceKey = await sourceProvider.obtainKey(configuration);
    if (token?.isCancelled ?? false) {
      throw const OriginItemCoverLoadCancelledException();
    }
    final sourceCompleter = sourceProvider.loadImage(sourceKey, decode);
    final frame = Completer<ImageInfo>();
    final cancelled = Completer<ImageInfo>();
    void handleCancellation() {
      if (!cancelled.isCompleted) {
        cancelled.completeError(const OriginItemCoverLoadCancelledException());
      }
    }

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        if (!frame.isCompleted) frame.complete(imageInfo.clone());
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!frame.isCompleted) {
          frame.completeError(error, stackTrace ?? StackTrace.current);
        }
      },
    );
    sourceCompleter.addListener(listener);
    token?.addListener(handleCancellation);
    try {
      final firstResult = token == null
          ? frame.future
          : Future.any<ImageInfo>(<Future<ImageInfo>>[
              frame.future,
              cancelled.future,
            ]);
      return await firstResult.timeout(
        loadTimeout,
        onTimeout: () => throw TimeoutException(
          'Origin item cover did not produce a frame within $loadTimeout',
        ),
      );
    } finally {
      token?.removeListener(handleCancellation);
      sourceCompleter.removeListener(listener);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is OriginItemCoverThrottledImageProvider &&
        other.sourceProvider == sourceProvider &&
        identical(other.loadLimiter, loadLimiter) &&
        other.loadTimeout == loadTimeout;
  }

  @override
  int get hashCode =>
      Object.hash(sourceProvider, identityHashCode(loadLimiter), loadTimeout);
}
