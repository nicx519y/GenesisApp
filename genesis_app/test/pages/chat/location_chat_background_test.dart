import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_palette.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    debugGenesisStaticNetworkImageCompleter = null;
  });

  tearDown(() {
    debugGenesisStaticNetworkImageCompleter = null;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  test('location chat enables background rendering by default', () {
    const panel = LocationChatPanel(worldId: 'world-1', locationId: 'loc-1');

    expect(panel.renderBackgroundImage, isTrue);
  });

  test('location chat background uses the global image DPR cap', () {
    final resource = GenesisImageResourceRegistry.register(
      const GenesisImageResource(
        xlUrl: 'https://cdn.example.com/location-chat-cap.webp',
      ),
    );

    expect(
      resolveLocationChatBackgroundUrlForTesting(
        imageUrl: resource.displayUrl,
        logicalWidth: 400,
        logicalHeight: 800,
        devicePixelRatio: 3,
      ),
      'https://cdn.example.com/location-chat-cap.webp'
      '?x-oss-process=image/resize,w_720,image/format,webp',
    );
    expect(
      resolveLocationChatBackgroundUrlForTesting(
        imageUrl: resource.displayUrl,
        logicalWidth: 400,
        logicalHeight: 800,
        devicePixelRatio: 1.5,
      ),
      'https://cdn.example.com/location-chat-cap.webp'
      '?x-oss-process=image/resize,w_720,image/format,webp',
    );
  });

  test('location chat avatars use the 2.4 DPR cap', () {
    final resource = GenesisImageResourceRegistry.register(
      const GenesisImageResource(
        xlUrl: 'https://cdn.example.com/location-chat-avatar.webp',
      ),
    );

    expect(
      resolveLocationChatAvatarUrlForTesting(
        imageUrl: resource.displayUrl,
        devicePixelRatio: 3,
      ),
      'https://cdn.example.com/location-chat-avatar.webp'
      '?x-oss-process=image/resize,w_180,image/format,webp',
    );
  });

  test('location chat preview uses the XL URL at a small CDN tier', () {
    final resource = GenesisImageResourceRegistry.register(
      const GenesisImageResource(
        smUrl: 'https://cdn.example.com/location-chat-preview.webp',
        xlUrl: 'https://cdn.example.com/location-chat-full.webp',
      ),
    );

    expect(
      resolveLocationChatBackgroundPreviewUrlForTesting(
        imageUrl: resource.xlUrl,
        previewImageUrl: resource.smUrl,
      ),
      'https://cdn.example.com/location-chat-full.webp'
      '?x-oss-process=image/resize,w_180,image/format,webp',
    );
  });

  testWidgets('disabled location chat background creates no image provider', (
    tester,
  ) async {
    final requestedUrls = <String>[];
    debugGenesisStaticNetworkImageCompleter = (key) {
      requestedUrls.add(key.imageUrl);
      return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
    };

    await tester.pumpWidget(
      _backgroundHarness(
        renderBackgroundImage: false,
        backgroundImageUrl: 'https://cdn.example.com/disabled-full.webp',
        backgroundPreviewImageUrl:
            'https://cdn.example.com/disabled-preview.webp',
      ),
    );
    await tester.pump();

    expect(requestedUrls, isEmpty);
    expect(find.byType(GenesisStaticNetworkImage), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('location-chat-background-disabled')),
      findsOneWidget,
    );
  });

  testWidgets('empty location chat background uses the redesign solid color', (
    tester,
  ) async {
    final requestedUrls = <String>[];
    debugGenesisStaticNetworkImageCompleter = (key) {
      requestedUrls.add(key.imageUrl);
      return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
    };

    await tester.pumpWidget(
      _backgroundHarness(backgroundImageUrl: '', backgroundPreviewImageUrl: ''),
    );
    await tester.pump();

    expect(requestedUrls, isEmpty);
    expect(find.byType(GenesisStaticNetworkImage), findsNothing);
    expect(find.byType(Image), findsNothing);
    final background = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('location-chat-background')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(background.color, GenesisPalette.redesignBackground);
    final overlay = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('location-chat-background-overlay')),
    );
    final gradient = (overlay.decoration as BoxDecoration).gradient!;
    expect(gradient, isA<LinearGradient>());
    final linearGradient = gradient as LinearGradient;
    expect(linearGradient.begin, Alignment.topCenter);
    expect(linearGradient.end, Alignment.bottomCenter);
    expect(linearGradient.stops, const <double>[0, 0.32, 0.64, 1]);
    expect(linearGradient.colors, const <Color>[
      GenesisPalette.redesignInk80,
      GenesisPalette.redesignInk50,
      GenesisPalette.redesignInk50,
      GenesisPalette.redesignInk80,
    ]);
  });

  testWidgets('location chat shows preview before fading in the full image', (
    tester,
  ) async {
    const previewUrl =
        'https://cdn.example.com/location-chat-full.webp'
        '?x-oss-process=image/resize,w_180,image/format,webp';
    const fullUrl =
        'https://cdn.example.com/location-chat-full.webp'
        '?x-oss-process=image/resize,w_720,image/format,webp';
    final requestedUrls = <String>{};
    final frames = <String, Completer<ImageInfo>>{};
    debugGenesisStaticNetworkImageCompleter = (key) {
      requestedUrls.add(key.imageUrl);
      final frame = frames.putIfAbsent(
        key.imageUrl,
        () => Completer<ImageInfo>(),
      );
      return OneFrameImageStreamCompleter(frame.future);
    };

    await tester.pumpWidget(
      _backgroundHarness(
        backgroundImageUrl: 'https://cdn.example.com/location-chat-full.webp',
        backgroundPreviewImageUrl:
            'https://cdn.example.com/location-chat-preview.webp',
      ),
    );

    expect(requestedUrls, {previewUrl});
    expect(
      find.byKey(const ValueKey<String>('location-chat-background-preview')),
      findsOneWidget,
    );
    final backgroundLayers = tester.widget<Stack>(
      find.byKey(const ValueKey<String>('location-chat-background-layers')),
    );
    expect(backgroundLayers.children.last, isA<IgnorePointer>());
    expect(
      find.byKey(const ValueKey<String>('location-chat-background-overlay')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('location-chat-background-full')),
      findsNothing,
    );

    await tester.pump();

    expect(requestedUrls, {previewUrl, fullUrl});
    final previewImage = await tester.runAsync(
      () => _createTestImage(Colors.blue),
    );
    frames[previewUrl]!.complete(ImageInfo(image: previewImage!));
    await tester.pump();
    await tester.pump();

    final previewLayer = find.byKey(
      const ValueKey<String>('location-chat-background-preview'),
    );
    expect(
      find.descendant(of: previewLayer, matching: find.byType(RawImage)),
      findsOneWidget,
    );

    final fullImage = await tester.runAsync(
      () => _createTestImage(Colors.green),
    );
    frames[fullUrl]!.complete(ImageInfo(image: fullImage!));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final fullLayer = find.byKey(
      const ValueKey<String>('location-chat-background-full'),
    );
    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(of: fullLayer, matching: find.byType(AnimatedOpacity)),
    );
    expect(opacity.opacity, 1);
    expect(opacity.duration, const Duration(milliseconds: 150));
    expect(
      find.descendant(of: fullLayer, matching: find.byType(RawImage)),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('location chat keeps the XL preview when the full image fails', (
    tester,
  ) async {
    const previewUrl =
        'https://cdn.example.com/location-chat-full.webp'
        '?x-oss-process=image/resize,w_180,image/format,webp';
    const fullUrl =
        'https://cdn.example.com/location-chat-full.webp'
        '?x-oss-process=image/resize,w_720,image/format,webp';
    final frames = <String, Completer<ImageInfo>>{};
    debugGenesisStaticNetworkImageCompleter = (key) {
      final frame = frames.putIfAbsent(
        key.imageUrl,
        () => Completer<ImageInfo>(),
      );
      return OneFrameImageStreamCompleter(frame.future);
    };

    await tester.pumpWidget(
      _backgroundHarness(
        backgroundImageUrl: 'https://cdn.example.com/location-chat-full.webp',
        backgroundPreviewImageUrl:
            'https://cdn.example.com/location-chat-preview.webp',
      ),
    );
    await tester.pump();

    final previewImage = await tester.runAsync(
      () => _createTestImage(Colors.blue),
    );
    frames[previewUrl]!.complete(ImageInfo(image: previewImage!));
    await tester.pump();
    await tester.pump();

    frames[fullUrl]!.completeError(StateError('full background failed'));
    await tester.pump();
    await tester.pump();

    final previewLayer = find.byKey(
      const ValueKey<String>('location-chat-background-preview'),
    );
    expect(
      find.descendant(of: previewLayer, matching: find.byType(RawImage)),
      findsOneWidget,
    );
    final fullLayer = find.byKey(
      const ValueKey<String>('location-chat-background-full'),
    );
    final opacity = tester.widget<AnimatedOpacity>(
      find.descendant(of: fullLayer, matching: find.byType(AnimatedOpacity)),
    );
    expect(opacity.opacity, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Widget _backgroundHarness({
  required String backgroundImageUrl,
  required String backgroundPreviewImageUrl,
  bool renderBackgroundImage = true,
}) {
  return MaterialApp(
    theme: GenesisTheme.worldoDark(),
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 390,
        height: 600,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 600), devicePixelRatio: 2),
          child: LocationChatPanel(
            worldId: 'world-background-test',
            locationId: 'location-background-test',
            active: false,
            backgroundImageUrl: backgroundImageUrl,
            backgroundPreviewImageUrl: backgroundPreviewImageUrl,
            renderBackgroundImage: renderBackgroundImage,
          ),
        ),
      ),
    ),
  );
}

Future<ui.Image> _createTestImage(Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = color);
  return recorder.endRecording().toImage(2, 2);
}
