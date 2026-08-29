import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const int originItemCoverMaxConcurrentLoads = 4;

/// Limits first-frame image work shared by all cards on the Worldo lists.
class OriginItemCoverLoadLimiter {
  OriginItemCoverLoadLimiter({required this.maxConcurrentLoads})
    : assert(maxConcurrentLoads > 0);

  final int maxConcurrentLoads;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  var _activeLoads = 0;

  Future<T> schedule<T>(Future<T> Function() load) async {
    await _acquire();
    try {
      return await load();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_activeLoads < maxConcurrentLoads) {
      _activeLoads += 1;
      return;
    }
    final waiter = Completer<void>();
    _waiters.addLast(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }
    _activeLoads -= 1;
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
  }) : loadLimiter = loadLimiter ?? _sharedOriginItemCoverLoadLimiter;

  final ImageProvider<Object> sourceProvider;
  final OriginItemCoverLoadLimiter loadLimiter;

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
      key.loadLimiter.schedule(() => key._loadFirstFrame(decode)),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider<Object>>(
          'Origin item cover source',
          key.sourceProvider,
        ),
        IntProperty(
          'Maximum concurrent loads',
          key.loadLimiter.maxConcurrentLoads,
        ),
      ],
    );
  }

  Future<ImageInfo> _loadFirstFrame(ImageDecoderCallback decode) async {
    const configuration = ImageConfiguration.empty;
    final sourceKey = await sourceProvider.obtainKey(configuration);
    final sourceCompleter = sourceProvider.loadImage(sourceKey, decode);
    final frame = Completer<ImageInfo>();
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
    try {
      return await frame.future;
    } finally {
      sourceCompleter.removeListener(listener);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is OriginItemCoverThrottledImageProvider &&
        other.sourceProvider == sourceProvider &&
        identical(other.loadLimiter, loadLimiter);
  }

  @override
  int get hashCode =>
      Object.hash(sourceProvider, identityHashCode(loadLimiter));
}
