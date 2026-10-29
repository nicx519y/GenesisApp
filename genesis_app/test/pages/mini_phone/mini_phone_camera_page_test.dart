import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_widgets.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_cast.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';

final _strings = MiniPhoneCameraStrings(
  inThePhoto: 'In the photo',
  selectedCount: (count) => count == 0 ? 'No one selected' : '$count selected',
  castHint: 'Tap the people below to bring them into the frame.',
  you: 'You',
  describeMoment: 'Describe the moment',
  promptHint: 'Where are you? What’s the mood?',
  tryTemplate: 'Try a template',
  templateHint: 'Tap to fill the prompt',
  povSelfie: 'POV selfie',
  mirrorSelfie: 'Mirror selfie',
  byFriend: 'By a friend',
  povSelfiePrompt: 'Selfie prompt for only the selected people.',
  mirrorSelfiePrompt: 'Mirror prompt for only the selected people.',
  byFriendPrompt: 'Friend prompt for only the selected people.',
  takePhoto: 'Take photo',
  tryAgain: 'Try again',
  pricePerPhoto: (price) => '$price Gems / photo',
  comingSoon: 'Coming soon',
  creatingPhoto: 'Creating your photo',
  creatingTitle: 'A moment in the making.',
  creatingBody: 'Bringing your characters and scene together.',
  cancel: 'Cancel',
  generationFailed: 'Could not create this photo.',
  draftPreserved: 'Draft preserved',
  takeAnother: 'Take another',
  useInPost: 'Use in a post',
  openPhoto: 'Open photo',
  imageUnavailable: 'Image unavailable',
  savedToPhotos: 'Saved to Photos',
  syncingPhotos: 'Syncing Photos',
  photoSyncFailed: 'Could not sync Photos',
);
const _person = PhonePerson('person-a', 'Person A', '');

