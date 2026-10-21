import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_collect_probe.dart';

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

  testWidgets(
    'Photos counts initial, next, revisit and reopen, never preload or rebuild',
    (tester) async {
      final collect = MiniPhoneCollectProbe();
      addTearDown(collect.dispose);
      final probe = await _mount(tester, [_photo(1), _photo(2), _photo(3)]);
      await tester.runAsync(collect.take);
      final tile = find.byKey(const ValueKey('mini-phone-album-1'));
      await tester.tap(tile);
      await tester.pumpAndSettle();
      Future<void> expectViews(int count) async {
        final events = (await tester.runAsync(collect.take))!;
        final views = events
            .where((e) => e.action == 'mini_phone_photo_view')
            .toList();
        expect(views, hasLength(count));
        for (final e in views) {
          expect(
            [e.object2, e.object3, e.object4, e.extData],
            ['', '', '', ''],
          );
        }
      }

      await expectViews(1);
      await tester.pump();
      await expectViews(0);
      final page = find.byKey(const ValueKey('genesis-image-viewer-page-view'));
      await tester.drag(page, const Offset(-350, 0));
      await tester.pumpAndSettle();
      await expectViews(1);
      await tester.drag(page, const Offset(350, 0));
      await tester.pumpAndSettle();
      await expectViews(1);
      final interactive = tester
          .widgetList<InteractiveViewer>(find.byType(InteractiveViewer))
          .first;
      interactive.transformationController!.value = Matrix4.diagonal3Values(
        2,
        2,
        1,
      );
      await tester.pumpAndSettle();
      await expectViews(0);
      await tester.tap(
        find.byKey(const ValueKey('genesis-image-viewer-close')),
      );
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await expectViews(1);
      await tester.tap(
        find.byKey(const ValueKey('genesis-image-viewer-close')),
      );
      await tester.pumpAndSettle();
      unawaited(
        showGenesisImageViewer(
          tester.element(find.byType(MiniPhonePage)),
          imageUrls: const ['https://cdn.example/full-1.png'],
        ),
      );
      await tester.pumpAndSettle();
      await expectViews(0);
      await tester.pumpWidget(const SizedBox.shrink());
      probe.session.dispose();
    },
  );

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
      expect(provider.cacheHeight, (tester.getSize(tile).height * 2).ceil());
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

  testWidgets(
    'unrelated state changes neither rebuild Photos nor page near the bottom',
    (tester) async {
      final probe = await _mount(tester, [
        for (var i = 1; i <= 36; i++) _photo(i),
      ]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      final store = probe.session.data!;
      store.hasMore['album'] = false;
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent - 80);
      await tester.pumpAndSettle();
      store.hasMore['album'] = true;
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final calls = probe.backend.calls('album').length;
      store.currentTime = 'Day 3/14:05';
      await tester.runAsync(store.refreshSummary);
      await tester.pumpAndSettle();
      expect(probe.backend.calls('album').length, calls);
      expect(
        identical(tester.widget<SliverGrid>(find.byType(SliverGrid)), grid),
        isTrue,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(probe.backend.calls('album').length, greaterThan(calls));
      await tester.pumpWidget(const SizedBox.shrink());
      probe.session.dispose();
    },
  );

  testWidgets(
    'reentry starts at top with cached pages, diffs first page and pages at confirmed boundary',
    (tester) async {
      final first = [for (var id = 1; id <= 100; id++) _photo(id)];
      final probe = await _mount(tester, first);
      final store = probe.session.data!;
      final backend = probe.backend;
      Completer<Object?>? firstGate;
      Completer<Object?>? secondGate;
      backend.respond = (request) {
        if (!request.uri.path.endsWith('/album')) return null;
        final pn = int.parse(request.uri.queryParameters['pn']!);
        if (pn == 1 && firstGate != null) return firstGate.future;
        if (pn == 2 && secondGate != null) return secondGate.future;
        return ok(
          page(
            [
              for (var id = (pn - 1) * 100 + 1; id <= pn * 100; id++)
                _photo(id),
            ],
            pn: pn,
            rn: 100,
            total: 250,
          ),
        );
      };
      await tester.runAsync(() async {
        await store.refreshAlbum();
        await store.refreshAlbum(next: true);
      });
      await tester.pumpAndSettle();
      final cached = store.album;
      ScrollController scroll() => tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll().jumpTo(1200);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Photos'));
      await tester.pumpAndSettle();
      firstGate = Completer<Object?>();
      final calls = backend.calls('album').length;
      await tester.tap(find.bySemanticsLabel('Photos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(backend.calls('album').length, calls + 1);
      expect(
        backend.calls('album').last.uri.queryParameters,
        containsPair('rn', '100'),
      );
      expect(scroll().offset, 0);
      expect(store.album, same(cached));
      final unchangedTile = tester.widget(find.byKey(const ValueKey<int>(2)));
      firstGate.complete(
        ok(page([_photo(301), ...first.skip(1)], rn: 100, total: 250)),
      );
      await tester.pumpAndSettle();
      expect(store.album.length, 200);
      expect(store.album.first.id, 301);
      expect(store.album[1], same(cached[1]));
      expect(
        tester.widget(find.byKey(const ValueKey<int>(2))),
        same(unchangedTile),
      );
      expect(scroll().offset, 0);
      expect(backend.calls('album').length, calls + 1);

      // The cache extends to page 2, but the current read only confirmed page 1.
      secondGate = Completer<Object?>();
      final gridWidth = tester.getSize(find.byType(CustomScrollView)).width;
      final boundary = 34 * gridWidth / 3;
      scroll().jumpTo(boundary - scroll().position.viewportDimension - 200);
      await tester.pumpAndSettle();
      expect(backend.calls('album').length, calls + 1);
      scroll().jumpTo(scroll().offset + 100);
      await tester.pump();
      expect(backend.calls('album').length, calls + 2);
      expect(backend.calls('album').last.uri.queryParameters['pn'], '2');
      expect(scroll().position.extentAfter, greaterThan(1000));
      final position = scroll().offset;
      secondGate.complete(
        ok(
          page(
            [for (var id = 101; id <= 200; id++) _photo(id)],
            pn: 2,
            rn: 100,
            total: 250,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll().offset, position);
      expect(backend.calls('album').length, calls + 2);
      await tester.pumpWidget(const SizedBox.shrink());
      probe.session.dispose();
    },
  );

  testWidgets(
    'filtered pages automatically fill the viewport and stop at visible boundary',
    (tester) async {
      final probe = await _mount(tester, [_photo(1)]);
      final store = probe.session.data!;
      final calls = probe.backend.calls('album').length;
      probe.backend.respond = (request) {
        if (!request.uri.path.endsWith('/album')) return null;
        final pn = int.parse(request.uri.queryParameters['pn']!);
        return ok(
          page(
            [
              for (var id = (pn - 1) * 100 + 1; id <= pn * 100; id++)
                pn < 3
                    ? {..._photo(id), 'image_url': '', 'thumbnail_url': ''}
                    : _photo(id),
            ],
            pn: pn,
            rn: 100,
            total: 300,
          ),
        );
      };
      await tester.runAsync(store.refreshAlbum);
      await tester.pumpAndSettle();
      expect(
        probe.backend
            .calls('album')
            .skip(calls)
            .map((r) => r.uri.queryParameters['pn']),
        ['1', '2', '3'],
      );
      expect(
        find.byKey(const ValueKey('mini-phone-album-201')),
        findsOneWidget,
      );
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
    PhoneBackend backend,
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
  backend.respond = (request) => request.uri.path.endsWith('/album')
      ? ok(
          page(
            photos,
            pn: int.parse(request.uri.queryParameters['pn']!),
            rn: 100,
          ),
        )
      : null;
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
  return (
    session: session,
    backend: backend,
    prefetched: prefetched,
    loaded: loaded,
  );
}
