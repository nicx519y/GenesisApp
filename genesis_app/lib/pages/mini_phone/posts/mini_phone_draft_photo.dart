import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../utils/genesis_image_resource.dart';

/// Keeps upload bytes intact while decoding only enough pixels for the preview.
ImageProvider miniPhoneDraftPhotoProvider(
  Uint8List bytes, {
  required double devicePixelRatio,
}) {
  final ratio = genesisImageDevicePixelRatio(devicePixelRatio);
  return MiniPhoneDraftPhotoProvider(
    bytes,
    width: (108 * ratio).ceil(),
    height: (144 * ratio).ceil(),
  );
}

@immutable
class MiniPhoneDraftPhotoProvider
    extends ImageProvider<MiniPhoneDraftPhotoProvider> {
  const MiniPhoneDraftPhotoProvider(
    this.bytes, {
    required this.width,
    required this.height,
  });
  final Uint8List bytes;
  final int width, height;

  @override
  Future<MiniPhoneDraftPhotoProvider> obtainKey(
    ImageConfiguration configuration,
  ) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    MiniPhoneDraftPhotoProvider key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _decode(decode), scale: 1);

  Future<ui.Codec> _decode(ImageDecoderCallback decode) async => decode(
    await ui.ImmutableBuffer.fromUint8List(bytes),
    getTargetSize: (intrinsicWidth, intrinsicHeight) {
      // Preserve aspect ratio and sufficient resolution for BoxFit.cover.
      final scale = math.min(
        1.0,
        math.max(width / intrinsicWidth, height / intrinsicHeight),
      );
      return ui.TargetImageSize(
        width: math.max(1, (intrinsicWidth * scale).ceil()),
        height: math.max(1, (intrinsicHeight * scale).ceil()),
      );
    },
  );

  @override
  bool operator ==(Object other) =>
      other is MiniPhoneDraftPhotoProvider &&
      identical(bytes, other.bytes) &&
      width == other.width &&
      height == other.height;
  @override
  int get hashCode => Object.hash(identityHashCode(bytes), width, height);
}
