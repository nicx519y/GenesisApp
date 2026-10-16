import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/rendering.dart';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  for (final portrait in [false, true]) {
    testWidgets(
      'opening flies from painted thumbnail bounds to viewer bounds, portrait=$portrait',
      (tester) async {
        final probe = await _mount(tester, portrait: portrait);
        final anchor = find.byType(GenesisImageViewerSourceAnchor);
        await tester.tap(anchor);
        await tester.pump();
        final flight = find.byKey(
          const ValueKey('genesis-image-viewer-opening-image'),
        );
        final sourceRect = portrait
            ? const Rect.fromLTWH(32, 210, 60, 120)
            : const Rect.fromLTWH(32, 230, 160, 80);
        expect(tester.getRect(flight), sourceRect);
        await _capture(tester, probe.captureKey, 'start-$portrait');
        expect(
          tester
              .widget<Opacity>(
                find
                    .descendant(of: anchor, matching: find.byType(Opacity))
                    .first,
              )
              .opacity,
          0,
        );
        await tester.pump(const Duration(milliseconds: 160));
        final destination = portrait
            ? const Rect.fromLTWH(0, 0, 390, 780)
            : const Rect.fromLTWH(0, 202.5, 390, 195);
        final expected = Rect.lerp(
          sourceRect,
          destination,
          Curves.easeOutCubic.transform(.5),
        )!;
        final actual = tester.getRect(flight);
        expect(actual.left, closeTo(expected.left, .01));
        expect(actual.top, closeTo(expected.top, .01));
        expect(actual.width, closeTo(expected.width, .01));
        expect(actual.height, closeTo(expected.height, .01));
        await _capture(tester, probe.captureKey, 'middle-$portrait');
        // Full image has already loaded, but the flight still uses the cached tile.
        final flyingImage = tester.widget<Image>(
          find.descendant(of: flight, matching: find.byType(Image)),
        );
        expect(flyingImage.image, probe.provider);
        await tester.pumpAndSettle();
        expect(flight, findsNothing);
        await _capture(tester, probe.captureKey, 'end-$portrait');
        expect(find.byType(GenesisImageViewerOverlay), findsOneWidget);
        expect(
          tester
              .widget<Opacity>(
                find
                    .descendant(of: anchor, matching: find.byType(Opacity))
                    .first,
              )
              .opacity,
          1,
        );
        expect(
          tester
              .widget<GenesisImageViewerOverlay>(
                find.byType(GenesisImageViewerOverlay),
              )
              .previewImageProviders
              .single,
          probe.provider,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const ValueKey('genesis-image-viewer-close')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GenesisImageViewerOverlay), findsNothing);
        expect(
          tester
              .widget<Opacity>(
                find
                    .descendant(of: anchor, matching: find.byType(Opacity))
                    .first,
              )
              .opacity,
          1,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('reduced motion opens directly without hiding the source', (
    tester,
  ) async {
    await _mount(tester, reducedMotion: true);
    final anchor = find.byType(GenesisImageViewerSourceAnchor);
    await tester.tap(anchor);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-opening-image')),
      findsNothing,
    );
    expect(find.byType(GenesisImageViewerOverlay), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: anchor, matching: find.byType(Opacity)).first,
          )
          .opacity,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'dismissal during opening restores the source and removes the flight',
    (tester) async {
      await _mount(tester);
      final anchor = find.byType(GenesisImageViewerSourceAnchor);
      await tester.tap(anchor);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      Navigator.of(
        tester.element(find.byType(GenesisImageViewerOverlay)),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.byType(GenesisImageViewerOverlay), findsNothing);
      expect(
        find.byKey(const ValueKey('genesis-image-viewer-opening-image')),
        findsNothing,
      );
      expect(
        tester
            .widget<Opacity>(
              find.descendant(of: anchor, matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<({ImageProvider<Object> provider, GlobalKey captureKey})> _mount(
  WidgetTester tester, {
  bool portrait = false,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 200, 200), Paint()..color = Colors.pink);
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(
    () => picture.toImage(portrait ? 100 : 200, portrait ? 200 : 100),
  ))!;
  picture.dispose();
  final png = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  ))!;
  image.dispose();
  final bytes = png.buffer.asUint8List();
  final provider = MemoryImage(bytes);
  final captureKey = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: DefaultAssetBundle(
        bundle: _ImageBundle(bytes),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 32,
                  top: 210,
                  width: 160,
                  height: 120,
                  child: Builder(
                    builder: (context) => GenesisImageViewerSourceAnchor(
                      previewImageProvider: provider,
                      alignment: Alignment.centerLeft,
                      onTap: (source) => showGenesisImageViewer(
                        context,
                        imageUrls: const ['assets/viewer-transition-full.png'],
                        source: source,
                      ),
                      child: Image(
                        image: provider,
                        width: 160,
                        height: 120,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
  return (provider: provider, captureKey: captureKey);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory =
      Platform.environment['GENESIS_VIEWER_TRANSITION_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final frame = await boundary.toImage(pixelRatio: 1);
    final png = await frame.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png').writeAsBytes(png!.buffer.asUint8List());
    frame.dispose();
  });
}

class _ImageBundle extends CachingAssetBundle {
  _ImageBundle(this.bytes);
  final Uint8List bytes;
  @override
  Future<ByteData> load(String key) =>
      key == 'assets/viewer-transition-full.png'
      ? Future.value(ByteData.sublistView(bytes))
      : rootBundle.load(key);
}
