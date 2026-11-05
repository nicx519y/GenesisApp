import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_api.dart';
import 'package:genesis_flutter_android/network/models/photo_task.dart';
import 'package:genesis_flutter_android/pages/mini_phone/photos/mini_phone_photos_page.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import '../../support/mini_phone_chat_backend.dart';

Map<String, dynamic> asset(int id, {String? url}) => {
  'asset_id': id,
  'world_id': 'w',
  'image_url': url ?? 'https://cdn.example/$id.png',
  'desc': 'Description $id',
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() {
    debugGenesisStaticNetworkImageCompleter = null;
    debugGenesisImageViewerPrecacheImage = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  Future<void> imageSetup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 60), Paint());
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(40, 60)))!;
    picture.dispose();
    addTearDown(image.dispose);
    debugGenesisStaticNetworkImageCompleter = (_) =>
        OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: image.clone())),
        );
    debugGenesisImageViewerPrecacheImage = (_, _) async {};
  }

  // Generating tasks continuously animate, so settle layout with bounded frames.
  Future<void> pumpAlbum(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final target in [1, 2, 150, 200]) {
    testWidgets(
      'notification opens asset $target once and keeps album position',
      (tester) async {
        await imageSetup(tester);
        final b = PhoneBackend();
        final total = target <= 2 ? 2 : 200;
        b.respond = (r) => r.uri.path.endsWith('/album')
            ? ok(
                page(
                  [
                    for (
                      var id =
                          (int.parse(r.uri.queryParameters['pn']!) - 1) * 100 +
                          1;
                      id <= int.parse(r.uri.queryParameters['pn']!) * 100 &&
                          id <= total;
                      id++
                    )
                      asset(id),
                  ],
                  pn: int.parse(r.uri.queryParameters['pn']!),
                  rn: 100,
                  total: total,
                ),
              )
            : null;
        final store = b.store(namespace: 'album-target-$target');
        await tester.runAsync(() => store.ready);
        store.phoneVisible = true;
        store.albumVisible = true;
        for (var i = 0; i < 4; i++) {
          store.cameraTasks.accept(
            PhotoTask(
              taskId: 'pending-$i',
              requestId: 'pending-$i',
              status: PhotoTaskStatus.generating,
            ),
          );
        }
        var handled = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MiniPhonePhotosPage(
                store: store,
                header: const SizedBox(height: 56),
                tasks: store.cameraTasks,
                target: PhoneCameraTarget(
                  worldId: 'w',
                  taskId: 'task',
                  assetId: target,
                ),
                onTargetHandled: () => handled++,
              ),
            ),
          ),
        );
        await pumpAlbum(tester);
        final viewer = tester.widget<GenesisImageViewerOverlay>(
          find.byType(GenesisImageViewerOverlay),
        );
        expect(
          viewer.imageUrls[viewer.initialIndex],
          'https://cdn.example/$target.png',
        );
        expect(handled, 1);
        final scroll = tester.widget<CustomScrollView>(
          find.byType(CustomScrollView, skipOffstage: false),
        );
        final offset = scroll.controller!.offset;
        if (target == 200) {
          expect(offset, scroll.controller!.position.maxScrollExtent);
        }
        if (target <= 2) expect(offset, 0);
        await tester.tap(
          find.byKey(const ValueKey('genesis-image-viewer-close')),
        );
        await pumpAlbum(tester);
        expect(find.byType(GenesisImageViewerOverlay), findsNothing);
        expect(scroll.controller!.offset, offset);
        if (target > 100) {
          expect(
            b.calls('album').map((r) => r.uri.queryParameters['pn']),
            containsAllInOrder(['1', '2']),
          );
        }
        await store.refreshAlbum();
        await pumpAlbum(tester);
        expect(find.byType(GenesisImageViewerOverlay), findsNothing);
        expect(handled, 1);
        await tester.pumpWidget(const SizedBox());
        store.dispose();
      },
    );
  }

  for (final count in [1, 2, 4]) {
    testWidgets('camera tasks and photos share grid rows with $count tasks', (
      tester,
    ) async {
      await imageSetup(tester);
      final b = PhoneBackend();
      b.respond = (r) => r.uri.path.endsWith('/album')
          ? ok(page([asset(1), asset(2), asset(3)], rn: 100))
          : null;
      final store = b.store(namespace: 'album-grid-$count');
      await tester.runAsync(() => store.ready);
      store.phoneVisible = true;
      store.albumVisible = true;
      await store.refreshAlbum();
      final jobs = store.cameraTasks;
      jobs.accept(
        const PhotoTask(
          taskId: 'success',
          requestId: 'success',
          status: PhotoTaskStatus.succeeded,
          imageUrl: 'https://cdn.example/99.png',
          assetId: 99,
        ),
      );
      for (var i = 0; i < count; i++) {
        jobs.accept(
          PhotoTask(
            taskId: 'pending-$i',
            requestId: 'pending-$i',
            status: PhotoTaskStatus.generating,
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPhonePhotosPage(
              store: store,
              header: const SizedBox(),
              tasks: jobs,
            ),
          ),
        ),
      );
      await pumpAlbum(tester);
      final origin = tester.getTopLeft(
        find.byKey(ValueKey('camera-task-pending-${count - 1}')),
      );
      void expectCell(int assetId, int index) {
        final rect = tester.getRect(
          find.byKey(ValueKey('mini-phone-album-$assetId')),
        );
        expect(rect.size, const Size(120, 120));
        expect(rect.left, origin.dx + (index % 3) * 120);
        expect(rect.top, origin.dy + (index ~/ 3) * 120);
      }

      expectCell(99, count);
      expectCell(1, count + 1);
      expectCell(2, count + 2);
      expectCell(3, count + 3);

      // Finishing a task keeps a continuous grid with the ordinary photos.
      jobs.accept(
        const PhotoTask(
          taskId: 'pending-0',
          requestId: 'pending-0',
          status: PhotoTaskStatus.succeeded,
          imageUrl: 'https://cdn.example/100.png',
          assetId: 100,
        ),
      );
      await pumpAlbum(tester);
      expectCell(1, count + 1);
      await tester.tap(find.byKey(const ValueKey('mini-phone-album-100')));
      await pumpAlbum(tester);
      final viewer = tester.widget<GenesisImageViewerOverlay>(
        find.byType(GenesisImageViewerOverlay),
      );
      expect(viewer.imageUrls.toSet(), {
        for (final id in [99, 100, 1, 2, 3]) 'https://cdn.example/$id.png',
      });
      expect(
        viewer.imageUrls[viewer.initialIndex],
        'https://cdn.example/100.png',
      );
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  testWidgets(
    'mixed grid pages at the confirmed rows including camera results',
    (tester) async {
      await imageSetup(tester);
      final b = PhoneBackend();
      Completer<Object?>? nextPage;
      b.respond = (r) {
        if (!r.uri.path.endsWith('/album')) return null;
        final pn = int.parse(r.uri.queryParameters['pn']!);
        if (pn == 2 && nextPage != null) return nextPage.future;
        return ok(
          page(
            [for (var id = (pn - 1) * 100 + 1; id <= pn * 100; id++) asset(id)],
            pn: pn,
            rn: 100,
            total: 300,
          ),
        );
      };
      final store = (await tester.runAsync(() async {
        final store = b.store(namespace: 'album-mixed-pagination');
        await store.ready;
        await store.refreshAlbum();
        await store.refreshAlbum(next: true);
        return store;
      }))!;
      store.phoneVisible = true;
      store.albumVisible = true;
      store.cameraTasks.accept(
        const PhotoTask(
          taskId: 'success',
          requestId: 'success',
          status: PhotoTaskStatus.succeeded,
          imageUrl: 'https://cdn.example/201.png',
          assetId: 201,
        ),
      );
      for (var i = 0; i < 2; i++) {
        store.cameraTasks.accept(
          PhotoTask(
            taskId: 'pending-$i',
            requestId: 'pending-$i',
            status: PhotoTaskStatus.generating,
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPhonePhotosPage(
              store: store,
              header: const SizedBox(),
              tasks: store.cameraTasks,
            ),
          ),
        ),
      );
      await pumpAlbum(tester);
      expect(store.album, hasLength(200));
      expect(store.photosController.confirmedAlbum, hasLength(100));
      final calls = b.calls('album').length;
      nextPage = Completer<Object?>();
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      // Two task cells + one local success + 100 confirmed assets = 35 rows.
      final boundary = 35 * 120.0;
      scroll.jumpTo(boundary - scroll.position.viewportDimension - 170);
      await pumpAlbum(tester);
      expect(b.calls('album'), hasLength(calls));
      scroll.jumpTo(scroll.offset + 20);
      await tester.pump();
      expect(b.calls('album'), hasLength(calls + 1));
      expect(b.calls('album').last.uri.queryParameters['pn'], '2');
      nextPage.complete(
        ok(
          page(
            [for (var id = 101; id <= 200; id++) asset(id)],
            pn: 2,
            rn: 100,
            total: 300,
          ),
        ),
      );
      await pumpAlbum(tester);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );

  testWidgets('duplicate URL target resolves to retained asset alias', (
    tester,
  ) async {
    await imageSetup(tester);
    final b = PhoneBackend();
    b.respond = (r) => r.uri.path.endsWith('/album')
        ? ok(
            page([
              asset(1),
              asset(2, url: 'https://cdn.example/1.png'),
            ], rn: 100),
          )
        : null;
    final store = b.store();
    await tester.runAsync(() => store.ready);
    store.phoneVisible = true;
    store.albumVisible = true;
    await store.refreshAlbum();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniPhonePhotosPage(
            store: store,
            header: const SizedBox(),
            target: const PhoneCameraTarget(
              worldId: 'w',
              taskId: 'task',
              assetId: 2,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final viewer = tester.widget<GenesisImageViewerOverlay>(
      find.byType(GenesisImageViewerOverlay),
    );
    expect(viewer.imageUrls, ['https://cdn.example/1.png']);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('user drag cancels delayed target loading', (tester) async {
    await imageSetup(tester);
    final b = PhoneBackend();
    final delayed = Completer<Object?>();
    var hold = false;
    b.respond = (r) => r.uri.path.endsWith('/album')
        ? hold
              ? delayed.future
              : ok(
                  page(
                    [for (var id = 1; id <= 30; id++) asset(id)],
                    rn: 100,
                    total: 200,
                  ),
                )
        : null;
    final store = b.store();
    await tester.runAsync(() => store.ready);
    store.phoneVisible = true;
    store.albumVisible = true;
    await store.refreshAlbum();
    hold = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MiniPhonePhotosPage(
            store: store,
            header: const SizedBox(),
            target: const PhoneCameraTarget(
              worldId: 'w',
              taskId: 'task',
              assetId: 150,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    delayed.complete(ok(page([asset(150)], rn: 100)));
    await tester.pumpAndSettle();
    expect(find.byType(GenesisImageViewerOverlay), findsNothing);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'live task failure has no retry; success merges with formal asset',
    (tester) async {
      await imageSetup(tester);
      final b = PhoneBackend();
      final store = b.store();
      await tester.runAsync(() => store.ready);
      store.phoneVisible = true;
      store.albumVisible = true;
      final jobs = store.cameraTasks;
      jobs.accept(
        const PhotoTask(
          taskId: 'task',
          requestId: 'r',
          status: PhotoTaskStatus.generating,
        ),
      );
      Future<void> mount() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniPhonePhotosPage(
              store: store,
              header: const SizedBox(),
              tasks: jobs,
            ),
          ),
        ),
      );
      await mount();
      await pumpAlbum(tester);
      expect(find.text('Creating your photo'), findsOneWidget);
      final taskTile = find.byKey(const ValueKey('camera-task-r'));
      expect(
        find.descendant(
          of: taskTile,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      jobs.accept(
        const PhotoTask(
          taskId: 'task',
          requestId: 'r',
          status: PhotoTaskStatus.failed,
          failureCode: 'generation_failed',
          failureMessage: 'Failed on server',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Failed on server'), findsOneWidget);
      expect(
        find.descendant(
          of: taskTile,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(find.text('Try again'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await mount();
      await tester.pumpAndSettle();
      expect(find.text('Failed on server'), findsNothing);
      expect(jobs.records, hasLength(1));
      jobs.accept(
        const PhotoTask(
          taskId: 'success',
          requestId: 's',
          status: PhotoTaskStatus.succeeded,
          imageUrl: 'https://cdn.example/99.png',
          assetId: 99,
          description: 'Real result',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mini-phone-album-99')), findsOneWidget);
      b.respond = (r) =>
          r.uri.path.endsWith('/album') ? ok(page([asset(99)], rn: 100)) : null;
      await store.refreshAlbum();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mini-phone-album-99')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    },
  );
}
