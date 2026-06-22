import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/common/genesis_modal_routes.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';

const _firstImage = 'assets/images/mock_maps/steam_kingdom_isometric.png';
const _secondImage = 'assets/images/mock_maps/location_rail_gate_map.png';
const _thirdImage = 'assets/images/mock_maps/location_clocktower_map.png';

void main() {
  testWidgets('viewer restores default status bar style after closing', (
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

    GenesisSystemUiChrome.applyDefault();
    calls.clear();

    await _pumpViewerHost(tester, const [_firstImage]);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('genesis-image-viewer-close')));
    await tester.pumpAndSettle();

    expect(calls.length, greaterThanOrEqualTo(2));
    expect(
      calls.any(
        (call) => call['statusBarIconBrightness'] == 'Brightness.light',
      ),
      isTrue,
    );
    expect(calls.last['statusBarIconBrightness'], 'Brightness.dark');
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
    expect(
      tester.getSize(
        find.byKey(const ValueKey('genesis-image-viewer-image-0')),
      ),
      pageSize,
    );

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
      pageSize,
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
  int initialIndex = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showGenesisImageViewer(
                context,
                imageUrls: imageUrls,
                initialIndex: initialIndex,
              ),
              child: const Text('Open'),
            );
          },
        ),
      ),
    ),
  );
}
