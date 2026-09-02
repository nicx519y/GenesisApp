import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ui/components/genesis_static_network_image.dart';

const LinearGradient originRolePortraitGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: <double>[0.42, 0.72, 1],
  colors: <Color>[Colors.transparent, Color(0x66151517), Color(0xFF0E0D10)],
);

/// Produces the role-card portrait as one decoded image with its readability
/// gradient already composited into the pixels.
///
/// The source frame is needed only while [loadImage] is composing the result.
/// Once composition finishes, its listener-owned image handle is disposed and
/// its exact source key is evicted from Flutter's in-memory [ImageCache]. The
/// underlying asset or HTTP disk cache is intentionally left untouched.
@immutable
class OriginRolePortraitImageProvider
    extends ImageProvider<OriginRolePortraitImageProvider> {
  const OriginRolePortraitImageProvider({
    required this.sourceProvider,
    required this.outputSize,
  }) : assert(outputSize > 0);

  factory OriginRolePortraitImageProvider.fromUrl({
    required String imageUrl,
    required int outputSize,
  }) {
    final normalizedUrl = imageUrl.trim();
    assert(normalizedUrl.isNotEmpty);
    final ImageProvider<Object> sourceProvider =
        normalizedUrl.startsWith('assets/')
        ? AssetImage(normalizedUrl)
        : GenesisStaticNetworkImageProvider(
            imageUrl: normalizedUrl,
            cacheWidth: outputSize,
            cacheHeight: outputSize,
            fit: BoxFit.cover,
          );
    return OriginRolePortraitImageProvider(
      sourceProvider: sourceProvider,
      outputSize: outputSize,
    );
  }

  final ImageProvider<Object> sourceProvider;
  final int outputSize;

  @override
  Future<OriginRolePortraitImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<OriginRolePortraitImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    OriginRolePortraitImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      key._loadCompositeImage(),
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider<Object>>(
          'Role portrait source',
          key.sourceProvider,
        ),
        IntProperty('Output pixel size', key.outputSize),
      ],
    );
  }

  Future<ImageInfo> _loadCompositeImage() async {
    const configuration = ImageConfiguration.empty;
    final sourceKey = await sourceProvider.obtainKey(configuration);
    final sourceStream = sourceProvider.resolve(configuration);
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

    ImageInfo? sourceInfo;
    try {
      sourceInfo = await sourceFrame.future;
      final compositeImage = await composeOriginRolePortraitImage(
        sourceImage: sourceInfo.image,
        outputSize: outputSize,
      );
      return ImageInfo(
        image: compositeImage,
        scale: 1,
        debugLabel: 'origin-role-portrait-composite',
      );
    } finally {
      sourceStream.removeListener(sourceListener);
      sourceInfo?.dispose();
      PaintingBinding.instance.imageCache.evict(sourceKey);
    }
  }

  @override
  bool operator ==(Object other) {
    return other is OriginRolePortraitImageProvider &&
        other.sourceProvider == sourceProvider &&
        other.outputSize == outputSize;
  }

  @override
  int get hashCode => Object.hash(sourceProvider, outputSize);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'OriginRolePortraitImageProvider')}'
        '(source: $sourceProvider, outputSize: $outputSize)';
  }
}

@visibleForTesting
Future<ui.Image> composeOriginRolePortraitImage({
  required ui.Image sourceImage,
  required int outputSize,
}) async {
  assert(outputSize > 0);
  final outputRect = Rect.fromLTWH(
    0,
    0,
    outputSize.toDouble(),
    outputSize.toDouble(),
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
    outputRect,
    Paint()..shader = originRolePortraitGradient.createShader(outputRect),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(outputSize, outputSize);
  } finally {
    picture.dispose();
  }
}
