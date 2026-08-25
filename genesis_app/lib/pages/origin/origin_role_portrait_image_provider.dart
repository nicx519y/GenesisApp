import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ui/components/genesis_static_network_image.dart';

// 卡片暗色族全部走深墨系(#151517 -> #0E0D10):中明度的灰紫
// (redesignRaised #1F1D24)叠在模糊图上会把阴影"抬灰",显得糊;
// 深墨只压暗不泛灰。最底部锚定比浮窗背景更深一档的 #0E0D10 收底。
const LinearGradient originRolePortraitGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  stops: <double>[0.42, 0.72, 1],
  colors: <Color>[Colors.transparent, Color(0x66151517), Color(0xF00E0D10)],
);

/// Produces the role-card portrait as one decoded image with its readability
/// gradient already composited into the pixels.
///
/// The output keeps the card's own aspect ratio and crops the source with a
/// top-anchored cover fit, so a portrait keeps its head in frame instead of
/// being squared off around the center first.
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
    required this.outputWidth,
    required this.outputHeight,
  }) : assert(outputWidth > 0),
       assert(outputHeight > 0);

  factory OriginRolePortraitImageProvider.fromUrl({
    required String imageUrl,
    required int outputWidth,
    required int outputHeight,
  }) {
    final normalizedUrl = imageUrl.trim();
    assert(normalizedUrl.isNotEmpty);
    final ImageProvider<Object> sourceProvider =
        normalizedUrl.startsWith('assets/')
        ? AssetImage(normalizedUrl)
        : GenesisStaticNetworkImageProvider(
            imageUrl: normalizedUrl,
            cacheWidth: outputWidth,
            cacheHeight: outputHeight,
            fit: BoxFit.cover,
          );
    return OriginRolePortraitImageProvider(
      sourceProvider: sourceProvider,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
    );
  }

  final ImageProvider<Object> sourceProvider;
  final int outputWidth;
  final int outputHeight;

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
        IntProperty('Output pixel width', key.outputWidth),
        IntProperty('Output pixel height', key.outputHeight),
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
        outputWidth: outputWidth,
        outputHeight: outputHeight,
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
        other.outputWidth == outputWidth &&
        other.outputHeight == outputHeight;
  }

  @override
  int get hashCode => Object.hash(sourceProvider, outputWidth, outputHeight);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'OriginRolePortraitImageProvider')}'
        '(source: $sourceProvider, '
        'outputWidth: $outputWidth, outputHeight: $outputHeight)';
  }
}

@visibleForTesting
Future<ui.Image> composeOriginRolePortraitImage({
  required ui.Image sourceImage,
  required int outputWidth,
  required int outputHeight,
}) async {
  assert(outputWidth > 0);
  assert(outputHeight > 0);
  final outputRect = Rect.fromLTWH(
    0,
    0,
    outputWidth.toDouble(),
    outputHeight.toDouble(),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // Design 9i anchors the portrait to the top edge (object-position 50% 0%)
  // and relies on tall source art to fill the card without a visible crop.
  // Sources at least as tall as the card follow that cover crop exactly. A
  // square or landscape avatar keeps its full width at the top instead, over
  // a blurred, dimmed cover-scaled copy of the same art; the sharp layer's
  // bottom edge is feathered into that backdrop so the card reads as one
  // continuous rectangle of artwork with no visible seam.
  final sourceIsAsTallAsCard =
      sourceImage.height * outputWidth >= sourceImage.width * outputHeight;
  if (sourceIsAsTallAsCard) {
    paintImage(
      canvas: canvas,
      rect: outputRect,
      image: sourceImage,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.medium,
    );
  } else {
    final blurSigma = outputWidth * 0.08;
    canvas.saveLayer(
      outputRect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: ui.TileMode.clamp,
        ),
    );
    paintImage(
      canvas: canvas,
      rect: outputRect,
      image: sourceImage,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.low,
    );
    canvas.restore();
    // 模糊底压暗 55%,用深墨 #0E0D10 而不是灰紫 raised —— 后者会泛灰。
    canvas.drawRect(outputRect, Paint()..color = const Color(0x8C0E0D10));

    final sharpHeight = outputWidth * sourceImage.height / sourceImage.width;
    final sharpRect = Rect.fromLTWH(0, 0, outputRect.width, sharpHeight);
    final featherTop = sharpHeight * 0.72;
    canvas.saveLayer(sharpRect, Paint());
    paintImage(
      canvas: canvas,
      rect: outputRect,
      image: sourceImage,
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      filterQuality: FilterQuality.medium,
    );
    canvas.drawRect(
      sharpRect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.linear(
          Offset(0, featherTop),
          Offset(0, sharpHeight),
          const <Color>[Color(0xFFFFFFFF), Color(0x00FFFFFF)],
        ),
    );
    canvas.restore();
  }
  canvas.drawRect(
    outputRect,
    Paint()..shader = originRolePortraitGradient.createShader(outputRect),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(outputWidth, outputHeight);
  } finally {
    picture.dispose();
  }
}
