import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_wallpaper_background.dart';

class _DeferredImage extends ImageProvider<_DeferredImage> {
  final frame = Completer<ImageInfo>();
  @override
  Future<_DeferredImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _DeferredImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(frame.future);
}

void main() {
  testWidgets(
    'waits for replacement pixels then crossfades; same image does not animate',
    (tester) async {
      final old = _DeferredImage();
      final next = _DeferredImage();
      final frame = (await tester.runAsync(
        () => createTestImage(width: 2, height: 2),
      ))!;
      old.frame.complete(ImageInfo(image: frame.clone()));
      Widget view(ImageProvider provider) =>
          MaterialApp(home: MiniPhoneWallpaperBackground(image: provider));
      await tester.pumpWidget(view(old));
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).image, old);
      await tester.pumpWidget(view(next));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<Image>(find.byType(Image)).image, old);
      next.frame.complete(ImageInfo(image: frame.clone()));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(Image), findsNWidgets(2));
      final fades = tester.widgetList<FadeTransition>(
        find.byType(FadeTransition),
      );
      expect(
        fades.any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Image>(find.byType(Image)).image, next);
      await tester.pumpWidget(view(next));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(const SizedBox());
      await old.evict();
      await next.evict();
      frame.dispose();
    },
  );

  testWidgets('replacement crossfades only after returning to Home', (
    tester,
  ) async {
    final old = _DeferredImage();
    final next = _DeferredImage();
    final frame = (await tester.runAsync(
      () => createTestImage(width: 2, height: 2),
    ))!;
    old.frame.complete(ImageInfo(image: frame.clone()));
    next.frame.complete(ImageInfo(image: frame.clone()));
    Widget view(ImageProvider provider, {bool visible = true}) => MaterialApp(
      home: TickerMode(
        enabled: visible,
        child: MiniPhoneWallpaperBackground(image: provider),
      ),
    );
    await tester.pumpWidget(view(old));
    await tester.pumpAndSettle();
    await tester.pumpWidget(view(next, visible: false));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.widget<Image>(find.byType(Image)).image, old);
    await tester.pumpWidget(view(next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(Image), findsNWidgets(2));
    expect(
      tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
      isTrue,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, next);
    await tester.pumpWidget(const SizedBox());
    await old.evict();
    await next.evict();
    frame.dispose();
  });

  testWidgets('failed or obsolete replacement keeps the current image', (
    tester,
  ) async {
    final old = _DeferredImage();
    final stale = _DeferredImage();
    final broken = _DeferredImage();
    final frame = (await tester.runAsync(
      () => createTestImage(width: 2, height: 2),
    ))!;
    old.frame.complete(ImageInfo(image: frame.clone()));
    Widget view(ImageProvider provider) =>
        MaterialApp(home: MiniPhoneWallpaperBackground(image: provider));
    await tester.pumpWidget(view(old));
    await tester.pumpAndSettle();
    await tester.pumpWidget(view(stale));
    await tester.pumpWidget(view(broken));
    broken.frame.completeError(StateError('decode failed'));
    stale.frame.complete(ImageInfo(image: frame.clone()));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, old);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await old.evict();
    await stale.evict();
    await broken.evict();
    frame.dispose();
  });
}
