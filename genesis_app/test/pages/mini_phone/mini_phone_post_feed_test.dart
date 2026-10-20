import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_feed.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_content.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_post_thumbnail.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/utils/genesis_image_resource.dart';

import '../../support/mini_phone_chat_backend.dart';

void main() {
  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    debugGenesisStaticNetworkImageCompleter = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  test(
    'fixed-height CDN resize replaces old transforms and retains URL parameters',
    () {
      final result = Uri.parse(
        resizeGenesisImageUrlToHeight(
          'https://cdn.example/post.png?token=abc&tag=one&tag=two&x-oss-process=image/resize,w_200#old',
          logicalHeight: 200,
          devicePixelRatio: 3,
        ),
      );
      expect(
        result.queryParameters['x-oss-process'],
        'image/resize,h_400/format,webp',
      );
      expect(result.queryParameters['token'], 'abc');
      expect(result.queryParametersAll['tag'], ['one', 'two']);
      expect(result.hasFragment, isFalse);
      final resource = GenesisImageResourceRegistry.register(
        const GenesisImageResource(
          smUrl: 'https://cdn.example/small-for-feed.png',
          xlUrl: 'https://cdn.example/original-for-feed.png',
        ),
      );
      expect(
        Uri.parse(
          resizeGenesisImageUrlToHeight(
            resource.smUrl,
            logicalHeight: 200,
            devicePixelRatio: 1,
          ),
        ).path,
        '/original-for-feed.png',
      );
    },
  );

  testWidgets(
    'loading and failed thumbnails keep 200 height with no placeholder or error UI',
    (tester) async {
      final result = Completer<ImageInfo>();
      GenesisStaticNetworkImageProvider? key;
      debugGenesisStaticNetworkImageCompleter = (provider) {
        key = provider;
        return OneFrameImageStreamCompleter(result.future);
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MiniPhonePostThumbnail(
                  imageUrl: 'https://cdn.example/failed.png',
                  onTap: (_, _) {},
                ),
                const SizedBox(key: ValueKey('below-photo'), height: 20),
              ],
            ),
          ),
        ),
      );
      final thumbnail = find.byType(MiniPhonePostThumbnail);
      final below = tester.getTopLeft(
        find.byKey(const ValueKey('below-photo')),
      );
      expect(tester.getSize(thumbnail).height, 200);
      expect(below.dy, tester.getTopLeft(thumbnail).dy + 200);
      final displayed = tester.widget<Image>(find.byType(Image));
      expect(
        displayed.image,
        miniPhonePostThumbnailProvider(
          'https://cdn.example/failed.png',
          width: tester.getSize(thumbnail).width,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(
            tester.element(thumbnail),
          ),
        ),
      );
      expect(
        Uri.parse(key!.imageUrl).queryParameters['x-oss-process'],
        contains('resize,h_'),
      );
      result.completeError(StateError('Image unavailable'));
      await tester.pump();
      await tester.pump();
      expect(tester.getSize(thumbnail).height, 200);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('below-photo'))),
        below,
      );
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(
        find.image(const AssetImage(genesisDefaultListImageAsset)),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loaded landscape image does not change the reserved height', (
    tester,
  ) async {
    final bytes = await rootBundle.load('assets/images/default_list_image.png');
    final image = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    }))!;
    final result = Completer<ImageInfo>();
    debugGenesisStaticNetworkImageCompleter = (_) =>
        OneFrameImageStreamCompleter(result.future);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MiniPhonePostThumbnail(
                imageUrl: 'https://cdn.example/loaded.png',
                onTap: (_, _) {},
              ),
              const SizedBox(key: ValueKey('after-image'), height: 20),
            ],
          ),
        ),
      ),
    );
    final before = tester.getTopLeft(find.byKey(const ValueKey('after-image')));
    result.complete(ImageInfo(image: image));
    await tester.pump();
    expect(tester.getSize(find.byType(MiniPhonePostThumbnail)).height, 200);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('after-image'))),
      before,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [240.0, 420.0]) {
    testWidgets(
      'wide photo crops centrally at fixed height within width $width',
      (tester) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 800, 200),
          Paint()..color = Colors.red,
        );
        canvas.drawRect(
          const Rect.fromLTWH(100, 0, 600, 200),
          Paint()..color = Colors.green,
        );
        final picture = recorder.endRecording();
        final decoded = (await tester.runAsync(
          () => picture.toImage(800, 200),
        ))!;
        picture.dispose();
        addTearDown(decoded.dispose);
        debugGenesisStaticNetworkImageCompleter = (_) =>
            OneFrameImageStreamCompleter(
              Future.value(ImageInfo(image: decoded.clone())),
            );
        final boundaryKey = GlobalKey();
        GenesisImageViewerSource? source;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: width,
                    child: MiniPhonePostThumbnail(
                      imageUrl: 'https://cdn.example/wide-$width.png',
                      onTap: (_, captured) => source = captured,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final thumbnail = find.byType(MiniPhonePostThumbnail);
        expect(tester.getSize(thumbnail), Size(width, 200));
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final rendered = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        ))!;
        final pixels = (await tester.runAsync(
          () => rendered.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        // The center band fills the full height; the red outer edges are cropped.
        for (final point in [const Offset(1, 1), Offset(width - 2, 198)]) {
          final offset =
              (point.dy.toInt() * rendered.width + point.dx.toInt()) * 4;
          expect(
            pixels.getUint32(offset),
            Colors.green.toARGB32() << 8 & 0xffffffff | 0xff,
          );
        }
        rendered.dispose();
        await tester.tap(thumbnail);
        expect(source, isNotNull);
        expect(source!.rect.size, Size(width, 200));
        expect(source!.aspectRatio, 4);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final scenario in [
    (detail: false, failFullImage: false),
    (detail: false, failFullImage: true),
    (detail: true, failFullImage: false),
    (detail: true, failFullImage: true),
  ]) {
    final failFullImage = scenario.failFullImage;
    testWidgets(
      'Posts detail=${scenario.detail} reuses its thumbnail and full image failure=$failFullImage',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final bytes = await rootBundle.load(
          'assets/images/default_list_image.png',
        );
        final decoded = (await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          codec.dispose();
          return frame.image;
        }))!;
        addTearDown(decoded.dispose);
        final fullImage = Completer<ImageInfo>();
        var thumbnailLoads = 0;
        var fullLoads = 0;
        debugGenesisStaticNetworkImageCompleter = (provider) {
          final process =
              Uri.parse(provider.imageUrl).queryParameters['x-oss-process'] ??
              '';
          if (process.contains('resize,h_')) {
            thumbnailLoads++;
            return OneFrameImageStreamCompleter(
              Future<ImageInfo>.value(ImageInfo(image: decoded.clone())),
            );
          }
          fullLoads++;
          return OneFrameImageStreamCompleter(fullImage.future);
        };
        final backend = PhoneBackend();
        const original = 'https://cdn.example/post-viewer-original.png';
        backend.respond = (request) => request.uri.path.endsWith('/posts')
            ? ok(
                page([
                  {...phonePost(), 'image': original},
                ]),
              )
            : request.uri.path.endsWith('/post/detail')
            ? ok({...phoneDetail(), 'image': original})
            : null;
        final store = (await tester.runAsync(() async {
          final store = backend.store();
          await store.ready;
          return store;
        }))!;
        final session = MiniPhoneSession(data: store);
        await tester.pumpWidget(
          MaterialApp(
            home: MiniPhonePage(
              session: session,
              initialScreen: MiniPhoneScreen.posts,
            ),
          ),
        );
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        if (scenario.detail) {
          final post = tester.widget<MiniPhonePostContent>(
            find.byType(MiniPhonePostContent),
          );
          post.onOpenPost(post.id);
          await tester.pumpAndSettle();
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<MiniPhonePostContent>(find.byType(MiniPhonePostContent))
                .detail,
            isTrue,
          );
        }
        final thumbnail = find.byType(MiniPhonePostThumbnail);
        expect(thumbnail, findsOneWidget);
        expect(tester.getSize(thumbnail), const Size(308, 200));
        final thumbnailProvider = tester
            .widget<Image>(
              find.descendant(of: thumbnail, matching: find.byType(Image)),
            )
            .image;
        expect(
          Uri.parse(
            (thumbnailProvider as GenesisStaticNetworkImageProvider).imageUrl,
          ).queryParameters['x-oss-process'],
          'image/resize,h_400/format,webp',
        );
        expect(thumbnailLoads, 1);
        await tester.tap(thumbnail);
        await tester.pumpAndSettle();
        final viewer = tester.widget<GenesisImageViewerOverlay>(
          find.byType(GenesisImageViewerOverlay),
        );
        expect(viewer.imageUrls, [original]);
        expect(viewer.previewImageProviders.single, thumbnailProvider);
        final preview = find.byKey(
          const ValueKey('genesis-image-viewer-preview-0'),
        );
        expect(preview, findsOneWidget);
        expect(
          tester
              .widget<RawImage>(
                find.descendant(of: preview, matching: find.byType(RawImage)),
              )
              .image,
          isNotNull,
        );
        expect(thumbnailLoads, 1);
        expect(fullLoads, 1);
        if (failFullImage) {
          fullImage.completeError(StateError('Full image unavailable'));
        } else {
          fullImage.complete(ImageInfo(image: decoded.clone()));
        }
        await tester.pumpAndSettle();
        expect(preview, failFullImage ? findsOneWidget : findsNothing);
        if (!failFullImage) {
          final full = find.byKey(
            const ValueKey('genesis-image-viewer-full-0'),
          );
          expect(
            tester
                .widget<RawImage>(
                  find.descendant(of: full, matching: find.byType(RawImage)),
                )
                .image,
            isNotNull,
          );
        }
        expect(thumbnailLoads, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      },
    );
  }

  testWidgets(
    'feed builds only nearby rows and preloads exactly the next five posts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requested = <int>{};
      final built = <int>{};
      debugGenesisStaticNetworkImageCompleter = (key) {
        requested.add(
          int.parse(Uri.parse(key.imageUrl).pathSegments.last.split('.').first),
        );
        return OneFrameImageStreamCompleter(
          Future<ImageInfo>.error(StateError('Offline')),
        );
      };
      final posts = [
        for (var i = 0; i < 100; i++)
          PhonePost.fromJson({
            ...phonePost(),
            'post_id': i + 1,
            'image': 'https://cdn.example/$i.png',
          }),
      ];
      Widget feed({bool active = true, Object resetKey = 0}) => MaterialApp(
        home: Scaffold(
          body: MiniPhonePostFeed(
            posts: posts,
            active: active,
            resetKey: resetKey,
            header: const SizedBox(height: 80),
            footer: const SizedBox.shrink(),
            itemBuilder: (post) {
              final index = post.id - 1;
              built.add(index);
              return SizedBox(
                key: ValueKey('row-$index'),
                height: 370,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 41),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: MiniPhonePostThumbnail(
                      imageUrl: post.image,
                      onTap: (_, _) {},
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpWidget(feed());
      await tester.pumpAndSettle();
      expect(built.length, lessThan(6));
      expect(find.byKey(const ValueKey('row-99')), findsNothing);
      // Rows 0 and 1 intersect the viewport. Only rows 2..6 are prefetched.
      expect(requested, {0, 1, 2, 3, 4, 5, 6});
      requested.clear();
      final controller = tester
          .widget<ListView>(
            find.byWidgetPredicate(
              (w) => w is ListView && w.scrollDirection == Axis.vertical,
            ),
          )
          .controller!;
      controller.jumpTo(900);
      await tester.pumpAndSettle();
      // Rows 2 and 3 now intersect the viewport; prefetch moves to rows 4..8.
      expect(requested, containsAll([7, 8]));
      expect(requested.every((i) => i <= 8), isTrue);
      expect(find.byKey(const ValueKey('row-0')), findsNothing);
      expect(find.byKey(const ValueKey('row-3')), findsOneWidget);
      expect(
        find.byType(MiniPhonePostThumbnail).evaluate().length,
        lessThan(7),
      );
      await tester.pumpWidget(feed(resetKey: 'different-author'));
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(find.byKey(const ValueKey('row-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('prefetch pauses while the feed is inactive or covered', (
    tester,
  ) async {
    final requested = <String>{};
    debugGenesisStaticNetworkImageCompleter = (key) {
      requested.add(Uri.parse(key.imageUrl).path);
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(StateError('Offline')),
      );
    };
    final posts = [
      for (var i = 0; i < 15; i++)
        PhonePost.fromJson({
          ...phonePost(),
          'post_id': i + 1,
          'image': 'https://cdn.example/paused-$i.png',
        }),
    ];
    Widget feed({bool active = true, bool covered = false}) => MaterialApp(
      home: Scaffold(
        body: TickerMode(
          enabled: !covered,
          child: MiniPhonePostFeed(
            posts: posts,
            resetKey: 0,
            active: active,
            header: const SizedBox.shrink(),
            footer: const SizedBox.shrink(),
            itemBuilder: (_) => const SizedBox(height: 1000),
          ),
        ),
      ),
    );
    await tester.pumpWidget(feed(active: false));
    await tester.pumpAndSettle();
    expect(requested, isEmpty);
    await tester.pumpWidget(feed());
    await tester.pumpAndSettle();
    expect(requested, {for (var i = 1; i <= 5; i++) '/paused-$i.png'});
    requested.clear();
    await tester.pumpWidget(feed(covered: true));
    final controller = tester
        .widget<ListView>(
          find.byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.vertical,
          ),
        )
        .controller!;
    controller.jumpTo(1100);
    await tester.pumpAndSettle();
    expect(requested, isEmpty);
    await tester.pumpWidget(feed());
    await tester.pumpAndSettle();
    expect(requested, contains('/paused-6.png'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('text-only posts count toward the five-post prefetch window', (
    tester,
  ) async {
    final requested = <String>{};
    debugGenesisStaticNetworkImageCompleter = (key) {
      requested.add(Uri.parse(key.imageUrl).path);
      return OneFrameImageStreamCompleter(
        Future<ImageInfo>.error(StateError('Offline')),
      );
    };
    final posts = [
      for (var i = 0; i < 12; i++)
        PhonePost.fromJson({
          ...phonePost(),
          'post_id': i + 1,
          'image': i < 6 ? '' : 'https://cdn.example/$i.png',
        }),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniPhonePostFeed(
            posts: posts,
            resetKey: 0,
            header: const SizedBox.shrink(),
            footer: const SizedBox.shrink(),
            itemBuilder: (_) => const SizedBox(height: 1000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