void main() {
  late MiniPhoneCameraController camera;
  setUp(() {
    final requests = MiniPhoneRequests(() {})..uid = 'account';
    camera = MiniPhoneCameraController(
      requests: requests,
      scope: const MiniPhoneCameraScope(
        environment: 'test',
        accountId: 'account',
        worldId: 'world',
      ),
    );
  });
  tearDown(() {
    camera.dispose();
  });

  Widget app({
    String initialPrompt = '',
    MiniPhoneCameraGenerate? generate,
    double? price,
    double scale = 1,
    double keyboardInset = 0,
    VoidCallback? onOpenAlbum,
    Future<void> Function()? onCaptureRequested,
    String? albumThumbnailUrl,
    List<PhonePerson> people = const [_person],
    Widget? header,
    String coverImageUrl = '',
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: GenesisTheme.dark(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
      ),
      child: child!,
    ),
    home: Scaffold(
      resizeToAvoidBottomInset: false,
      body: MiniPhoneCameraPage(
        header: header ?? const SizedBox(height: 56),
        people: people,
        strings: _strings,
        controller: camera,
        coverImageUrl: coverImageUrl,
        initialPrompt: initialPrompt,
        onGenerate: generate,
        priceGems: price,
        onOpenAlbum: onOpenAlbum,
        albumLabel: 'Photos',
        onCaptureRequested: onCaptureRequested,
        albumThumbnailUrl: albumThumbnailUrl,
      ),
    ),
  );

  Future<void> size(WidgetTester tester, Size value) async {
    await tester.binding.setSurfaceSize(value);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets(
    'draft remains editable with no adapter and unknown price is hidden',
    (tester) async {
      await size(tester, const Size(390, 844));
      await tester.pumpWidget(app(initialPrompt: 'Latest reply'));
      expect(find.text('Coming soon'), findsNothing);
      expect(camera.prompt, 'Latest reply');
      expect(camera.selectedPeople, isEmpty);
      camera.togglePerson(_person);
      await tester.enterText(find.byType(TextField), 'An edited scene');
      await tester.pump();
      expect(camera.prompt, 'An edited scene');
      final shutter = find.byKey(const ValueKey('mini-phone-camera-shutter'));
      expect(shutter, findsOneWidget);
      expect(tester.widget<IconButton>(shutter).onPressed, isNull);
      expect(
        tester.widget<IconButton>(shutter).style!.backgroundColor!.resolve({
          WidgetState.disabled,
        }),
        Colors.transparent,
      );
      expect(find.text(_strings.takePhoto), findsNothing);
      expect(find.textContaining('Gems'), findsNothing);
      expect(find.byType(MiniPhoneCameraTemplateChoice), findsNothing);
      expect(
        find.byKey(const ValueKey('mini-phone-camera-viewfinder')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'template fills editable prompt and editing clears its selection',
    (tester) async {
      await size(tester, const Size(350, 740));
      await tester.pumpWidget(app());
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-camera-templates')),
      );
      await tester.pumpAndSettle();
      expect(find.text(_strings.templateHint), findsNothing);
      final template = find.byType(MiniPhoneCameraTemplateChoice).first;
      await tester.ensureVisible(template);
      await tester.tap(template);
      await tester.pumpAndSettle();
      expect(camera.prompt, _strings.povSelfiePrompt);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-camera-templates')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<MiniPhoneCameraTemplateChoice>(template).selected,
        isTrue,
      );
      Navigator.of(tester.element(template)).pop();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Edited template');
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-camera-templates')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<MiniPhoneCameraTemplateChoice>(template).selected,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(template)).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('page disposal and reopening preserve selection and prompt', (
    tester,
  ) async {
    await tester.pumpWidget(app(initialPrompt: 'Original reply'));
    camera.togglePerson(_person);
    camera.setPrompt('My edited draft');
    await tester.pumpWidget(const SizedBox());
    expect(camera.prompt, 'My edited draft');
    expect(camera.selectedPeople, [_person]);
    await tester.pumpWidget(app());
    expect(find.text('My edited draft'), findsOneWidget);
    expect(camera.selectedPeople, [_person]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'unmount during generation cancels token and rejects late image',
    (tester) async {
      await size(tester, const Size(350, 740));
      final output = Completer<MiniPhoneCameraResult>();
      late MiniPhoneCameraCancellation token;
      Future<MiniPhoneCameraResult> generate(
        MiniPhoneCameraRequest request,
        MiniPhoneCameraCancellation cancellation,
      ) {
        token = cancellation;
        return output.future;
      }

      await tester.pumpWidget(app(initialPrompt: 'Draft', generate: generate));
      camera.togglePerson(_person);
      final task = camera.generate(generate);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(token.isCancelled, isTrue);
      output.complete(
        MiniPhoneCameraResult(imageUrl: 'https://camera.test/late.webp'),
      );
      await task;
      expect(camera.result, isNull);
      expect(camera.prompt, 'Draft');
      expect(camera.selectedPeople, [_person]);
    },
  );

  testWidgets(
    'generation error uses transient public Toast and retains retry draft',
    (tester) async {
      await tester.pumpWidget(app(initialPrompt: 'Draft'));
      camera.togglePerson(_person);
      await camera.generate((_, _) async => throw StateError('Rejected'));
      await tester.pump();
      expect(find.text(_strings.generationFailed), findsOneWidget);
      expect(find.text(_strings.takePhoto), findsNothing);
      expect(
        find.byKey(const ValueKey('mini-phone-camera-shutter')),
        findsOneWidget,
      );
      expect(find.text(_strings.draftPreserved), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(_strings.generationFailed), findsNothing);
      expect(camera.prompt, 'Draft');
      expect(camera.selectedPeople, [_person]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'only injected finite price appears and large text stays scrollable',
    (tester) async {
      await size(tester, const Size(350, 740));
      await tester.pumpWidget(app(price: 7.5, scale: 2));
      expect(find.textContaining('7.5 Gems / photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(price: double.nan, scale: 2));
      expect(find.textContaining('Gems'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('album control invokes only the injected callback', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(app(onOpenAlbum: () => calls++));
    await tester.tap(find.byKey(const ValueKey('mini-phone-camera-album')));
    expect(calls, 1);
    expect(camera.result, isNull);
    await tester.pumpWidget(app());
    expect(
      tester
          .widget<MiniPhoneCameraThumbnail>(
            find.byKey(const ValueKey('mini-phone-camera-album')),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'templates scroll horizontally and selecting the last fills then closes',
    (tester) async {
      await size(tester, const Size(350, 740));
      await tester.pumpWidget(app());
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-camera-templates')),
      );
      await tester.pumpAndSettle();
      final scroll = find.byKey(
        const ValueKey('mini-phone-camera-template-scroll'),
      );
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      await tester.drag(scroll, const Offset(-250, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MiniPhoneCameraTemplateChoice).last);
      await tester.pumpAndSettle();
      expect(camera.prompt, _strings.byFriendPrompt);
      expect(find.byType(BottomSheet), findsNothing);
      expect(camera.selectedPeople, isEmpty);
      expect(camera.result, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('keyboard hides controls without resizing the viewfinder', (
    tester,
  ) async {
    await size(tester, const Size(350, 740));
    await tester.pumpWidget(app(scale: 2));
    final frame = find.byKey(const ValueKey('mini-phone-camera-viewfinder'));
    final before = tester.getRect(frame);
    await tester.pumpWidget(app(scale: 2, keyboardInset: 300));
    expect(tester.getRect(frame), before);
    expect(
      find.byKey(const ValueKey('mini-phone-camera-shutter')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mini-phone-camera-album')).hitTestable(),
      findsNothing,
    );
    expect(find.byType(MiniPhoneCameraCastChoice).hitTestable(), findsNothing);
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(
      find.byType(TextField),
      'A long keyboard draft\nwith another line',
    );
    await tester.pumpAndSettle();
    expect(camera.prompt, contains('keyboard draft'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(app(scale: 2));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mini-phone-camera-shutter')).hitTestable(),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'capture explanation works with no people or draft and wins over generation',
    (tester) async {
      var captures = 0, generations = 0;
      final confirmation = Completer<void>();
      await tester.pumpWidget(
        app(
          people: const [],
          onCaptureRequested: () {
            captures++;
            return confirmation.future;
          },
          generate: (_, _) async {
            generations++;
            return MiniPhoneCameraResult(
              imageUrl: 'https://camera.test/unused.webp',
            );
          },
        ),
      );
      final shutter = find.byKey(const ValueKey('mini-phone-camera-shutter'));
      expect(tester.getSize(shutter), const Size.square(78));
      expect(
        find.descendant(of: shutter, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('mini-phone-camera-shutter-core')),
        ),
        const Size.square(62),
      );
      expect(tester.widget<IconButton>(shutter).onPressed, isNotNull);
      await tester.tap(shutter);
      await tester.pump();
      expect(captures, 1);
      expect(generations, 0);
      expect(tester.widget<IconButton>(shutter).onPressed, isNull);
      confirmation.complete();
      await tester.pump();
      expect(tester.widget<IconButton>(shutter).onPressed, isNotNull);
      expect(camera.result, isNull);
      expect(camera.phase, MiniPhoneCameraPhase.compose);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'thumbnail controls have no gallery icons or fabricated album image',
    (tester) async {
      await tester.pumpWidget(app());
      final template = find.byKey(
        const ValueKey('mini-phone-camera-templates'),
      );
      final album = find.byKey(const ValueKey('mini-phone-camera-album'));
      final thumbnailImage = find.byKey(
        const ValueKey('mini-phone-camera-thumbnail-image'),
      );
      expect(tester.getSize(thumbnailImage.first), const Size.square(52));
      expect(tester.getSize(thumbnailImage.last), const Size.square(52));
      expect(
        tester.getCenter(template).dx,
        lessThan(tester.getCenter(album).dx),
      );
      expect(find.text('Photos'), findsOneWidget);
      expect(
        find.descendant(of: album, matching: find.byType(Image)),
        findsNothing,
      );
      expect(
        find.descendant(of: album, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        tester.widget<MiniPhoneCameraThumbnail>(template).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(
        app(albumThumbnailUrl: 'https://camera.test/actual-thumbnail.webp'),
      );
      expect(
        tester
            .widget<GenesisStaticNetworkImage>(
              find.descendant(
                of: album,
                matching: find.byType(GenesisStaticNetworkImage),
              ),
            )
            .imageUrl,
        'https://camera.test/actual-thumbnail.webp',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('capture controls sit above the bottom with aligned thumbnails', (
    tester,
  ) async {
    await size(tester, const Size(390, 844));
    await tester.pumpWidget(app());
    final shutter = find.byKey(const ValueKey('mini-phone-camera-shutter'));
    final template = find.descendant(
      of: find.byKey(const ValueKey('mini-phone-camera-templates')),
      matching: find.byKey(const ValueKey('mini-phone-camera-thumbnail-image')),
    );
    final album = find.descendant(
      of: find.byKey(const ValueKey('mini-phone-camera-album')),
      matching: find.byKey(const ValueKey('mini-phone-camera-thumbnail-image')),
    );
    expect(tester.getCenter(shutter).dy, tester.getCenter(template).dy);
    expect(tester.getCenter(shutter).dy, tester.getCenter(album).dy);
    expect(tester.getRect(shutter).bottom, lessThanOrEqualTo(820));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'frame keeps standard cover ratio even with a different source ratio',
    (tester) async {
      await size(tester, const Size(390, 844));
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.grey, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(300, 400));
      picture.dispose();
      debugGenesisStaticNetworkImageCompleter = (_) =>
          OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: image!.clone())),
          );
      addTearDown(() {
        debugGenesisStaticNetworkImageCompleter = null;
        PaintingBinding.instance.imageCache.clear();
        image!.dispose();
      });
      await tester.pumpWidget(
        app(coverImageUrl: 'https://example.test/portrait.jpg'),
      );
      await tester.pumpAndSettle();
      final frame = find.byKey(const ValueKey('mini-phone-camera-viewfinder'));
      expect(tester.getSize(frame).aspectRatio, closeTo(2 / 3, .001));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(tester.getSize(frame).aspectRatio, closeTo(2 / 3, .001));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cast wraps inside default frame with in-frame status and no location fields',
    (tester) async {
      await size(tester, const Size(390, 844));
      final people = List.generate(
        8,
        (index) => PhonePerson('p$index', 'Person $index', ''),
      );
      await tester.pumpWidget(
        app(
          people: people,
          coverImageUrl: 'https://example.test/world-cover.jpg',
        ),
      );
      final frame = find.byKey(const ValueKey('mini-phone-camera-viewfinder'));
      expect(tester.getSize(frame).aspectRatio, closeTo(2 / 3, .001));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('mini-phone-camera-status')))
            .top,
        greaterThan(tester.getRect(frame).top),
      );
      expect(find.text(_strings.castHint), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mini-phone-camera-all-people')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('mini-phone-camera-add-person')),
      );
      await tester.pump();
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('mini-phone-camera-guide-area')))
            .bottom,
        tester.getRect(frame).bottom,
      );
      final inputRect = tester.getRect(find.byType(TextField));
      expect(inputRect.left, greaterThan(tester.getRect(frame).left + 22));
      expect(inputRect.right, lessThan(tester.getRect(frame).right - 22));
      expect(inputRect.bottom, lessThan(tester.getRect(frame).bottom - 20));
      expect(find.text(_strings.povSelfie), findsNothing);
      expect(find.text(_strings.mirrorSelfie), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      for (final person in people) {
        camera.togglePerson(person);
      }
      await tester.pump();
      final portraits = find.byType(MiniPhoneCameraFocusedPerson);
      expect(portraits, findsNWidgets(8));
      final frameRect = tester.getRect(frame);
      final portraitRows = <int>{};
      for (var index = 0; index < 8; index++) {
        final rect = tester.getRect(portraits.at(index));
        expect(frameRect.contains(rect.topLeft), isTrue);
        expect(frameRect.contains(rect.bottomRight), isTrue);
        expect(
          find.descendant(
            of: portraits.at(index),
            matching: find.text(people[index].name),
          ),
          findsNothing,
        );
        portraitRows.add(rect.top.round());
      }
      expect(portraitRows.length, greaterThan(1));
      expect(find.text('8 selected'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(camera.result, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('legacy generation still requires an actual ready draft', (
    tester,
  ) async {
    var calls = 0;
    final output = Completer<MiniPhoneCameraResult>();
    await tester.pumpWidget(
      app(
        generate: (_, _) {
          calls++;
          return output.future;
        },
      ),
    );
    final shutter = find.byKey(const ValueKey('mini-phone-camera-shutter'));
    expect(tester.widget<IconButton>(shutter).onPressed, isNull);
    camera.togglePerson(_person);
    camera.setPrompt('A real selected scene');
    await tester.pump();
    expect(tester.widget<IconButton>(shutter).onPressed, isNotNull);
    await tester.tap(shutter);
    await tester.pump();
    expect(calls, 1);
    expect(camera.phase, MiniPhoneCameraPhase.generating);
    await tester.pumpWidget(const SizedBox());
    output.completeError(const MiniPhoneCameraCancelled());
    await tester.pump();
    expect(camera.result, isNull);
  });

  const screenshotDir = String.fromEnvironment('CAMERA_UI_SCREENSHOT_DIR');
  testWidgets('render Camera screenshots for visual inspection', (
    tester,
  ) async {
    late ui.Image coverFixture;
    await tester.runAsync(() async {
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      // A test-only cover lets the render check exercise the real blur layer.
      final bytes = await rootBundle.load(
        MiniPhoneCameraTemplate.values.first.assetPath,
      );
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      coverFixture = (await codec.getNextFrame()).image;
      codec.dispose();
    });
    debugGenesisStaticNetworkImageCompleter = (_) =>
        OneFrameImageStreamCompleter(
          Future.value(ImageInfo(image: coverFixture.clone())),
        );
    addTearDown(() {
      debugGenesisStaticNetworkImageCompleter = null;
      imageCache.clear();
      coverFixture.dispose();
    });
    const renderKey = ValueKey('camera-v3-render');
    Future<void> capture(String name) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(renderKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory(screenshotDir)..createSync(recursive: true);
        File(
          '${directory.path}/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    final header = SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.arrow_back_ios_new, size: 20),
            const SizedBox(width: 12),
            Text(
              'Camera',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
    await size(tester, const Size(390, 844));
    await tester.pumpWidget(
      RepaintBoundary(
        key: renderKey,
        child: app(
          header: header,
          coverImageUrl: 'https://example.test/render-cover.jpg',
          onCaptureRequested: () async {},
        ),
      ),
    );
    await capture('camera-v14-390x844');
    camera.togglePerson(_person);
    camera.setPrompt('An evening with friends.');
    await tester.pump();
    await capture('camera-v14-selected');
    final renderPeople = List.generate(
      6,
      (i) => PhonePerson('render-$i', 'Person ${i + 1}', ''),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: renderKey,
        child: app(
          header: header,
          people: renderPeople,
          coverImageUrl: 'https://example.test/render-cover.jpg',
          onCaptureRequested: () async {},
        ),
      ),
    );
    for (final person in renderPeople) {
      camera.togglePerson(person);
    }
    await tester.pump();
    await capture('camera-v14-multiple');

    await tester.tap(find.byKey(const ValueKey('mini-phone-camera-templates')));
    await capture('camera-v14-template-sheet');
    Navigator.of(
      tester.element(find.byType(MiniPhoneCameraTemplateChoice).first),
    ).pop();
    await tester.pumpAndSettle();
    await tester.binding.setSurfaceSize(const Size(350, 740));
    await tester.pumpWidget(
      RepaintBoundary(
        key: renderKey,
        child: app(
          header: header,
          coverImageUrl: 'https://example.test/render-cover.jpg',
          scale: 2,
          keyboardInset: 300,
          onCaptureRequested: () async {},
        ),
      ),
    );
    await tester.ensureVisible(find.byType(TextField));
    await capture('camera-v14-350x740-keyboard');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, skip: screenshotDir.isEmpty);
}
