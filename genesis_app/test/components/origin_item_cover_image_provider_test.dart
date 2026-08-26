import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/origin/origin_item_cover_image_provider.dart';

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

  testWidgets('composites the cover and footer gradient into one image', (
    tester,
  ) async {
    const sourceProvider = _SolidImageProvider(color: Color(0xFFFF0000));
    const fallbackProvider = _SolidImageProvider(color: Color(0xFF00FF00));
    const provider = OriginItemCoverImageProvider(
      sourceProvider: sourceProvider,
      fallbackProvider: fallbackProvider,
      outputWidth: 12,
      outputHeight: 18,
      transitionHeight: 6,
    );
    ImageInfo? imageInfo;

    await tester.runAsync(() async {
      imageInfo = await _resolveImage(provider);
    });

    final composite = imageInfo;
    expect(composite, isNotNull);
    expect(composite!.image.width, 12);
    expect(composite.image.height, 18);

    ByteData? pixels;
    await tester.runAsync(() async {
      pixels = await composite.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
    });
    final data = pixels!;
    expect(_channel(data, x: 6, y: 2, width: 12, channel: 0), greaterThan(230));
    expect(_channel(data, x: 6, y: 2, width: 12, channel: 1), lessThan(20));
    expect(
      _channel(data, x: 6, y: 17, width: 12, channel: 0),
      inInclusiveRange(17, 50),
    );
    expect(_channel(data, x: 6, y: 17, width: 12, channel: 1), closeTo(17, 2));
    expect(_channel(data, x: 6, y: 17, width: 12, channel: 2), closeTo(17, 2));

    composite.dispose();
    await provider.evict();
  });

  testWidgets('composites the default asset when the cover URL is empty', (
    tester,
  ) async {
    final provider = OriginItemCoverImageProvider.fromUrl(
      imageUrl: '',
      fallbackAsset: 'assets/images/default_list_image.png',
      outputWidth: 220,
      outputHeight: 330,
      transitionHeight: 50,
    );
    ImageInfo? imageInfo;

    await tester.runAsync(() async {
      imageInfo = await _resolveImage(provider);
    });

    expect(imageInfo, isNotNull);
    expect(imageInfo!.image.width, 220);
    expect(imageInfo!.image.height, 330);
    imageInfo!.dispose();
    await provider.evict();
  });
}

int _channel(
  ByteData data, {
  required int x,
  required int y,
  required int width,
  required int channel,
}) {
  return data.getUint8((y * width + x) * 4 + channel);
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
  const _SolidImageProvider({required this.color});

  final Color color;

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
    canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 12), Paint()..color = color);
    final picture = recorder.endRecording();
    try {
      return ImageInfo(image: await picture.toImage(8, 12));
    } finally {
      picture.dispose();
    }
  }

  @override
  bool operator ==(Object other) {
    return other is _SolidImageProvider && other.color == color;
  }

  @override
  int get hashCode => color.hashCode;
}
