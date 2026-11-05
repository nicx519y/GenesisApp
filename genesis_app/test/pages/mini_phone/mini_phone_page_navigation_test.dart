import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import '../../support/mini_phone_music_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_widgets.dart';
import 'package:genesis_flutter_android/pages/mini_phone/photos/mini_phone_photos_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/posts/mini_phone_create_post_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_store.dart';
import 'package:genesis_flutter_android/pages/mini_phone/messages/mini_phone_live_chat.dart';
import 'package:genesis_flutter_android/pages/mini_phone/home/mini_phone_home.dart';
import 'package:genesis_flutter_android/ui/navigation/genesis_dark_page_route.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';
import 'package:genesis_flutter_android/ui/animations/app_launch_transition/app_launch_transition.dart';
import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_collect_probe.dart';
import '../../support/mini_phone_memory_cache.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MiniPhoneSession> mount(
    WidgetTester tester,
    TargetPlatform platform, {
    bool outerRoute = false,
    bool directChat = false,
    String entrySource = 'unknown',
    MiniPhoneScreen initialScreen = MiniPhoneScreen.messages,
    Future<bool> Function()? networkAvailabilityCheck,
    MiniPhoneStore? store,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final b = PhoneBackend();
    b.respond = (r) => r.uri.path.endsWith('/dm_sessions')
        ? ok(
            page([
              for (var i = 0; i < 20; i++)
                {
                  ...phoneSession(),
                  'dm_session_id': 0,
                  'char_id': 'c$i',
                  'char_name': 'Person $i',
                },
            ]),
          )
        : null;
    final s = (await tester.runAsync(() async {
      final s =
          store ?? b.store(networkAvailabilityCheck: networkAvailabilityCheck);
      await s.ready;
      return s;
    }))!;
    final session = MiniPhoneSession(data: s);
    addTearDown(session.dispose);
    Widget phone() => MiniPhonePage(
      session: session,
      entrySource: entrySource,
      initialScreen: initialScreen,
      initialContact: directChat
          ? const PhonePerson('c0', 'Person 0', '')
          : null,
    );
    final services = () {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        return musicTestServices(
          GenesisApi(
            useMock: false,
            apiClient: ApiClient(
              baseUrl: 'https://api.example/api/',
              transport: LocalMockGenesisTransport.isolated(),
            ),
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    }();
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(platform: platform),
          home: outerRoute
              ? Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).push(GenesisDarkPageRoute<void>(builder: (_) => phone())),
                    child: const Text('Open phone'),
                  ),
                )
              : phone(),
        ),
      ),
    );
    if (outerRoute) {
      await tester.tap(find.text('Open phone'));
      await tester.pump();
    }
    await settle(tester);
    return session;
  }

  Future<void> pumpCameraFrames(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    // Accepted tasks keep the album indicator animating indefinitely.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'phone entry refreshes cached camera options without blocking captures',
    (tester) async {
      final backend = PhoneBackend();
      final session = await mount(
        tester,
        TargetPlatform.android,
        outerRoute: true,
        initialScreen: MiniPhoneScreen.home,
        store: backend.store(namespace: 'camera-options-entry'),
      );
      expect(backend.calls('photo/options'), hasLength(1));
      final cached = session.data!.cameraTasks.options!;

      Future<void> openCamera() async {
        await tester.tap(find.bySemanticsLabel('Home position 1'));
        await pumpCameraFrames(tester);
        await tester.tap(find.bySemanticsLabel('Camera').first);
        await pumpCameraFrames(tester);
        expect(find.byType(MiniPhoneCameraPage), findsOneWidget);
      }

      await openCamera();
      await tester.binding.handlePopRoute();
      await pumpCameraFrames(tester);
      await openCamera();
      expect(backend.calls('photo/options'), hasLength(1));
      session.camera!.togglePerson(session.data!.people['c']!);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mini-phone-camera-shutter')));
      await pumpCameraFrames(tester);
      await tester.tap(find.text('Generate photo'));
      await pumpCameraFrames(tester);
      expect(backend.calls('photo/create'), hasLength(1));
      expect(backend.calls('photo/options'), hasLength(1));
      expect(
        backend.body(backend.calls('photo/create').single).keys,
        unorderedEquals([
          'client_request_id',
          'world_id',
          'character_ids',
          'aspect_ratio',
          'style',
        ]),
      );

      await tester.tap(find.byTooltip('Close'));
      await pumpCameraFrames(tester);
      final refresh = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/photo/options') ? refresh.future : null;
      await tester.tap(find.text('Open phone'));
      await pumpCameraFrames(tester);
      expect(backend.calls('photo/options'), hasLength(2));
      expect(session.data!.cameraTasks.options, same(cached));
      await openCamera();
      expect(session.camera!.selectedPeople, isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('mini-phone-camera-shutter')));
      await pumpCameraFrames(tester);
      // The entry refresh is still unresolved; the cached confirmation and
      // style must allow create to finish independently of that request.
      expect(refresh.isCompleted, isFalse);
      expect(backend.calls('photo/create'), hasLength(2));
      expect(backend.calls('photo/options'), hasLength(2));
      refresh.complete(
        ok({
          'world_id': 'w',
          'price_cent': 4200,
          'free_status': 'used',
          'styles': [
            {'name': 'Updated selfie', 'label': 'selfie', 'demo_image_url': ''},
          ],
        }),
      );
      await pumpCameraFrames(tester);
      expect(session.data!.cameraTasks.options!.priceCent, 4200);
      expect(session.data!.cameraTasks.options!.freeAvailable, isFalse);
      expect(session.data!.cameraTasks.style!.name, 'Updated selfie');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'camera cold cache waits for options and ignores a previous account refresh',
    (tester) async {
      final backend = PhoneBackend();
      final oldOptions = Completer<Object?>();
      final newOptions = Completer<Object?>();
      backend.respond = (r) {
        if (!r.uri.path.endsWith('/photo/options')) return null;
        return backend.calls('photo/options').length == 1
            ? oldOptions.future
            : newOptions.future;
      };
      final session = await mount(
        tester,
        TargetPlatform.android,
        initialScreen: MiniPhoneScreen.camera,
        store: backend.store(namespace: 'camera-options-account'),
      );
      final shutter = find.byKey(const ValueKey('mini-phone-camera-shutter'));
      expect(backend.calls('photo/options'), hasLength(1));
      expect(session.data!.cameraTasks.options, isNull);
      expect(tester.widget<IconButton>(shutter).onPressed, isNull);
      backend.uid = 'another-account';
      backend.revision.value++;
      await tester.runAsync(() => session.data!.ready);
      await pumpCameraFrames(tester);
      expect(backend.calls('photo/options'), hasLength(2));
      expect(session.data!.cameraTasks.options, isNull);
      newOptions.complete(
        ok({
          'world_id': 'w',
          'price_cent': 4200,
          'free_status': 'used',
          'styles': [
            {
              'name': 'New account style',
              'label': 'new_style',
              'demo_image_url': '',
            },
          ],
        }),
      );
      await pumpCameraFrames(tester);
      expect(session.data!.cameraTasks.options!.priceCent, 4200);
      expect(tester.widget<IconButton>(shutter).onPressed, isNotNull);
      oldOptions.complete(
        backend.defaultResponse(backend.calls('photo/options').first),
      );
      await pumpCameraFrames(tester);
      expect(session.data!.cameraTasks.options!.priceCent, 4200);
      expect(session.data!.cameraTasks.style!.label, 'new_style');
      expect(backend.calls('photo/create'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'camera submits empty prompt with real options and permits parallel accepted tasks',
    (tester) async {
      final backend = PhoneBackend();
      final session = await mount(
        tester,
        TargetPlatform.android,
        initialScreen: MiniPhoneScreen.camera,
        store: backend.store(namespace: 'camera-submit-ui'),
      );
      expect(backend.calls('photo/options'), hasLength(1));
      final camera = session.camera!;
      camera.togglePerson(session.data!.people['c']!);
      await tester.pump();
      expect(camera.prompt, isEmpty);
      await tester.tap(find.byKey(const ValueKey('mini-phone-camera-shutter')));
      await pumpCameraFrames(tester);
      expect(find.text('Base price: 30.0 Gems'), findsWidgets);
      await tester.tap(find.text('Generate photo'));
      await pumpCameraFrames(tester);
      expect(backend.calls('photo/create'), hasLength(1));
      final first = backend.body(backend.calls('photo/create').first);
      expect(first['character_ids'], ['c']);
      expect(first['world_id'], 'w');
      expect(first.containsKey('prompt'), false);
      expect(first['style'], 'selfie');
      expect(find.byType(MiniPhoneCameraPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mini-phone-camera-shutter')));
      await pumpCameraFrames(tester);
      expect(backend.calls('photo/create'), hasLength(2));
      expect(session.data!.cameraTasks.pendingCount, 2);
      expect(backend.calls('photo/options'), hasLength(1));
      expect(
        backend.body(backend.calls('photo/create').last)['client_request_id'],
        isNot(first['client_request_id']),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('camera album back returns to the camera draft', (tester) async {
    await mount(
      tester,
      TargetPlatform.android,
      initialScreen: MiniPhoneScreen.camera,
    );
    expect(find.byType(MiniPhoneCameraPage), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mini-phone-camera-album')));
    await settle(tester);
    final back = find.ancestor(
      of: find.text('Photos'),
      matching: find.byType(TextButton),
    );
    await tester.tap(back.first);
    await settle(tester);
    expect(find.byType(MiniPhoneCameraPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mini-phone-camera-shutter')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final fromCamera in [false, true]) {
      for (final dismiss in [
        'close',
        'system',
        if (platform == TargetPlatform.android) ...[
          'predictive system',
          'predictive cancel',
        ],
        'down',
        'repeated close',
        if (platform == TargetPlatform.iOS) 'swipe',
      ]) {
        testWidgets(
          '$platform album from ${fromCamera ? 'camera' : 'home'} viewer $dismiss returns only to grid',
          (tester) async {
            await tester.runAsync(
              () => databaseFactory.setDatabasesPath(Directory.systemTemp.path),
            );
            const pathChannel = MethodChannel(
              'plugins.flutter.io/path_provider',
            );
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              pathChannel,
              (_) async => Directory.systemTemp.path,
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(pathChannel, null),
            );
            final recorder = ui.PictureRecorder();
            Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
            final picture = recorder.endRecording();
            final image = picture.toImageSync(40, 60);
            picture.dispose();
            debugGenesisStaticNetworkImageCompleter = (_) =>
                OneFrameImageStreamCompleter(
                  SynchronousFuture(ImageInfo(image: image.clone())),
                );
            debugGenesisImageViewerPrecacheImage = (_, _) async {};
            addTearDown(() {
              debugGenesisStaticNetworkImageCompleter = null;
              debugGenesisImageViewerPrecacheImage = null;
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              image.dispose();
            });
            final backend = PhoneBackend();
            backend.respond = (r) => r.uri.path.endsWith('/album')
                ? ok(
                    page([
                      for (var id = 1; id <= 2; id++)
                        {
                          'asset_id': id,
                          'image_url': 'https://cdn.example/$id.png',
                          'desc': 'Photo name $id',
                        },
                    ]),
                  )
                : null;
            final store = backend.store(
              namespace: 'viewer-$platform-$fromCamera-$dismiss',
            );
            final session = await mount(
              tester,
              platform,
              outerRoute: true,
              initialScreen: fromCamera
                  ? MiniPhoneScreen.camera
                  : MiniPhoneScreen.home,
              store: store,
            );
            await tester.tap(
              fromCamera
                  ? find.byKey(const ValueKey('mini-phone-camera-album'))
                  : find.bySemanticsLabel('Photos'),
            );
            await settle(tester);
            await tester.tap(find.byKey(const ValueKey('mini-phone-album-1')));
            await settle(tester);
            expect(find.byType(GenesisImageViewerOverlay), findsOneWidget);
            expect(find.text('Photo name 1'), findsNothing);
            final actionRect = tester.getRect(
              find.byType(GenesisPrimaryButton),
            );
            final dotsRect = tester.getRect(
              find.byKey(const ValueKey('genesis-image-viewer-page-dots')),
            );
            expect(dotsRect.top - actionRect.bottom, 16);
            expect(
              tester
                  .getBottomLeft(
                    find.byKey(
                      const ValueKey('genesis-image-viewer-page-view'),
                    ),
                  )
                  .dy,
              lessThanOrEqualTo(actionRect.top),
            );
            if (dismiss == 'close') {
              await tester.tap(
                find.byKey(const ValueKey('genesis-image-viewer-close')),
              );
            } else if (dismiss == 'system') {
              await tester.binding.handlePopRoute();
            } else if (dismiss.startsWith('predictive')) {
              final previousPlatform = debugDefaultTargetPlatformOverride;
              debugDefaultTargetPlatformOverride = TargetPlatform.android;
              try {
                for (final call in [
                  const MethodCall('startBackGesture', {
                    'touchOffset': <double>[5, 300],
                    'progress': 0.0,
                    'swipeEdge': 0,
                  }),
                  const MethodCall('updateBackGestureProgress', {
                    'touchOffset': <double>[150, 300],
                    'progress': 0.5,
                    'swipeEdge': 0,
                  }),
                  MethodCall(
                    dismiss == 'predictive cancel'
                        ? 'cancelBackGesture'
                        : 'commitBackGesture',
                  ),
                ]) {
                  await tester.binding.defaultBinaryMessenger
                      .handlePlatformMessage(
                        'flutter/backgesture',
                        const StandardMethodCodec().encodeMethodCall(call),
                        (_) {},
                      );
                  await tester.pump();
                }
              } finally {
                debugDefaultTargetPlatformOverride = previousPlatform;
              }
              if (dismiss == 'predictive cancel') {
                await settle(tester);
                expect(find.byType(GenesisImageViewerOverlay), findsOneWidget);
                await tester.binding.handlePopRoute();
              }
            } else if (dismiss == 'down') {
              await tester.dragFrom(
                const Offset(180, 300),
                const Offset(0, 100),
              );
            } else if (dismiss == 'repeated close') {
              final close = tester
                  .widget<IconButton>(
                    find.byKey(const ValueKey('genesis-image-viewer-close')),
                  )
                  .onPressed!;
              close();
              close();
            } else {
              final gesture = await tester.startGesture(const Offset(1, 300));
              await gesture.moveBy(const Offset(100, 0));
              await gesture.moveBy(const Offset(100, 0));
              await tester.pump();
              await gesture.moveBy(const Offset(0, 300));
              await gesture.up();
            }
            await settle(tester);
            expect(find.byType(GenesisImageViewerOverlay), findsNothing);
            expect(find.byType(MiniPhonePhotosPage), findsOneWidget);
            expect(
              find.byKey(const ValueKey('mini-phone-album-1')),
              findsOneWidget,
            );
            await tester.tap(find.widgetWithText(TextButton, 'Photos'));
            await settle(tester);
            expect(find.byType(MiniPhonePhotosPage), findsNothing);
            expect(
              fromCamera
                  ? find.byType(MiniPhoneCameraPage)
                  : find.byType(MiniPhoneHome),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            session.dispose();
          },
        );
      }
    }
  }

  for (final selectedIndex in [0, 1]) {
    testWidgets(
      'album photo $selectedIndex reuses thumbnail, publishes original and closes toward Posts',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'camera-post-test-',
        );
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        await tester.runAsync(
          () => databaseFactory.setDatabasesPath(directory.path),
        );
        const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          pathChannel,
          (_) async => directory.path,
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            pathChannel,
            null,
          );
        });
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 40, 60), Paint());
        final picture = recorder.endRecording();
        final image = (await tester.runAsync(() => picture.toImage(40, 60)))!;
        picture.dispose();
        final imageLoads = <GenesisStaticNetworkImageProvider>[];
        debugGenesisStaticNetworkImageCompleter = (key) {
          imageLoads.add(key);
          return OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image.clone())),
          );
        };
        debugGenesisImageViewerPrecacheImage = (_, _) async {};
        addTearDown(() {
          debugGenesisStaticNetworkImageCompleter = null;
          debugGenesisImageViewerPrecacheImage = null;
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          image.dispose();
        });
        final backend = PhoneBackend();
        backend.respond = (r) => r.uri.path.endsWith('/album')
            ? ok(
                page([
                  for (var i = 0; i < 2; i++)
                    {
                      'asset_id': i + 1,
                      'image_url':
                          'https://cdn.example/camera-result-$i.png?token=original',
                      'desc': 'Photo name $i',
                    },
                ]),
              )
            : null;
        final session = await mount(
          tester,
          selectedIndex == 0 ? TargetPlatform.android : TargetPlatform.iOS,
          initialScreen: MiniPhoneScreen.home,
          store: backend.store(namespace: 'camera-viewer-post-$selectedIndex'),
        );
        final hostOrigin = tester.getTopLeft(
          find.byType(AppLaunchTransitionHost),
        );
        final postsRect = tester
            .getRect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is AppLaunchSource &&
                    widget.id == MiniPhoneScreen.posts,
              ),
            )
            .shift(-hostOrigin);
        final home = tester.widget<MiniPhoneHome>(find.byType(MiniPhoneHome));
        session.postDraft!.setText('Keep real draft');
        home.onLaunch(
          MiniPhoneScreen.photos,
          MiniPhoneScreen.photos,
          () => home.onNavigate(MiniPhoneScreen.photos),
        );
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('mini-phone-album-1')));
        await settle(tester);
        if (selectedIndex == 1) {
          await tester.drag(
            find.descendant(
              of: find.byType(GenesisImageViewerOverlay),
              matching: find.byType(PageView),
            ),
            const Offset(-390, 0),
          );
          await settle(tester);
        }
        final viewer = tester.widget<GenesisImageViewerOverlay>(
          find.byType(GenesisImageViewerOverlay),
        );
        final preview = viewer.previewImageProviders[selectedIndex];
        final loadsBeforeCreate = List.of(imageLoads);
        final usePhoto = tester
            .widget<GenesisPrimaryButton>(find.byType(GenesisPrimaryButton))
            .onPressed!;
        usePhoto();
        usePhoto();
        await settle(tester);
        final create = tester.widget<MiniPhoneCreatePostPage>(
          find.byType(MiniPhoneCreatePostPage),
        );
        expect(create.draft.isCameraPreview, isFalse);
        final originalUrl =
            'https://cdn.example/camera-result-$selectedIndex.png?token=original';
        expect(create.draft.uploadedUrl, originalUrl);
        expect(create.draft.previewImageProvider, same(preview));
        expect(
          tester
              .widget<Image>(
                find.byKey(const ValueKey('mini-phone-album-draft-photo')),
              )
              .image,
          same(preview),
        );
        expect(imageLoads, loadsBeforeCreate);
        expect(find.byType(BottomSheet), findsNothing);
        await tester.enterText(find.byType(TextField), 'Local caption');
        expect(create.draft.canSubmit, isTrue);
        expect(session.postDraft!.text, 'Keep real draft');
        expect(
          await tester.runAsync(
            () => create.draft.submit(
              (_) async =>
                  throw StateError('Album photo must not upload again'),
            ),
          ),
          isTrue,
        );
        expect(
          backend.body(backend.calls('post/create').single)['image'],
          originalUrl,
        );
        expect(create.draft.previewImageProvider, isNull);
        create.onPublished();
        await settle(tester);
        expect(session.composingCameraPhoto, isFalse);
        expect(find.widgetWithText(TextButton, 'Posts'), findsOneWidget);
        TestGesture? gesture;
        if (selectedIndex == 0) {
          await tester.tap(find.widgetWithText(TextButton, 'Posts'));
          await tester.pump();
          await tester.pump(const Duration(microseconds: 279900));
        } else {
          gesture = await tester.startGesture(const Offset(1, 400));
          await gesture.moveBy(const Offset(420, 0));
          await tester.pump();
        }
        final flight = tester.widget<Positioned>(
          find.byKey(const ValueKey('app-launch-surface')),
        );
        expect(flight.left, closeTo(postsRect.left, 5));
        expect(flight.top, closeTo(postsRect.top, 5));
        expect(flight.width, closeTo(postsRect.width, 5));
        expect(flight.height, closeTo(postsRect.height, 5));
        await gesture?.up();
        await settle(tester);
        expect(find.byType(MiniPhoneHome), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
        await settle(tester);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final resource in ['people', 'album']) {
    testWidgets(
      'open camera applies late $resource refresh without losing its draft or rebuilding navigation',
      (tester) async {
        final backend = PhoneBackend();
        Completer<WorldDetail>? worldResponse;
        final store = (await tester.runAsync(() async {
          final store = MiniPhoneStore(
            api: backend.api,
            worldId: 'w',
            namespace: 'camera-navigation-$resource',
            readUid: () async => 'u',
            accountRevision: backend.revision,
            cacheStorage: MemoryMiniPhoneCacheStorage(),
            loadWorld: () async =>
                worldResponse?.future ??
                WorldDetail.fromJson({
                  'world_id': 'w',
                  'characters': [
                    {'char_id': 'c', 'name': 'Character'},
                  ],
                }),
          );
          await store.ready;
          return store;
        }))!;
        final session = await mount(
          tester,
          TargetPlatform.android,
          initialScreen: MiniPhoneScreen.camera,
          store: store,
        );
        final camera = find.byType(MiniPhoneCameraPage);
        final cameraState = tester.state(camera);
        final navigator = find.descendant(
          of: find.byType(MiniPhonePage),
          matching: find.byType(Navigator),
        );
        final navigatorBefore = tester.widget<Navigator>(navigator);
        await tester.tap(find.text('Character'));
        await tester.enterText(find.byType(TextField), 'Keep my camera draft');
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester);
        expect(session.camera!.selectedPeople.single.id, 'c');

        final albumResponse = Completer<Object?>();
        worldResponse = Completer<WorldDetail>();
        backend.respond = (request) =>
            request.uri.path.endsWith('/album') ? albumResponse.future : null;
        final refresh = resource == 'people'
            ? store.refreshPeople()
            : store.refreshAlbum();
        await tester.pump();
        expect(store.busy, contains(resource));
        expect(find.text('Late character'), findsNothing);
        expect(
          tester.widget<MiniPhoneCameraPage>(camera).albumThumbnailUrl,
          isNull,
        );
        const cover = 'https://camera.test/late-cover.webp';
        const photo = 'https://camera.test/late-photo.webp';
        const thumbnail = 'https://camera.test/late-thumbnail.webp';
        if (resource == 'people') {
          worldResponse.complete(
            WorldDetail.fromJson({
              'world_id': 'w',
              'cover': cover,
              'characters': [
                {'char_id': 'c', 'name': 'Character updated'},
                {'char_id': 'late', 'name': 'Late character'},
              ],
            }),
          );
        } else {
          albumResponse.complete(
            ok(
              page([
                {
                  'asset_id': 42,
                  'world_id': 'w',
                  'image_url': photo,
                  'thumbnail_url': thumbnail,
                },
              ]),
            ),
          );
        }
        await settle(tester);
        expect(await refresh, isTrue);
        expect(tester.takeException(), isNull);
        if (resource == 'people') {
          expect(find.text('Late character'), findsOneWidget);
          expect(find.text('Character updated'), findsOneWidget);
          expect(
            tester
                .widget<MiniPhoneCameraViewfinder>(
                  find.byType(MiniPhoneCameraViewfinder),
                )
                .imageUrl,
            cover,
          );
          expect(
            session.camera!.selectedPeople.single.name,
            'Character updated',
          );
        } else {
          final image = find.descendant(
            of: find.byKey(const ValueKey('mini-phone-camera-album')),
            matching: find.byType(GenesisStaticNetworkImage),
          );
          expect(image, findsOneWidget);
          expect(
            tester.widget<GenesisStaticNetworkImage>(image).imageUrl,
            '$thumbnail?x-oss-process=image/resize,w_96/format,webp',
          );
        }
        expect(tester.state(camera), same(cameraState));
        expect(tester.widget<Navigator>(navigator), same(navigatorBefore));
        expect(session.camera!.selectedPeople.single.id, 'c');
        expect(session.camera!.prompt, 'Keep my camera draft');
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Keep my camera draft',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final directChat in [false, true]) {
    testWidgets(
      'offline Send shows a toast in the real phone navigator directChat=$directChat',
      (tester) async {
        final session = await mount(
          tester,
          TargetPlatform.android,
          directChat: directChat,
          networkAvailabilityCheck: () async => false,
        );
        if (!directChat) {
          await tester.tap(
            find.byKey(const ValueKey('mini-phone-conversation-c0')),
          );
          await settle(tester);
        }
        await tester.enterText(find.byType(TextField), 'Keep offline draft');
        for (
          var i = 0;
          i < 6 &&
              !tester
                  .widget<ChatComposer>(find.byType(ChatComposer))
                  .sendEnabled;
          i++
        ) {
          await settle(tester);
        }
        expect(
          tester.widget<ChatComposer>(find.byType(ChatComposer)).sendEnabled,
          isTrue,
        );
        for (var attempt = 0; attempt < 2; attempt++) {
          await tester.tap(
            find.byKey(const ValueKey('chat-composer-send-button')),
          );
          await settle(tester);
          expect(
            find.text('Network unavailable. Check network.'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<ChatComposer>(find.byType(ChatComposer))
                .controller
                .text,
            'Keep offline draft',
          );
          expect(session.data!.pending, isEmpty);
          expect(session.data!.outgoingDm('c0'), isEmpty);
          await tester.pump(const Duration(seconds: 3));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final source in [
    'world_dock',
    'location_chat_dock',
    'location_chat_avatar',
    'location_chat_roster',
  ]) {
    testWidgets(
      'Collect direct chat from $source has no phantom Home or Messages',
      (tester) async {
        final collect = MiniPhoneCollectProbe();
        addTearDown(collect.dispose);
        final session = await mount(
          tester,
          TargetPlatform.android,
          directChat: true,
          entrySource: source,
        );
        final events = (await tester.runAsync(collect.take))!;
        expect(events.map((e) => e.action), [
          'mini_phone_open',
          'mini_phone_page',
        ]);
        expect(events.map((e) => e.object2), ['chat', 'chat']);
        expect(jsonDecode(events.first.extData)['source'], source);
        expect(jsonDecode(events.last.extData)['char_id'], 'c0');
        await tester.runAsync(() => session.data!.refreshPosts());
        await settle(tester);
        expect(await tester.runAsync(collect.take), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Collect page transitions count visits once and preserve open ID',
    (tester) async {
      final collect = MiniPhoneCollectProbe();
      addTearDown(collect.dispose);
      final session = await mount(
        tester,
        TargetPlatform.android,
        entrySource: 'world_dock',
      );
      final initial = (await tester.runAsync(collect.take))!;
      expect(initial.map((e) => e.action), [
        'mini_phone_open',
        'mini_phone_page',
      ]);
      final openId = jsonDecode(initial.first.extData)['open_id'];
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-conversation-c0')),
      );
      await tester.pump();
      await settle(tester);
      var events = (await tester.runAsync(collect.take))!;
      expect(events.single.object2, 'chat');
      expect(jsonDecode(events.single.extData)['source'], 'messages_list');
      expect(jsonDecode(events.single.extData)['open_id'], openId);
      await tester.binding.handlePopRoute();
      await tester.pump();
      await settle(tester);
      events = (await tester.runAsync(collect.take))!;
      expect(events.single.object2, 'messages');
      expect(jsonDecode(events.single.extData)['navigation_type'], 'back');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(session.data!.analytics.openId, isNull);
    },
  );

  testWidgets('content refresh leaves the shell Navigator unchanged', (
    tester,
  ) async {
    final session = await mount(tester, TargetPlatform.android);
    final navigator = find.descendant(
      of: find.byType(MiniPhonePage),
      matching: find.byType(Navigator),
    );
    final before = tester.widget<Navigator>(navigator);
    await tester.runAsync(() => session.data!.refreshPosts());
    await settle(tester);
    expect(session.data!.posts, isNotEmpty);
    expect(tester.widget<Navigator>(navigator), same(before));
    expect(find.text('Person 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform list-to-chat uses the shared route and back preserves the list',
      (tester) async {
        await mount(tester, platform);
        final list = find.byType(ListView);
        final listElement = tester.element(list);
        await tester.drag(list, const Offset(0, -350));
        await tester.pumpAndSettle();
        final scrollable = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        final scroll = tester.state<ScrollableState>(scrollable).position;
        final offset = scroll.pixels;
        expect(offset, greaterThan(0));
        await tester.tap(
          find.byKey(const ValueKey('mini-phone-conversation-c8')),
        );
        await tester.pump();
        final chat = find.byType(MiniPhoneLiveChat);
        final route = ModalRoute.of(tester.element(chat))!;
        expect(route, isA<GenesisDarkPageRoute<void>>());
        expect(route.animation!.value, lessThan(1));
        await tester.pump(const Duration(milliseconds: 80));
        expect(route.animation!.value, greaterThan(0));
        expect(route.animation!.value, lessThan(1));
        await settle(tester);
        expect(route.animation!.isCompleted, isTrue);
        if (platform == TargetPlatform.android) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.widgetWithText(TextButton, 'Person 8'));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(route.animation!.value, greaterThan(0));
        expect(route.animation!.value, lessThan(1));
        await settle(tester);
        expect(chat, findsNothing);
        expect(tester.element(find.byType(ListView)), same(listElement));
        expect(scroll.pixels, closeTo(offset, .01));
        expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('iOS swipe back removes the chat and keeps the phone open', (
    tester,
  ) async {
    await mount(tester, TargetPlatform.iOS);
    await tester.tap(find.byKey(const ValueKey('mini-phone-conversation-c0')));
    await tester.pump();
    await settle(tester);
    await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
    await settle(tester);
    expect(find.byType(MiniPhoneLiveChat), findsNothing);
    expect(find.byType(MiniPhonePage), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final screen in [
    MiniPhoneScreen.messages,
    MiniPhoneScreen.posts,
    MiniPhoneScreen.photos,
    MiniPhoneScreen.music,
    MiniPhoneScreen.settings,
  ]) {
    testWidgets('iOS $screen swipes to desktop then exits the phone', (
      tester,
    ) async {
      await mount(
        tester,
        TargetPlatform.iOS,
        outerRoute: true,
        initialScreen: screen,
      );
      // Exactly one real desktop survives behind every internal app route.
      final desktop = tester.element(
        find.byType(MiniPhoneHome, skipOffstage: false),
      );
      await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
      await settle(tester);
      expect(find.byType(MiniPhonePage), findsOneWidget);
      expect(tester.element(find.byType(MiniPhoneHome)), same(desktop));
      expect(find.byType(Navigator), findsOneWidget);
      await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
      await settle(tester);
      expect(find.byType(MiniPhonePage), findsNothing);
      expect(find.text('Open phone'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'canceling an iOS root-app swipe leaves its page and phone open',
    (tester) async {
      await mount(tester, TargetPlatform.iOS, outerRoute: true);
      final gesture = await tester.startGesture(const Offset(1, 400));
      await gesture.moveBy(const Offset(70, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-65, 0));
      await gesture.up();
      await settle(tester);
      expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
      expect(find.byType(MiniPhonePage), findsOneWidget);
      expect(find.byType(Navigator), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('iOS swipe back from a direct chat returns to its caller', (
    tester,
  ) async {
    final session = await mount(
      tester,
      TargetPlatform.iOS,
      outerRoute: true,
      directChat: true,
    );
    expect(find.byType(MiniPhoneLiveChat), findsOneWidget);
    await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
    await settle(tester);
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(session.isDisposed, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final screen in [MiniPhoneScreen.create, MiniPhoneScreen.comments]) {
    testWidgets('iOS $screen swipes back through Posts to desktop', (
      tester,
    ) async {
      await mount(tester, TargetPlatform.iOS, initialScreen: screen);
      await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
      await settle(tester);
      expect(find.widgetWithText(TextButton, 'Posts'), findsOneWidget);
      await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
      await settle(tester);
      expect(find.byType(MiniPhoneHome), findsOneWidget);
      // Returning home schedules its existing debounced refresh. Let it drain
      // before this test releases the externally-owned phone session.
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('iOS models swipe returns to direct chat then its caller', (
    tester,
  ) async {
    await mount(tester, TargetPlatform.iOS, outerRoute: true, directChat: true);
    await tester.tap(find.byKey(const ValueKey('memory-model-entry')));
    await settle(tester);
    expect(find.byType(MiniPhoneLiveChat), findsNothing);
    await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
    await settle(tester);
    expect(find.byType(MiniPhoneLiveChat), findsOneWidget);
    await tester.dragFrom(const Offset(1, 400), const Offset(340, 0));
    await settle(tester);
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('close while iOS swipe is active never pops the caller twice', (
    tester,
  ) async {
    await mount(tester, TargetPlatform.iOS, outerRoute: true);
    final gesture = await tester.startGesture(const Offset(1, 400));
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await gesture.up();
    await settle(tester);
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('close during internal navigation exits the entire phone', (
    tester,
  ) async {
    await mount(tester, TargetPlatform.android, outerRoute: true);
    await tester.tap(find.byKey(const ValueKey('mini-phone-conversation-c0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'repeated close before the next frame preserves the parent route',
    (tester) async {
      await mount(tester, TargetPlatform.android, outerRoute: true);
      await tester.tap(find.byTooltip('Close'));
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(MiniPhonePage), findsNothing);
      expect(find.text('Open phone'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('system back after close does not pop the parent route twice', (
    tester,
  ) async {
    await mount(tester, TargetPlatform.android, outerRoute: true);
    await tester.tap(find.byTooltip('Close'));
    // The close callback is waiting for the next frame; emulate a competing pop.
    final context = tester.element(find.byType(MiniPhonePage));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.byType(MiniPhonePage), findsNothing);
    expect(find.text('Open phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
