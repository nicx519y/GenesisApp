import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ui/components/genesis_static_network_image.dart';

const LinearGradient originItemCoverGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[Color(0x00111111), Color(0xFF111111)],
);

/// Produces one decoded cover image with the footer transition already
/// composited into its pixels.
///
/// The source frame is released after composition so an item does not retain
/// separate source-image and gradient paint paths while it is on screen.
@immutable
class OriginItemCoverImageProvider
    extends ImageProvider<OriginItemCoverImageProvider> {
  const OriginItemCoverImageProvider({
    required this.sourceProvider,
    required this.fallbackProvider,
    required this.outputWidth,
    required this.outputHeight,
    required this.transitionHeight,
  }) : assert(outputWidth > 0),
       assert(outputHeight > 0),
       assert(transitionHeight > 0);

  factory OriginItemCoverImageProvider.fromUrl({
    required String imageUrl,
    required String fallbackAsset,
    required int outputWidth,
    required int outputHeight,
    required int transitionHeight,
  }) {
    final normalizedUrl = imageUrl.trim();
    final fallbackProvider = AssetImage(fallbackAsset);
    final ImageProvider<Object> sourceProvider = normalizedUrl.isEmpty
        ? fallbackProvider
        : normalizedUrl.startsWith('assets/')
        ? AssetImage(normalizedUrl)
        : GenesisStaticNetworkImageProvider(
            imageUrl: normalizedUrl,
            cacheWidth: outputWidth,
            cacheHeight: outputHeight,
            fit: BoxFit.cover,
          );
    return OriginItemCoverImageProvider(
      sourceProvider: sourceProvider,
      fallbackProvider: fallbackProvider,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
      transitionHeight: transitionHeight,
    );
  }

  final ImageProvider<Object> sourceProvider;
  final ImageProvider<Object> fallbackProvider;
  final int outputWidth;
  final int outputHeight;
  final int transitionHeight;

  @override
  Future<OriginItemCoverImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<OriginItemCoverImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    OriginItemCoverImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      key._loadCompositeImage(),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider<Object>>(
          'Origin item cover source',
          key.sourceProvider,
        ),
        IntProperty('Output width', key.outputWidth),
        IntProperty('Output height', key.outputHeight),
        IntProperty('Transition height', key.transitionHeight),
      ],
    );
  }

  Future<ImageInfo> _loadCompositeImage() async {
    _LoadedSource? source;
    try {
      try {
        source = await _loadSource(sourceProvider);
      } catch (_) {
        if (sourceProvider == fallbackProvider) rethrow;
        source = await _loadSource(fallbackProvider);
      }
      final compositeImage = await composeOriginItemCoverImage(
        sourceImage: source.info.image,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
        transitionHeight: transitionHeight,
      );
      return ImageInfo(
        image: compositeImage,
        scale: 1,
        debugLabel: 'origin-item-cover-composite',
      );
    } finally {
      if (source case final loaded?) {
        loaded.info.dispose();
        PaintingBinding.instance.imageCache.evict(loaded.key);
      }
    }
  }

  Future<_LoadedSource> _loadSource(ImageProvider<Object> provider) async {
    const configuration = ImageConfiguration.empty;
    final sourceKey = await provider.obtainKey(configuration);
    final sourceStream = provider.resolve(configuration);
    final sourceFrame = Completer<ImageInfo>();
    late final ImageStreamListener sourceListener;
    sourceListener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        if (!sourceFrame.isCompleted) {
          sourceFrame.complete(imageInfo);
        } else {
          imageInfo.dispose();
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!sourceFrame.isCompleted) {
          sourceFrame.completeError(error, stackTrace ?? StackTrace.current);
        }
      },
    );
    sourceStream.addListener(sourceListener);
    try {
      return _LoadedSource(info: await sourceFrame.future, key: sourceKey);
    } finally {
      sourceStream.removeListener(sourceListener);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is OriginItemCoverImageProvider &&
        other.sourceProvider == sourceProvider &&
        other.fallbackProvider == fallbackProvider &&
        other.outputWidth == outputWidth &&
        other.outputHeight == outputHeight &&
        other.transitionHeight == transitionHeight;
  }

  @override
  int get hashCode => Object.hash(
    sourceProvider,
    fallbackProvider,
    outputWidth,
    outputHeight,
    transitionHeight,
  );
}

@immutable
class _LoadedSource {
  const _LoadedSource({required this.info, required this.key});

  final ImageInfo info;
  final Object key;
}

@visibleForTesting
Future<ui.Image> composeOriginItemCoverImage({
  required ui.Image sourceImage,
  required int outputWidth,
  required int outputHeight,
  required int transitionHeight,
}) async {
  assert(outputWidth > 0);
  assert(outputHeight > 0);
  assert(transitionHeight > 0);
  final outputRect = Rect.fromLTWH(
    0,
    0,
    outputWidth.toDouble(),
    outputHeight.toDouble(),
  );
  final effectiveTransitionHeight = transitionHeight.clamp(1, outputHeight);
  final transitionRect = Rect.fromLTWH(
    0,
    (outputHeight - effectiveTransitionHeight).toDouble(),
    outputWidth.toDouble(),
    effectiveTransitionHeight.toDouble(),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintImage(
    canvas: canvas,
    rect: outputRect,
    image: sourceImage,
    fit: BoxFit.cover,
    alignment: Alignment.center,
    filterQuality: FilterQuality.medium,
  );
  canvas.drawRect(
    transitionRect,
    Paint()..shader = originItemCoverGradient.createShader(transitionRect),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(outputWidth, outputHeight);
  } finally {
    picture.dispose();
  }
}
