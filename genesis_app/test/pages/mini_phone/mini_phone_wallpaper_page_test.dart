import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:genesis_flutter_android/components/common/local_image_crop_page.dart';
import 'package:genesis_flutter_android/components/common/genesis_upload_progress_overlay.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/network/api_client.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/network/local_mock_genesis_transport.dart';
import 'package:genesis_flutter_android/network/models/miniphone_info.dart';
import 'package:genesis_flutter_android/pages/mini_phone/mini_phone.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/mini_phone_settings_page.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/wallpaper/mini_phone_wallpaper_controller.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/wallpaper/mini_phone_wallpaper_cache.dart';
import 'package:genesis_flutter_android/pages/mini_phone/settings/wallpaper/mini_phone_wallpaper_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_list_image.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/ui/components/genesis_primary_button.dart';
import 'package:genesis_flutter_android/ui/animations/app_launch_transition/app_launch_transition.dart';
import 'package:genesis_flutter_android/components/login_sheet.dart';
import '../../support/mini_phone_music_services.dart';

const oldUrl = 'https://cdn.example/current.png';
const newUrl = 'https://cdn.example/new.png';

class _PreviewCache implements MiniPhoneWallpaperCache {
  _PreviewCache(this.bytes);
  final Uint8List bytes;
  final savedImage = Completer<Uint8List>();

  @override
  Future<CachedMiniPhoneWallpaper?> read(String owner, String worldId) async =>
      null;

  @override
  Future<Uint8List> loadImage(String url) async =>
      url == newUrl ? savedImage.future : bytes;

  @override
  Future<void> write(String owner, String worldId, MiniphoneInfo info) async {}

