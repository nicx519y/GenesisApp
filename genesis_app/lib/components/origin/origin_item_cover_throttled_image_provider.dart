import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../network/http_transport.dart';

const int originItemCoverMaxConcurrentLoads = 6;
const int originItemCoverMaxConcurrentPrefetchLoads = 1;
const int originItemCoverMaxPendingLoads = 24;
const Duration originItemCoverLoadTimeout = Duration(seconds: 15);

enum OriginItemCoverLoadPriority { disabled, prefetch, visible }

class OriginItemCoverLoadCancelledException implements Exception {
  const OriginItemCoverLoadCancelledException();

  @override
  String toString() => 'Origin item cover load was cancelled or superseded';
}

class OriginItemCoverLoadCancellationToken {
  final Set<VoidCallback> _listeners = <VoidCallback>{};
  final NetworkCancellationToken networkToken = NetworkCancellationToken();
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
    networkToken.cancel();
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
    this.maxConcurrentPrefetchLoads = originItemCoverMaxConcurrentPrefetchLoads,
    this.maxPendingLoads = originItemCoverMaxPendingLoads,
  }) : assert(maxConcurrentLoads > 0),
       assert(maxConcurrentPrefetchLoads >= 0),
       assert(maxConcurrentPrefetchLoads <= maxConcurrentLoads),
       assert(maxPendingLoads >= 0);

  final int maxConcurrentLoads;
  final int maxConcurrentPrefetchLoads;
  final int maxPendingLoads;
  final Queue<_OriginItemCoverLoadJob> _visibleWaiters =
      Queue<_OriginItemCoverLoadJob>();
  final Queue<_OriginItemCoverLoadJob> _prefetchWaiters =
      Queue<_OriginItemCoverLoadJob>();
  var _activeLoads = 0;
  var _activePrefetchLoads = 0;

  @visibleForTesting
  int get activeLoadCount => _activeLoads;

  @visibleForTesting
  int get activePrefetchLoadCount => _activePrefetchLoads;

  @visibleForTesting
  int get pendingLoadCount => _visibleWaiters.length + _prefetchWaiters.length;

  Future<T> schedule<T>(
    Future<T> Function() load, {
    OriginItemCoverLoadCancellationToken? cancellationToken,
    ValueListenable<OriginItemCoverLoadPriority>? priorityListenable,
  }) {
    final job = _TypedOriginItemCoverLoadJob<T>(
      load,
      priority:
          priorityListenable?.value ?? OriginItemCoverLoadPriority.visible,
    );
    void handleCancellation() {
      if (job.hasStarted) return;
      _removePending(job);
      job.cancel();
      _drain();
    }

    void handlePriorityChange() {
      if (job.hasStarted || job.isCancelled) return;
      final nextPriority =
          priorityListenable?.value ?? OriginItemCoverLoadPriority.visible;
      if (job.priority == nextPriority) return;
      _removePending(job);
      job.priority = nextPriority;
      if (nextPriority == OriginItemCoverLoadPriority.disabled) {
        job.cancel();
      } else {
        _enqueue(job);
      }
      _drain();
    }

    job.onSettled = () {
      cancellationToken?.removeListener(handleCancellation);
      priorityListenable?.removeListener(handlePriorityChange);
    };
    priorityListenable?.addListener(handlePriorityChange);
    cancellationToken?.addListener(handleCancellation);
    if (job.isCancelled) return job.future;

    if (job.priority == OriginItemCoverLoadPriority.disabled) {
      job.cancel();
      return job.future;
    }

    if (maxPendingLoads == 0) {
      if (_canStart(job)) {
        _start(job);
      } else {
        job.cancel();
      }
      return job.future;
    }
    while (pendingLoadCount >= maxPendingLoads) {
      final superseded = _prefetchWaiters.isNotEmpty
          ? _prefetchWaiters.removeFirst()
          : _visibleWaiters.removeFirst();
      superseded.cancel();
    }
    _enqueue(job);
    _drain();
    return job.future;
  }

  void _enqueue(_OriginItemCoverLoadJob job) {
    switch (job.priority) {
      case OriginItemCoverLoadPriority.visible:
        _visibleWaiters.addLast(job);
        return;
      case OriginItemCoverLoadPriority.prefetch:
        _prefetchWaiters.addLast(job);
        return;
      case OriginItemCoverLoadPriority.disabled:
        job.cancel();
        return;
    }
  }

  void _removePending(_OriginItemCoverLoadJob job) {
    _visibleWaiters.remove(job);
    _prefetchWaiters.remove(job);
  }

  bool _canStart(_OriginItemCoverLoadJob job) {
    if (_activeLoads >= maxConcurrentLoads) return false;
    return job.priority == OriginItemCoverLoadPriority.visible ||
        _activePrefetchLoads < maxConcurrentPrefetchLoads;
  }

  void _drain() {
    while (_activeLoads < maxConcurrentLoads) {
      _OriginItemCoverLoadJob? next;
      while (_visibleWaiters.isNotEmpty && next == null) {
        final candidate = _visibleWaiters.removeLast();
        if (!candidate.isCancelled) next = candidate;
      }
      while (next == null &&
          _activePrefetchLoads < maxConcurrentPrefetchLoads &&
          _prefetchWaiters.isNotEmpty) {
        final candidate = _prefetchWaiters.removeLast();
        if (!candidate.isCancelled) next = candidate;
      }
      if (next == null) return;
      _start(next);
    }
  }

  void _start(_OriginItemCoverLoadJob job) {
    _activeLoads += 1;
    final startedAsPrefetch =
        job.priority == OriginItemCoverLoadPriority.prefetch;
    if (startedAsPrefetch) _activePrefetchLoads += 1;
    unawaited(
      job.run().whenComplete(
        () => _release(startedAsPrefetch: startedAsPrefetch),
      ),
    );
  }

  void _release({required bool startedAsPrefetch}) {
    _activeLoads -= 1;
    if (startedAsPrefetch) _activePrefetchLoads -= 1;
    _drain();
  }
}

