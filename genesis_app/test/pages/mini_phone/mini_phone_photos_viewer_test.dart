import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone_page.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

import '../../support/mini_phone_chat_backend.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    debugGenesisStaticNetworkImageCompleter = null;
    debugGenesisImageViewerPrecacheImage = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('Photos requests CDN thumbnails even without thumbnail URLs', (
    tester,
  ) async {
    final probe = await _mount(tester, [
      {..._photo(1), 'thumbnail_url': null},
      {..._photo(2), 'thumbnail_url': 'https://cdn.example/tiny-2.png'},
      _photo(3),
    ], devicePixelRatio: 3);
    for (var id = 1; id <= 3; id++) {
      final tile = find.byKey(ValueKey('mini-phone-album-$id'));
      final provider =
          tester
                  .widget<Image>(
                    find.descendant(of: tile, matching: find.byType(Image)),
                  )
                  .image
              as GenesisStaticNetworkImageProvider;
      expect(Uri.parse(provider.imageUrl).path, '/full-$id.png');
      expect(
        Uri.parse(provider.imageUrl).queryParameters['x-oss-process'],
        'image/resize,w_180/format,webp',
      );
      expect(provider.cacheWidth, (tester.getSize(tile).width * 2).ceil());
      expect(provider.fit, BoxFit.cover);
    }
    expect(probe.prefetched, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    probe.session.dispose();
  });

  testWidgets(
    'Photos expands the selected tile and reuses adjacent full-image preloads',
    (tester) async {
      final probe = await _mount(tester, [
        for (var i = 0; i < 5; i++) _photo(i + 1),
      ]);
      final tile = find.byKey(const ValueKey('mini-phone-album-3'));
      final rect = tester.getRect(tile);
      final thumbnailProvider = tester
          .widget<Image>(
            find.descendant(of: tile, matching: find.byType(Image)),
          )
          .image;
      await tester.tap(tile);
      await tester.pump();
      final flight = find.byKey(
        const ValueKey('genesis-image-viewer-opening-image'),
      );
      // Grid uses cover: animation starts at the square tile's clipped bounds.
      expect(tester.getRect(flight), rect);
      expect(
        tester
            .widget<Image>(
              find.descendant(of: flight, matching: find.byType(Image)),
            )
            .image,
        thumbnailProvider,
      );
      await tester.pumpAndSettle();
      final viewer = tester.widget<GenesisImageViewerOverlay>(
        find.byType(GenesisImageViewerOverlay),
      );
      expect(viewer.initialIndex, 2);
      expect(viewer.previewImageProviders[2], thumbnailProvider);
      expect(probe.prefetched.map((p) => Uri.parse(p.imageUrl).path), [
        '/full-2.png',
        '/full-4.png',
      ]);
      for (final provider in probe.prefetched) {
        expect(provider.cacheWidth, 360);
        expect(provider.cacheHeight, isNull);
        expect(provider.fit, BoxFit.fitWidth);
        // At this width, shrinking by the page gap would choose the wrong CDN tier.
        expect(
          Uri.parse(provider.imageUrl).queryParameters['x-oss-process'],
          contains('resize,w_720'),
        );
      }
      final preloadedNext = probe.prefetched.last;
      probe.prefetched.clear();
      await tester.drag(
        find.byKey(const ValueKey('genesis-image-viewer-page-view')),
        const Offset(-360, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('genesis-image-viewer-image-3')),
        findsOneWidget,
      );
      expect(probe.prefetched.map((p) => Uri.parse(p.imageUrl).path), [
        '/full-3.png',
        '/full-5.png',
      ]);
      final actualNext = tester
          .widget<Image>(
            find.descendant(
              of: find.byKey(const ValueKey('genesis-image-viewer-full-3')),
              matching: find.byType(Image),
            ),
          )
          .image;
      expect(actualNext, preloadedNext);
      expect(probe.loaded.where((p) => p == preloadedNext), hasLength(1));
      final pages = tester
          .widget<PageView>(
            find.byKey(const ValueKey('genesis-image-viewer-page-view')),
          )
          .controller!;
      probe.prefetched.clear();
      pages.jumpToPage(0);
      await tester.pumpAndSettle();
      pages.jumpToPage(4);
      await tester.pumpAndSettle();
      expect(probe.prefetched, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      probe.session.dispose();
    },
  );

  testWidgets(
    'Photos skips empty originals without shifting the selected photo',
    (tester) async {
      final probe = await _mount(tester, [
        {..._photo(1), 'image_url': ''},
        _photo(2),
        _photo(3),
        _photo(4),
      ]);
      await tester.tap(find.byKey(const ValueKey('mini-phone-album-3')));
      await tester.pumpAndSettle();
      final viewer = tester.widget<GenesisImageViewerOverlay>(
        find.byType(GenesisImageViewerOverlay),
      );
      expect(viewer.imageUrls, [
        for (final i in [2, 3, 4]) 'https://cdn.example/full-$i.png',
      ]);
      expect(viewer.initialIndex, 1);
      expect(
        (viewer.previewImageProviders[1] as GenesisStaticNetworkImageProvider)
            .imageUrl,
        contains('/full-3.png'),
      );
      expect(probe.prefetched.map((p) => Uri.parse(p.imageUrl).path), [
        '/full-2.png',
        '/full-4.png',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      probe.session.dispose();
    },
  );

  testWidgets('failed adjacent prefetch never interrupts viewing', (
    tester,
  ) async {
    final probe = await _mount(tester, [_photo(1), _photo(2)]);
    debugGenesisImageViewerPrecacheImage = (_, _) =>
        Future<void>.error(StateError('Offline'));
    await tester.tap(find.byKey(const ValueKey('mini-phone-album-1')));
    await tester.pumpAndSettle();
    expect(find.byType(GenesisImageViewerOverlay), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    probe.session.dispose();
  });
}

Map<String, dynamic> _photo(int id) => {
  'asset_id': id,
  'world_id': 'w',
  'image_url': 'https://cdn.example/full-$id.png',
  'thumbnail_url':
      'https://cdn.example/thumb-$id.png?x-oss-process=image/resize,w_90/format,webp',
  'desc': '',
  'created_at': '',
};

Future<
  ({
    MiniPhoneSession session,
    List<GenesisStaticNetworkImageProvider> prefetched,
    List<GenesisStaticNetworkImageProvider> loaded,
  })
>
_mount(
  WidgetTester tester,
  List<Map<String, dynamic>> photos, {
  double devicePixelRatio = 1,
}) async {
  tester.view.physicalSize = Size(
    360 * devicePixelRatio,
    720 * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 160, 80), Paint()..color = Colors.pink);
  final picture = recorder.endRecording();
  final image = (await tester.runAsync(() => picture.toImage(160, 80)))!;
  picture.dispose();
  addTearDown(image.dispose);
  final loaded = <GenesisStaticNetworkImageProvider>[];
  final prefetched = <GenesisStaticNetworkImageProvider>[];
  debugGenesisStaticNetworkImageCompleter = (provider) {
    loaded.add(provider);
    return OneFrameImageStreamCompleter(
      SynchronousFuture(ImageInfo(image: image.clone())),
    );
  };
  debugGenesisImageViewerPrecacheImage = (provider, context) {
    prefetched.add(provider as GenesisStaticNetworkImageProvider);
    return precacheImage(provider, context, onError: (_, _) {});
  };
  final backend = PhoneBackend();
  backend.respond = (request) =>
      request.uri.path.endsWith('/album') ? ok(page(photos)) : null;
  final store = (await tester.runAsync(() async {
    final store = backend.store();
    await store.ready;
    await store.refreshAlbum();
    return store;
  }))!;
  final session = MiniPhoneSession(data: store);
  await tester.pumpWidget(
    MaterialApp(
      home: MiniPhonePage(
        session: session,
        initialScreen: MiniPhoneScreen.photos,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (session: session, prefetched: prefetched, loaded: loaded);
}
