import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/origin/origin_role_portrait_image_provider.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('composites the gradient and evicts the decoded source frame', (
    tester,
  ) async {
    final sourceProvider = _SolidImageProvider(color: const Color(0xFFFF0000));
    final provider = OriginRolePortraitImageProvider(
      sourceProvider: sourceProvider,
      outputWidth: 12,
      outputHeight: 16,
    );
    ImageInfo? imageInfo;

    await tester.runAsync(() async {
      imageInfo = await _resolveImage(provider);
    });

    final composite = imageInfo;
    expect(composite, isNotNull);
    expect(composite!.image.width, 12);
    expect(composite.image.height, 16);
    final sourceStatus = await sourceProvider.obtainCacheStatus(
      configuration: ImageConfiguration.empty,
    );
    expect(sourceStatus, isNotNull);
    expect(sourceStatus!.untracked, isTrue);

    ByteData? pixels;
    await tester.runAsync(() async {
      pixels = await composite.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
    });
    final data = pixels;
    expect(data, isNotNull);
    final topRed = _redChannel(data!, x: 6, y: 1, width: 12);
    final bottomRed = _redChannel(data, x: 6, y: 15, width: 12);
    expect(topRed, greaterThan(230));
    expect(bottomRed, lessThan(topRed));

    composite.dispose();
    await provider.evict();
  });

  testWidgets('keeps a square source un-cropped over a blurred backdrop', (
    tester,
  ) async {
    final sourceProvider = _SolidImageProvider(
      color: const Color(0xFFFF0000),
      width: 16,
      height: 16,
    );
    final provider = OriginRolePortraitImageProvider(
      sourceProvider: sourceProvider,
      outputWidth: 12,
      outputHeight: 16,
    );
    ImageInfo? imageInfo;

    await tester.runAsync(() async {
      imageInfo = await _resolveImage(provider);
    });

    final composite = imageInfo;
    expect(composite, isNotNull);
    expect(composite!.image.width, 12);
    expect(composite.image.height, 16);

    ByteData? pixels;
    await tester.runAsync(() async {
      pixels = await composite.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
    });
    final data = pixels;
    expect(data, isNotNull);
    // fitWidth draws the 16x16 source as 12x12 at the top; the row below the
    // artwork is filled by the blurred, dimmed cover backdrop (still clearly
    // red-tinted but darker than the sharp art), proving the sides were not
    // cover-cropped away and the card bottom is no longer empty.
    final topRed = _redChannel(data!, x: 6, y: 1, width: 12);
    final topAlpha = _alphaChannel(data, x: 6, y: 1, width: 12);
    final belowArtRed = _redChannel(data, x: 6, y: 14, width: 12);
    final belowArtAlpha = _alphaChannel(data, x: 6, y: 14, width: 12);
    expect(topRed, greaterThan(230));
    expect(topAlpha, 255);
    expect(belowArtAlpha, 255);
    expect(belowArtRed, greaterThan(30));
    expect(belowArtRed, lessThan(topRed));

    composite.dispose();
    await provider.evict();
  });
}

int _redChannel(
  ByteData data, {
  required int x,
  required int y,
  required int width,
}) {
  return data.getUint8((y * width + x) * 4);
}

int _alphaChannel(
  ByteData data, {
  required int x,
  required int y,
  required int width,
}) {
  return data.getUint8((y * width + x) * 4 + 3);
}

Future<ImageInfo> _resolveImage(ImageProvider<Object> provider) {
  final result = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (imageInfo, synchronousCall) {
      if (!result.isCompleted) result.complete(imageInfo.clone());
      imageInfo.dispose();
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!result.isCompleted) {
        result.completeError(error, stackTrace ?? StackTrace.current);
      }
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return result.future;
}

@immutable
class _SolidImageProvider extends ImageProvider<_SolidImageProvider> {
  const _SolidImageProvider({
    required this.color,
    this.width = 8,
    this.height = 16,
  });

  final Color color;
  final int width;
  final int height;

  @override
  Future<_SolidImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_SolidImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _SolidImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_createImage());
  }

  Future<ImageInfo> _createImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = color,
    );
    final picture = recorder.endRecording();
    try {
      return ImageInfo(image: await picture.toImage(width, height));
    } finally {
      picture.dispose();
    }
  }

  @override
  bool operator ==(Object other) {
    return other is _SolidImageProvider &&
        other.color == color &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(color, width, height);
}
