import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

const _firstImage = 'assets/images/map_default/root_default.webp';
const _secondImage = 'assets/images/map_default/l1_default.webp';
const _thirdImage = 'assets/images/map_default/l2_default.webp';

void main() {
  testWidgets('viewer keeps the status bar transparent while icons change', (
    tester,
  ) async {
    final calls = <Map<dynamic, dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
            calls.add(Map<dynamic, dynamic>.from(call.arguments as Map));
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    SystemChrome.setSystemUIOverlayStyle(kGenesisDefaultSystemUiOverlayStyle);
    await tester.pump();
    calls.clear();

    await _pumpViewerHost(tester, const [_firstImage]);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('genesis-image-viewer-close')));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.idle();

    final statusBarCalls = calls
        .where((call) => call['statusBarColor'] != null)
        .toList(growable: false);
    expect(statusBarCalls, isNotEmpty);
    expect(
      statusBarCalls.every(
        (call) => call['statusBarColor'] == Colors.transparent.toARGB32(),
      ),
      isTrue,
    );
    expect(
      calls.any(
        (call) => call['statusBarIconBrightness'] == 'Brightness.light',
      ),
      isTrue,
    );
    expect(statusBarCalls.last['statusBarIconBrightness'], 'Brightness.dark');
  });

  testWidgets('single image viewer supports zoom and hides page dots', (
    tester,
  ) async {
    await _pumpViewerHost(tester, const [_firstImage]);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('genesis-image-viewer-surface')),
          )
          .color,
      Colors.black,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      ),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    final closeBackground = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('genesis-image-viewer-close-background')),
    );
    final decoration = closeBackground.decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, Colors.black.withValues(alpha: 0.38));
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-image-viewer-close-background')),
      ),
      const Size.square(36),
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-dots')),
      findsNothing,
    );
  });

  testWidgets('multi image viewer shows compact page dots', (tester) async {
    await _pumpViewerHost(tester, const [_firstImage, _secondImage]);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-dots')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-dot-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-dot-1')),
      findsOneWidget,
    );
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
    );
    expect(pageView.controller!.viewportFraction, greaterThan(1));
    final pageRect = tester.getRect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
    );
    final imageRect = tester.getRect(
      find.byKey(const ValueKey('genesis-image-viewer-image-0')),
    );
    expect(imageRect.left, closeTo(pageRect.left, 0.001));
    expect(imageRect.right, closeTo(pageRect.right, 0.001));
  });

  testWidgets('multi image viewer keeps each page full width while paging', (
    tester,
  ) async {
    await _pumpViewerHost(tester, const [_firstImage, _secondImage]);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final pageSize = tester.getSize(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
    );
    final initialImageSize = tester.getSize(
      find.byKey(const ValueKey('genesis-image-viewer-image-0')),
    );
    expect(initialImageSize.width, pageSize.width);
    expect(initialImageSize.height, greaterThanOrEqualTo(pageSize.height));

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      ),
    );
    await gesture.moveBy(const Offset(-220, 0));
    await tester.pump();

    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-image-viewer-image-0')),
      ),
      initialImageSize,
    );
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('viewer preloads adjacent full-size images', (tester) async {
    final preloadedAssetNames = <String>[];
    debugGenesisImageViewerPrecacheImage = (imageProvider, context) async {
      if (imageProvider is AssetImage) {
        preloadedAssetNames.add(imageProvider.assetName);
      }
    };
    addTearDown(() => debugGenesisImageViewerPrecacheImage = null);

    await _pumpViewerHost(tester, const [
      _firstImage,
      _secondImage,
      _thirdImage,
    ], initialIndex: 1);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(preloadedAssetNames, [_firstImage, _thirdImage]);

    preloadedAssetNames.clear();
    await tester.drag(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(preloadedAssetNames, [_secondImage]);
  });

  testWidgets(
    'viewer displays a low-resolution image before the full-screen image',
    (tester) async {
      const small = 'https://cdn.example.com/first-sm.png';
      const large =
          'https://cdn.example.com/first-xl.png?old_query=true#old_fragment';
      GenesisImageResourceRegistry.register(
        const GenesisImageResource(smUrl: small, xlUrl: large),
      );
      final preloadedUrls = <String>[];
      debugGenesisImageViewerPrecacheImage = (imageProvider, context) async {
        if (imageProvider is GenesisStaticNetworkImageProvider) {
          preloadedUrls.add(imageProvider.imageUrl);
        }
      };
      addTearDown(() => debugGenesisImageViewerPrecacheImage = null);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 2;

      await _pumpViewerHost(tester, const [large, large]);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      const expectedSuffix =
          '?x-oss-process=image/resize,w_2160,image/format,webp';
      const expectedFullUrl =
          'https://cdn.example.com/first-xl.png$expectedSuffix';
      final previewImage = tester.widget<GenesisStaticNetworkImage>(
        find.descendant(
          of: find.byKey(const ValueKey('genesis-image-viewer-preview-0')),
          matching: find.byType(GenesisStaticNetworkImage),
        ),
      );
      final fullImage = tester.widget<GenesisStaticNetworkImage>(
        find
            .descendant(
              of: find.byKey(const ValueKey('genesis-image-viewer-full-0')),
              matching: find.byType(GenesisStaticNetworkImage),
            )
            .first,
      );

      expect(previewImage.imageUrl, small);
      expect(fullImage.imageUrl, expectedFullUrl);
      expect(preloadedUrls, <String>[expectedFullUrl]);
    },
  );

  testWidgets('viewer reuses an existing resized URL as its preview', (
    tester,
  ) async {
    const thumbnail =
        'https://cdn.example.com/legacy.png'
        '?x-oss-process=image/resize,w_180,image/format,webp';

    await _pumpViewerHost(tester, const [thumbnail]);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final previewImage = tester.widget<GenesisStaticNetworkImage>(
      find.descendant(
        of: find.byKey(const ValueKey('genesis-image-viewer-preview-0')),
        matching: find.byType(GenesisStaticNetworkImage),
      ),
    );
    final fullImage = tester.widget<GenesisStaticNetworkImage>(
      find
          .descendant(
            of: find.byKey(const ValueKey('genesis-image-viewer-full-0')),
            matching: find.byType(GenesisStaticNetworkImage),
          )
          .first,
    );

    expect(previewImage.imageUrl, thumbnail);
    expect(
      fullImage.imageUrl,
      'https://cdn.example.com/legacy.png'
      '?x-oss-process=image/resize,w_2160,image/format,webp',
    );
  });

  testWidgets('viewer reuses the caller thumbnail image provider', (
    tester,
  ) async {
    final previewProvider = GenesisStaticNetworkImageProvider(
      imageUrl: 'https://cdn.example.com/cached-thumbnail.webp',
      cacheWidth: 160,
      cacheHeight: 160,
      fit: BoxFit.cover,
    );

    await _pumpViewerHost(
      tester,
      const ['https://cdn.example.com/cached-thumbnail.webp'],
      previewImageProviders: [previewProvider],
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final previewImage = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('genesis-image-viewer-preview-0')),
        matching: find.byType(Image),
      ),
    );
    expect(identical(previewImage.image, previewProvider), isTrue);
  });

  testWidgets('image zoom resets after paging away and back', (tester) async {
    await _pumpViewerHost(tester, const [_firstImage, _secondImage]);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final firstViewer = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('genesis-image-viewer-interactive-0')),
    );
    firstViewer.transformationController!.value = Matrix4.diagonal3Values(
      2,
      2,
      1,
    );
    expect(firstViewer.transformationController!.value.entry(0, 0), 2);

    await tester.drag(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    final restoredFirstViewer = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('genesis-image-viewer-interactive-0')),
    );
    expect(restoredFirstViewer.transformationController!.value.entry(0, 0), 1);
  });

  testWidgets('viewer closes on downward swipe', (tester) async {
    await _pumpViewerHost(tester, const [_firstImage]);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      findsNothing,
    );
  });

  testWidgets('viewer follows downward drag before dismissal', (tester) async {
    await _pumpViewerHost(tester, const [_firstImage]);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      ),
    );
    await gesture.moveBy(const Offset(0, 72));
    await tester.pump();

    final translation = tester.widget<Transform>(
      find.byKey(const ValueKey('genesis-image-viewer-drag-translation')),
    );
    final scale = tester.widget<Transform>(
      find.byKey(const ValueKey('genesis-image-viewer-drag-transform')),
    );
    expect(translation.transform.getTranslation().y, greaterThan(0));
    expect(scale.transform.entry(0, 0), lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('tall image scrolls vertically without dismissing the viewer', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 100, 1000),
      ui.Paint()..color = Colors.red,
    );
    final tallImage = await recorder.endRecording().toImage(100, 1000);
    debugGenesisStaticNetworkImageCompleter = (_) {
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.value(ImageInfo(image: tallImage)),
      );
    };
    addTearDown(() {
      debugGenesisStaticNetworkImageCompleter = null;
      tallImage.dispose();
    });

    await _pumpViewerHost(tester, const [
      'https://cdn.example.com/tall-image.png',
    ]);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final pageSize = tester.getSize(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('genesis-image-viewer-image-0')))
          .height,
      greaterThan(pageSize.height),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('genesis-image-viewer-interactive-0')),
      ),
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();

    var viewer = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('genesis-image-viewer-interactive-0')),
    );
    expect(
      viewer.transformationController!.value.getTranslation().y,
      lessThan(0),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('genesis-image-viewer-interactive-0')),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
      findsOneWidget,
    );
    viewer = tester.widget<InteractiveViewer>(
      find.byKey(const ValueKey('genesis-image-viewer-interactive-0')),
    );
    expect(
      viewer.transformationController!.value.getTranslation().y,
      lessThan(0),
    );
  });

  testWidgets('pinch zoom does not start page or dismiss gestures', (
    tester,
  ) async {
    await _pumpViewerHost(tester, const [_firstImage, _secondImage]);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final center = tester.getCenter(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
    );
    final firstFinger = await tester.startGesture(center - const Offset(20, 0));
    final secondFinger = await tester.startGesture(
      center + const Offset(20, 0),
    );
    await tester.pump();
    await firstFinger.moveBy(const Offset(-16, 90));
    await secondFinger.moveBy(const Offset(16, 90));
    await tester.pump();

    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
    );
    final translation = tester.widget<Transform>(
      find.byKey(const ValueKey('genesis-image-viewer-drag-translation')),
    );
    expect(pageView.physics, isA<NeverScrollableScrollPhysics>());
    expect(translation.transform.getTranslation().y, 0);

    await firstFinger.up();
    await secondFinger.up();
    await tester.pumpAndSettle();

    final restoredPageView = tester.widget<PageView>(
      find.byKey(const ValueKey('genesis-image-viewer-page-view')),
    );
    expect(
      restoredPageView.physics,
      isNot(isA<NeverScrollableScrollPhysics>()),
    );
  });
}

Future<void> _pumpViewerHost(
  WidgetTester tester,
  List<String> imageUrls, {
  List<ImageProvider<Object>?> previewImageProviders =
      const <ImageProvider<Object>?>[],
  int initialIndex = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: kGenesisDefaultSystemUiOverlayStyle,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showGenesisImageViewer(
                  context,
                  imageUrls: imageUrls,
                  previewImageProviders: previewImageProviders,
                  initialIndex: initialIndex,
                ),
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    ),
  );
}