  @override
  Future<void> writeImage(
    String url,
    Uint8List bytes,
    String contentType,
  ) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openCrop(WidgetTester tester) async {
    final source = img.Image(width: 32, height: 64)
      ..clear(img.ColorRgb8(30, 70, 90));
    final png = img.encodePng(source);
    // A valid image with trailing padding also verifies that the old 3 MiB
    // wallpaper gate no longer rejects input before the shared crop pipeline.
    final bytes = Uint8List(3 * 1024 * 1024 + png.length)..setAll(0, png);
    final directory = Directory.systemTemp.createTempSync('wallpaper-crop-');
    final file = File('${directory.path}/photo.png')..writeAsBytesSync(bytes);
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (_) async => file.path);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      directory.deleteSync(recursive: true);
    });
    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      final confirm = find.widgetWithIcon(IconButton, Icons.check);
      if (confirm.evaluate().isNotEmpty &&
          tester.widget<IconButton>(confirm).onPressed != null) {
        break;
      }
    }
    expect(find.byType(LocalImageCropPage), findsOneWidget);
    await tester.pumpAndSettle();
  }

  Future<MiniPhoneWallpaperController> mount(
    WidgetTester tester, {
    String worldId = 'w_1',
    MiniPhoneScreen screen = MiniPhoneScreen.settings,
    Future<MiniphoneInfo> Function()? load,
    Future<void> Function(String)? save,
    MiniWallpaperUploader? upload,
    MiniPhoneWallpaperCache? cache,
    bool nativePickerFlow = false,
    bool loggedIn = true,
    double width = 390,
    double devicePixelRatio = 1,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(
      width * devicePixelRatio,
      844 * devicePixelRatio,
    );
    tester.view.devicePixelRatio = devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final services = () {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      // File IO tests do not need the mobile billing plugin during setup.
      if (nativePickerFlow) {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      }
      try {
        return musicTestServices(
          GenesisApi(
            useMock: false,
            apiClient: ApiClient(
              baseUrl: 'https://api.example/api/',
              transport: LocalMockGenesisTransport.instance,
            ),
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = previousPlatform;
      }
    }();
    final session = services.sessionStore;
    if (loggedIn) await session.saveUid('u_test');
    final controller = MiniPhoneWallpaperController(
      worldId: worldId,
      sessionStore: session,
      cache: cache,
      load:
          load ??
          () async => const MiniphoneInfo(
            backgroundImage: oldUrl,
            wallpapers: [
              MiniphoneWallpaper(imageUrl: newUrl, title: 'New wallpaper'),
            ],
          ),
      save: save ?? (_) async {},
      upload: upload ?? (_, _) async => newUrl,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      AppServicesScope(
        services: services,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: MiniPhonePage(
            worldId: worldId,
            initialScreen: screen,
            wallpaperController: controller,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return controller;
  }

  testWidgets(
    'wallpaper tiles use preview-sized CDN URLs, show dark blocks while loading or failed and save the original URL',
    (tester) async {
      final pending = <String, Completer<ImageInfo>>{};
      debugGenesisStaticNetworkImageCompleter = (provider) =>
          OneFrameImageStreamCompleter(
            (pending[provider.imageUrl] ??= Completer<ImageInfo>()).future,
          );
      addTearDown(() {
        debugGenesisStaticNetworkImageCompleter = null;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      });
      final urls = List.generate(
        3,
        (i) =>
            'https://cdn.example/wallpaper-$i.png?token=abc&x-oss-process=image/resize,w_999',
      );
      final saved = <String>[];
      await mount(
        tester,
        load: () async => MiniphoneInfo(
          backgroundImage: oldUrl,
          wallpapers: [
            for (var i = 0; i < urls.length; i++)
              MiniphoneWallpaper(imageUrl: urls[i], title: 'Wallpaper $i'),
          ],
        ),
        save: (url) async => saved.add(url),
      );
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      await tester.pump();
      for (final url in urls) {
        final thumbnail = find.byKey(ValueKey(url));
        final image = tester.widget<Image>(
          find.descendant(of: thumbnail, matching: find.byType(Image)),
        );
        final provider = image.image as GenesisStaticNetworkImageProvider;
        final resized = Uri.parse(provider.imageUrl);
        expect(resized.path, Uri.parse(url).path);
        expect(resized.queryParameters['token'], 'abc');
        expect(
          resized.queryParameters['x-oss-process'],
          'image/resize,h_676/format,webp',
        );
        expect(provider.cacheWidth, 380);
        expect(provider.cacheHeight, 676);
        expect(tester.getSize(thumbnail).height, 100);
        expect(
          tester
              .widget<ColoredBox>(
                find.descendant(
                  of: thumbnail,
                  matching: find.byType(ColoredBox),
                ),
              )
              .color,
          GenesisColors.darkRaisedBackground,
        );
        expect(
          find.descendant(of: thumbnail, matching: find.byType(RawImage)),
          findsNothing,
        );
        pending[provider.imageUrl]!.completeError(StateError('Unavailable'));
      }
      await tester.pump();
      for (final url in urls) {
        expect(
          tester
              .widget<ColoredBox>(
                find.descendant(
                  of: find.byKey(ValueKey(url)),
                  matching: find.byType(ColoredBox),
                ),
              )
              .color,
          GenesisColors.darkRaisedBackground,
        );
        expect(
          find.descendant(
            of: find.byKey(ValueKey(url)),
            matching: find.byType(RawImage),
          ),
          findsNothing,
        );
      }
      await tester.tap(find.text('Wallpaper 1'));
      await tester.pump();
      await tester.ensureVisible(find.text('Apply wallpaper'));
      await tester.tap(find.text('Apply wallpaper'));
      await tester.pump();
      await tester.pump();
      expect(saved, [urls[1]]);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final ratio in [1.0, 3.0]) {
    testWidgets(
      'selecting a loaded wallpaper reuses the tile frame without another load at DPR $ratio',
      (tester) async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.pink, BlendMode.src);
        final picture = recorder.endRecording();
        final frame = (await tester.runAsync(() => picture.toImage(16, 32)))!;
        picture.dispose();
        final loads = <GenesisStaticNetworkImageProvider>[];
        debugGenesisStaticNetworkImageCompleter = (provider) {
          loads.add(provider);
          return OneFrameImageStreamCompleter(
            SynchronousFuture(ImageInfo(image: frame.clone())),
          );
        };
        addTearDown(() {
          debugGenesisStaticNetworkImageCompleter = null;
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          frame.dispose();
        });
        await mount(tester, devicePixelRatio: ratio);
        final tile = find.byKey(const ValueKey(newUrl));
        final tileProvider =
            tester
                    .widget<Image>(
                      find.descendant(of: tile, matching: find.byType(Image)),
                    )
                    .image
                as GenesisStaticNetworkImageProvider;
        expect(tileProvider.cacheWidth, ratio == 1 ? 190 : 380);
        expect(tileProvider.cacheHeight, ratio == 1 ? 338 : 676);
        final loadCount = loads.length;
        expect(
          loads.where((provider) => provider == tileProvider),
          hasLength(1),
        );
        await tester.tap(find.text('New wallpaper'));
        await tester.pump();
        final preview = find.ancestor(
          of: find.byType(MiniPhoneWallpaperImage),
          matching: find.byType(AspectRatio),
        );
        final previewProvider = tester
            .widget<Image>(
              find.descendant(of: preview, matching: find.byType(Image)),
            )
            .image;
        expect(previewProvider, tileProvider);
        expect(loads, hasLength(loadCount));
        final rendered = tester.widget<RawImage>(
          find.descendant(of: preview, matching: find.byType(RawImage)),
        );
        expect(rendered.image, isNotNull);
        expect(rendered.image!.isCloneOf(frame), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'device picker crops like Location and uploads processed bytes only on Apply',
    (tester) async {
      final uploads = <MiniWallpaperPhoto>[];
      final controller = await mount(
        tester,
        nativePickerFlow: true,
        load: () async =>
            const MiniphoneInfo(backgroundImage: '', wallpapers: []),
        upload: (photo, _) async {
          uploads.add(photo);
          return newUrl;
        },
      );
      await openCrop(tester);
      final cropPage = tester.widget<LocalImageCropPage>(
        find.byType(LocalImageCropPage),
      );
      expect(cropPage.cropSize, const Size(1500, 3000));
      expect(cropPage.maxOutputSize, isNull);
      expect(cropPage.uploadOnConfirm, isFalse);
      expect(cropPage.deferUploadPreparation, isTrue);
      expect(uploads, isEmpty);
      await tester.tap(find.byIcon(Icons.check));
      for (var i = 0; i < 100 && controller.draftPhoto == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final photo = controller.draftPhoto!;
      final decoded = img.decodeImage(photo.bytes)!;
      expect(decoded.width, lessThanOrEqualTo(600));
      expect(decoded.height, lessThanOrEqualTo(600));
      expect(decoded.width / decoded.height, .5);
      expect(photo.contentType, 'image/jpeg');
      expect(photo.filename, 'wallpaper.jpg');
      expect(uploads, isEmpty);
      expect(controller.backgroundImage, '');
      await tester.ensureVisible(find.text('Apply wallpaper'));
      await tester.tap(find.text('Apply wallpaper'));
      await tester.pump();
      for (var i = 0; i < 300 && controller.saving; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final uploaded = uploads.single;
      final fullImage = img.decodeImage(uploaded.bytes)!;
      expect((fullImage.width, fullImage.height), (1500, 3000));
      expect(uploaded.contentType, 'image/jpeg');
      expect(controller.displayBytes, same(uploaded.bytes));
      expect(controller.appliedPreviewBytes, same(photo.bytes));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('canceling wallpaper crop keeps the current draft', (
    tester,
  ) async {
    final controller = await mount(
      tester,
      nativePickerFlow: true,
      load: () async =>
          const MiniphoneInfo(backgroundImage: '', wallpapers: []),
    );
    final asset = await rootBundle.load('assets/images/default_list_image.png');
    final previous = MiniWallpaperPhoto(
      bytes: asset.buffer.asUint8List(),
      filename: 'previous.png',
      contentType: 'image/png',
    );
    controller.selectPhoto(previous);
    await tester.pump();
    await openCrop(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(controller.draftPhoto, same(previous));
    expect(controller.backgroundImage, '');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('account changes discard a pending wallpaper crop result', (
    tester,
  ) async {
    final controller = await mount(
      tester,
      nativePickerFlow: true,
      load: () async =>
          const MiniphoneInfo(backgroundImage: '', wallpapers: []),
    );
    await openCrop(tester);
    await controller.sessionStore.saveUid('another-user');
    await controller.refresh();
    Navigator.of(tester.element(find.byType(LocalImageCropPage))).pop(
      LocalImageCropResult(
        bytes: Uint8List(0),
        width: 1500,
        height: 3000,
        filename: 'wallpaper.jpg',
        contentType: 'image/jpeg',
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.draftPhoto, isNull);
    expect(controller.draftImage, '');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Settings previews selection and Apply automatically returns Home after saving',
    (tester) async {
      final saved = <String>[];
      final pending = Completer<void>();
      final controller = await mount(
        tester,
        save: (url) {
          saved.add(url);
          return pending.future;
        },
      );
      expect(find.text('New wallpaper'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
      expect(find.text('Choose from device'), findsNothing);
      expect(find.text('Reset phone'), findsNothing);
      final preview = find.ancestor(
        of: find.byType(MiniPhoneWallpaperImage),
        matching: find.byType(AspectRatio),
      );
      expect(preview, findsOneWidget);
      final previewSize = tester.getSize(preview);
      expect(previewSize.width, 190);
      expect(previewSize.width / previewSize.height, closeTo(9 / 16, .001));
      expect(find.text('Mist Forest'), findsNothing);
      expect(
        tester
            .widgetList<MiniPhoneWallpaperPreview>(
              find.byType(MiniPhoneWallpaperPreview),
            )
            .map((w) => w.url),
        contains(oldUrl),
      );
      await tester.tap(find.text('New wallpaper'));
      await tester.pump();
      expect(controller.draftImage, newUrl);
      expect(controller.backgroundImage, oldUrl);
      await tester.ensureVisible(find.text('Apply wallpaper'));
      await tester.tap(find.text('Apply wallpaper'));
      await tester.pump();
      await tester.pump();
      expect(saved, [newUrl]);
      expect(
        tester
            .widget<InkWell>(
              find.ancestor(
                of: find.byIcon(Icons.add_photo_alternate_outlined),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      expect(
        tester
            .widget<GenesisPrimaryButton>(find.byType(GenesisPrimaryButton))
            .isLoading,
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(GenesisPrimaryButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<GenesisPrimaryButton>(find.byType(GenesisPrimaryButton))
            .onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(controller.backgroundImage, newUrl);
      expect(find.text('Apply wallpaper'), findsNothing);
      expect(
        tester
            .widgetList<GenesisListImage>(find.byType(GenesisListImage))
            .map((w) => w.imageUrl),
        contains(newUrl),
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Apply keeps Settings open until the desktop original is ready then returns Home',
    (tester) async {
      final asset = await rootBundle.load(
        'assets/images/default_list_image.png',
      );
      final cache = _PreviewCache(asset.buffer.asUint8List());
      final controller = await mount(tester, cache: cache);
      await tester.tap(find.text('New wallpaper'));
      await tester.pump();
      final preview = find.ancestor(
        of: find.byType(MiniPhoneWallpaperImage),
        matching: find.byType(AspectRatio),
      );
      final image = find.descendant(
        of: preview,
        matching: find.byType(MiniPhoneWallpaperPreview),
      );
      final originalElement = tester.element(image);
      await tester.ensureVisible(find.text('Apply wallpaper'));
      await tester.tap(find.text('Apply wallpaper'));
      await tester.pump();
      await tester.pump();
      expect(controller.backgroundImage, newUrl);
      final applyButton = find.widgetWithText(
        GenesisPrimaryButton,
        'Apply wallpaper',
      );
      expect(
        tester.widget<GenesisPrimaryButton>(applyButton).isLoading,
        isTrue,
      );
      expect(controller.saveProgress, lessThan(1));
      expect(tester.element(image), same(originalElement));
      cache.savedImage.complete(cache.bytes);
      await tester.pump();
      await tester.pump();
      expect(controller.displayBackgroundImage, newUrl);
      expect(controller.displayBytes, same(cache.bytes));
      expect(
        tester.widget<GenesisPrimaryButton>(applyButton).isLoading,
        isFalse,
      );
      expect(controller.saveProgress, 1);
      expect(tester.element(image), same(originalElement));
      expect(tester.widget<MiniPhoneWallpaperPreview>(image).url, newUrl);
      await tester.pumpAndSettle();
      expect(find.text('Apply wallpaper'), findsNothing);
      expect(find.byType(MiniPhonePage), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'device photo previews in memory; Apply stays loading through upload and submit',
    (tester) async {
      final events = <String>[];
      final uploadDone = Completer<String>();
      final saveDone = Completer<void>();
      final controller = await mount(
        tester,
        upload: (_, _) {
          events.add('upload');
          return uploadDone.future;
        },
        save: (_) {
          events.add('save');
          return saveDone.future;
        },
      );
      final asset = await rootBundle.load(
        'assets/images/default_list_image.png',
      );
      final bytes = asset.buffer.asUint8List();
      controller.selectPhoto(
        MiniWallpaperPhoto(
          bytes: bytes,
          filename: 'wallpaper.png',
          contentType: 'image/png',
        ),
      );
      await tester.pump();
      bool usesSelectedBytes(Image widget) =>
          widget.image is MemoryImage &&
          identical((widget.image as MemoryImage).bytes, bytes);
      expect(
        tester.widgetList<Image>(find.byType(Image)).any(usesSelectedBytes),
        isTrue,
      );
      final photoPreview = tester
          .widgetList<Image>(find.byType(Image))
          .firstWhere(usesSelectedBytes);
      expect(photoPreview.width, double.infinity);
      expect(photoPreview.height, double.infinity);
      expect(photoPreview.fit, BoxFit.cover);
      expect(photoPreview.alignment, Alignment.center);
      final previewImage = find.descendant(
        of: find.byType(MiniPhoneSettingsPage),
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && usesSelectedBytes(widget),
        ),
      );
      final originalImageState = tester.state(previewImage);
      await tester.runAsync(() async {
        await precacheImage(photoPreview.image, tester.element(previewImage));
      });
      await tester.pump();
      final rawPreview = find.descendant(
        of: previewImage,
        matching: find.byType(RawImage),
      );
      final decodedFrame = tester.widget<RawImage>(rawPreview).image;
      expect(decodedFrame, isNotNull);
      expect(events, isEmpty);
      expect(find.text('Reset phone'), findsNothing);
      await tester.ensureVisible(find.text('Apply wallpaper'));
      await tester.tap(find.text('Apply wallpaper'));
      await tester.pump();
      await tester.pump();
      final button = find.byType(GenesisPrimaryButton);
      expect(events, ['upload']);
      expect(tester.widget<GenesisPrimaryButton>(button).isLoading, isTrue);
      final overlay = find.byType(GenesisUploadProgressOverlay);
      expect(
        tester.widget<GenesisUploadProgressOverlay>(overlay).showIndicator,
        isFalse,
      );
      expect(
        tester.widget<GenesisUploadProgressOverlay>(overlay).revealFromBottom,
        isTrue,
      );
      expect(
        find.descendant(of: overlay, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: overlay,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      await tester.tap(button);
      await tester.pump();
      expect(events, ['upload']);
      uploadDone.complete(newUrl);
      await tester.pump();
      await tester.pump();
      expect(events, ['upload', 'save']);
      expect(tester.widget<GenesisPrimaryButton>(button).isLoading, isTrue);
      expect(
        tester.widgetList<Image>(find.byType(Image)).any(usesSelectedBytes),
        isTrue,
      );
      saveDone.complete();
      await tester.pump();
      expect(tester.state(previewImage), same(originalImageState));
      expect(tester.widget<RawImage>(rawPreview).image, same(decodedFrame));
      await tester.pumpAndSettle();
      expect(find.text('Apply wallpaper'), findsNothing);
      expect(find.byType(MiniPhonePage), findsOneWidget);
      expect(controller.displayBytes, same(bytes));
      expect(
        tester.widgetList<Image>(find.byType(Image)).any(usesSelectedBytes),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('finishing Apply after leaving Settings keeps the current app', (
    tester,
  ) async {
    final pending = Completer<void>();
    final controller = await mount(tester, save: (_) => pending.future);
    await tester.tap(find.text('New wallpaper'));
    await tester.ensureVisible(find.text('Apply wallpaper'));
    await tester.tap(find.text('Apply wallpaper'));
    await tester.pump();
    await tester.pump();
    expect(controller.saving, isTrue);
    await tester.tap(find.widgetWithText(TextButton, 'Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Home position 1'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppLaunchSource && widget.id == MiniPhoneScreen.messages,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(controller.backgroundImage, newUrl);
    expect(find.widgetWithText(TextButton, 'Messages'), findsOneWidget);
    expect(find.byType(MiniPhonePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed save preserves draft and shows retry feedback', (
    tester,
  ) async {
    final controller = await mount(
      tester,
      save: (_) async => throw StateError('offline'),
    );
    await tester.tap(find.text('New wallpaper'));
    await tester.ensureVisible(find.text('Apply wallpaper'));
    await tester.tap(find.text('Apply wallpaper'));
    await tester.pumpAndSettle();
    expect(controller.backgroundImage, oldUrl);
    expect(controller.draftImage, newUrl);
    expect(
      find.text('Unable to save wallpaper. Please retry.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<GenesisPrimaryButton>(find.byType(GenesisPrimaryButton))
          .onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guest Apply opens shared login and never posts automatically', (
    tester,
  ) async {
    final saved = <String>[];
    final controller = await mount(
      tester,
      loggedIn: false,
      save: (url) async {
        saved.add(url);
      },
    );
    await tester.tap(find.text('New wallpaper'));
    await tester.ensureVisible(find.text('Apply wallpaper'));
    await tester.tap(find.text('Apply wallpaper'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginSheet), findsOneWidget);
    expect(saved, isEmpty);
    Navigator.of(tester.element(find.byType(LoginSheet))).pop(false);
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(controller.backgroundImage, oldUrl);
    expect(controller.draftImage, newUrl);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('unscoped preview makes no request and disables Apply', (
    tester,
  ) async {
    await mount(
      tester,
      worldId: '',
      load: () async {
        fail('Unexpected GET');
      },
    );
    expect(
      find.text('Open Mini phone from a World to change its wallpaper.'),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Apply wallpaper'));
    expect(
      tester
          .widget<GenesisPrimaryButton>(find.byType(GenesisPrimaryButton))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty catalogue keeps device picker and fallback preview', (
    tester,
  ) async {
    await mount(
      tester,
      load: () async =>
          const MiniphoneInfo(backgroundImage: '', wallpapers: []),
    );
    expect(
      find.text('No wallpapers available. Choose a photo from your device.'),
      findsNothing,
    );
    expect(find.text('Upload'), findsOneWidget);
    final preview = tester.widget<GenesisListImage>(
      find.byType(GenesisListImage),
    );
    expect(preview.imageUrl, isEmpty);
    expect(preview.placeholderAsset, 'assets/mini_phone/wallpaper-01.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'read error uses a toast and pull refresh restores server catalogue',
    (tester) async {
      var attempts = 0;
      await mount(
        tester,
        load: () async {
          if (attempts++ == 0) throw StateError('offline');
          return const MiniphoneInfo(backgroundImage: newUrl, wallpapers: []);
        },
      );
      expect(
        find.text('Unable to load wallpapers. Please retry.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Unable to load wallpapers. Please retry.'),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(
        find.text('Unable to load wallpapers. Please retry.'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('many long wallpaper titles wrap on narrow large-text Settings', (
    tester,
  ) async {
    await mount(
      tester,
      width: 320,
      textScale: 2,
      load: () async => MiniphoneInfo(
        backgroundImage: '',
        wallpapers: [
          for (var i = 0; i < 8; i++)
            MiniphoneWallpaper(
              imageUrl: 'https://cdn.example/$i.png',
              title: 'A long wallpaper title number $i',
            ),
        ],
      ),
    );
    await tester.ensureVisible(find.text('A long wallpaper title number 7'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