abstract interface class _OriginItemCoverLoadJob {
  OriginItemCoverLoadPriority get priority;

  set priority(OriginItemCoverLoadPriority value);

  bool get isCancelled;

  bool get hasStarted;

  set onSettled(VoidCallback? callback);

  Future<void> run();

  void cancel();
}

class _TypedOriginItemCoverLoadJob<T> implements _OriginItemCoverLoadJob {
  _TypedOriginItemCoverLoadJob(this._load, {required this.priority});

  final Future<T> Function() _load;
  final Completer<T> _completer = Completer<T>();
  @override
  OriginItemCoverLoadPriority priority;
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

/// Resolves an Origin list cover only after entering the shared six-slot
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
    this.priorityListenable,
    this.loadTimeout = originItemCoverLoadTimeout,
  }) : assert(loadTimeout > Duration.zero),
       loadLimiter = loadLimiter ?? _sharedOriginItemCoverLoadLimiter;

  final ImageProvider<Object> sourceProvider;
  final OriginItemCoverLoadLimiter loadLimiter;
  final OriginItemCoverLoadCancellationToken? cancellationToken;
  final ValueListenable<OriginItemCoverLoadPriority>? priorityListenable;
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
    final completer = OneFrameImageStreamCompleter(
      key.loadLimiter.schedule(
        () => key._loadFirstFrame(decode),
        cancellationToken: key.cancellationToken,
        priorityListenable: key.priorityListenable,
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
        EnumProperty<OriginItemCoverLoadPriority>(
          'Load priority',
          key.priorityListenable?.value,
        ),
        DiagnosticsProperty<Duration>('Load timeout', key.loadTimeout),
      ],
    );
    completer.addEphemeralErrorListener((_, _) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    return completer;
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
