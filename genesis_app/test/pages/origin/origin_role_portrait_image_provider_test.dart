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

  test('blends the portrait into the role-card action surface', () {
    expect(originRolePortraitGradient.stops, const <double>[0.30, 0.68, 1]);
    expect(originRolePortraitGradient.colors, const <Color>[
      Colors.transparent,
      Color(0x66151517),
      Color(0xFF151517),
    ]);
  });

  testWidgets(
    'stores a raw avatar snapshot before compositing and evicting the source',
    (tester) async {
      final sourceProvider = _SolidImageProvider(
        color: const Color(0xFFFF0000),
      );
      final snapshotStore = OriginRoleAvatarSnapshotStore();
      addTearDown(snapshotStore.dispose);
      final provider = OriginRolePortraitImageProvider(
        sourceProvider: sourceProvider,
        outputSize: 16,
        snapshotStore: snapshotStore,
        snapshotSourceKey: 'role-red',
        snapshotSize: 6,
      );
      ImageInfo? imageInfo;

      await tester.runAsync(() async {
        imageInfo = await _resolveImage(provider);
      });

      final composite = imageInfo;
      expect(composite, isNotNull);
      expect(composite!.image.width, 16);
      expect(composite.image.height, 16);
      final sourceStatus = await sourceProvider.obtainCacheStatus(
        configuration: ImageConfiguration.empty,
      );
      expect(sourceStatus, isNotNull);
      expect(sourceStatus!.untracked, isTrue);
      final snapshot = snapshotStore.imageFor('role-red');
      expect(snapshot, isNotNull);
      expect(snapshot!.width, 6);
      expect(snapshot.height, 6);

      ByteData? pixels;
      ByteData? snapshotPixels;
      await tester.runAsync(() async {
        pixels = await composite.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        snapshotPixels = await snapshot.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
      });
      final data = pixels;
      expect(data, isNotNull);
      final topRed = _redChannel(data!, x: 8, y: 1, width: 16);
      final bottomRed = _redChannel(data, x: 8, y: 15, width: 16);
      expect(topRed, greaterThan(230));
      expect(bottomRed, lessThan(topRed));
      expect(
        _redChannel(snapshotPixels!, x: 3, y: 5, width: 6),
        greaterThan(230),
        reason:
            'The selector snapshot must not include the role-card gradient.',
      );

      composite.dispose();
      await provider.evict();
    },
  );
}

int _redChannel(
  ByteData data, {
  required int x,
  required int y,
  required int width,
}) {
  return data.getUint8((y * width + x) * 4);
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
    canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 16), Paint()..color = color);
    final picture = recorder.endRecording();
    try {
      return ImageInfo(image: await picture.toImage(8, 16));
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
