import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_camera_models.dart';
import 'package:genesis_flutter_android/network/models/photo_task.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_style_sheet.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_tasks.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_widgets.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_cast.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/ui/theme/genesis_theme.dart';
import '../../support/mini_phone_chat_backend.dart';

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
  candid: 'Candid',
  livePhoto: 'Live photo',
  povSelfiePrompt: 'Selfie prompt for only the selected people.',
  mirrorSelfiePrompt: 'Mirror prompt for only the selected people.',
  byFriendPrompt: 'Friend prompt for only the selected people.',
  candidPrompt: 'Candid prompt for only the selected people.',
  livePhotoPrompt: 'Live still photo prompt for only the selected people.',
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
    double bottomSafeArea = 0,
    double? imageDevicePixelRatio,
    TargetPlatform? platform,
    VoidCallback? onOpenAlbum,
    Future<void> Function()? onCaptureRequested,
    MiniPhoneCameraTasks? tasks,
    String? albumThumbnailUrl,
    List<PhonePerson> people = const [_person],
    Widget? header,
    String coverImageUrl = '',
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: GenesisTheme.dark().copyWith(platform: platform),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        devicePixelRatio: imageDevicePixelRatio,
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
        viewPadding: MediaQuery.viewPaddingOf(
          context,
        ).copyWith(bottom: bottomSafeArea),
        padding: MediaQuery.paddingOf(context).copyWith(
          bottom: (bottomSafeArea - keyboardInset).clamp(0.0, double.infinity),
        ),
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
        tasks: tasks,
        albumThumbnailUrl: albumThumbnailUrl,
      ),
    ),
  );

  Future<void> size(WidgetTester tester, Size value) async {
    await tester.binding.setSurfaceSize(value);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  MiniPhoneCameraTasks realTasks(
    PhoneBackend backend, {
    String styleImage = '',
  }) {
    final tasks =
        MiniPhoneCameraTasks(
            api: backend.api,
            worldId: 'w',
            requests: camera.requests,
            pending: {},
            saveJournal: () async => true,
            onChanged: () {},
            onSuccess: () {},
          )
          ..options = PhoneCameraOptions.fromJson({
            'world_id': 'w',
            'price_cent': 3000,
            'free_status': 'available',
            'styles': [
              {
                'name': 'Selfie',
                'label': 'selfie',
                'demo_image_url': styleImage,
              },
              {'name': 'Mirror', 'label': 'mirror', 'demo_image_url': ''},
            ],
          });
    tasks.selectStyle('selfie');
    addTearDown(tasks.dispose);
    addTearDown(backend.revision.dispose);
    return tasks;
  }

  for (final scenario in [
    (viewport: const Size(390, 844), scale: 1.0),
    (viewport: const Size(350, 740), scale: 1.0),
    (viewport: const Size(350, 740), scale: 2.0),
  ]) {
    testWidgets('delayed camera options preserve geometry at $scenario', (
      tester,
    ) async {
      await size(tester, scenario.viewport);
      final tasks = realTasks(PhoneBackend());
      tasks.options = null;
      await tester.pumpWidget(
        app(tasks: tasks, scale: scenario.scale, bottomSafeArea: 34),
      );
      final frame = find.byKey(const ValueKey('mini-phone-camera-viewfinder'));
      final shutter = find.byKey(const ValueKey('mini-phone-camera-shutter'));
      final participants = find.byKey(
        const ValueKey('camera-participants-region'),
      );
      final initialFrame = tester.getRect(frame);
      final initialShutter = tester.getRect(shutter);
      final initialParticipants = tester.getRect(participants);
      expect(find.textContaining('Gems'), findsNothing);
      expect(
        tester.getSemantics(find.byType(Scaffold)).toStringDeep(),
        isNot(contains('Your first photo')),
      );

      // Exercise first load, refreshed eligibility/price, and a style name
      // that wraps in the same footer which determines the photo's size.
      for (final freeStatus in ['available', 'used', 'available']) {
        tasks.options = PhoneCameraOptions.fromJson({
          'world_id': 'w',
          'price_cent': freeStatus == 'used' ? 12500 : 3000,
          'free_status': freeStatus,
          'styles': [
            {
              'name': freeStatus == 'used'
                  ? 'A long camera style name'
                  : 'Selfie',
              'label': 'selfie',
              'demo_image_url': '',
            },
          ],
        });
        tasks.selectStyle('selfie');
        await tester.pump();
        expect(tester.getRect(frame), initialFrame);
        expect(tester.getRect(shutter), initialShutter);
        expect(tester.getRect(participants), initialParticipants);
        expect(find.textContaining('Gems'), findsNothing);
        expect(
          tester.getSemantics(find.byType(Scaffold)).toStringDeep(),
          freeStatus == 'available'
              ? contains('Your first photo')
              : isNot(contains('Your first photo')),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('server style selection paints before the sheet closes', (
    tester,
  ) async {
    await size(tester, const Size(390, 844));
    final tasks = realTasks(PhoneBackend());
    await tester.pumpWidget(app(tasks: tasks));
    await tester.tap(find.byKey(const ValueKey('mini-phone-camera-templates')));
    await tester.pumpAndSettle();
    bool selected(String name) => tester
        .widgetList<Semantics>(
          find.ancestor(of: find.text(name), matching: find.byType(Semantics)),
        )
        .any((widget) => widget.properties.selected == true);
    expect(selected('Selfie'), isTrue);
    await tester.tap(find.text('Mirror'));
    await tester.pump();
    expect(find.byType(PhoneCameraStyleSheet), findsOneWidget);
    expect(selected('Mirror'), isTrue);
    expect(selected('Selfie'), isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PhoneCameraStyleSheet), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneCameraStyleSheet), findsNothing);
    expect(tasks.selectedStyle, 'mirror');
    await tester.pumpWidget(const SizedBox());
  });

  for (final dpr in [1.0, 3.0]) {
    testWidgets('all camera images request CDN resizing at DPR 2 on DPR $dpr', (
      tester,
    ) async {
      await size(tester, const Size(390, 844));
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.grey, BlendMode.src);
      final picture = recorder.endRecording();
      final image = (await tester.runAsync(() => picture.toImage(40, 60)))!;
      picture.dispose();
      debugGenesisStaticNetworkImageCompleter = (_) =>
          OneFrameImageStreamCompleter(
            SynchronousFuture(ImageInfo(image: image.clone())),
          );
      addTearDown(() {
        debugGenesisStaticNetworkImageCompleter = null;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        image.dispose();
      });
      const styleImage =
          'https://cdn.example/style.png?token=keep&x-oss-process=image/resize,w_999';
      final tasks = realTasks(PhoneBackend(), styleImage: styleImage);
      const person = PhonePerson(
        'person',
        'Person',
        'https://cdn.example/avatar.png',
      );
      await tester.pumpWidget(
        app(
          tasks: tasks,
          people: [person],
          imageDevicePixelRatio: dpr,
          coverImageUrl: 'https://cdn.example/cover.png',
          albumThumbnailUrl: 'https://cdn.example/album.png',
        ),
      );
      camera.togglePerson(person);
      await tester.pumpAndSettle();
      Iterable<GenesisStaticNetworkImage> images(String path) => tester
          .widgetList<GenesisStaticNetworkImage>(
            find.byType(GenesisStaticNetworkImage),
          )
          .where((image) => Uri.parse(image.imageUrl).path == '/$path.png');
      void expectResize(String path, String process) {
        expect(images(path), isNotEmpty);
        for (final image in images(path)) {
          expect(
            Uri.parse(image.imageUrl).queryParameters['x-oss-process'],
            'image/resize,$process/format,webp',
          );
        }
      }

      expectResize('avatar', 'w_96');
      expect(images('avatar'), hasLength(2));
      expectResize('style', 'w_64');
      expectResize('album', 'w_96');
      expectResize('cover', 'w_720');
      expect(
        Uri.parse(images('style').single.imageUrl).queryParameters['token'],
        'keep',
      );

      tasks.accept(
        const PhotoTask(
          taskId: 'photo',
          requestId: 'photo',
          status: PhotoTaskStatus.succeeded,
          imageUrl: 'https://cdn.example/result.png',
          assetId: 1,
        ),
      );
      await tester.pumpAndSettle();
      expectResize('result', 'w_96');
      expect(tasks.latestSuccess!.imageUrl, 'https://cdn.example/result.png');

      await tester.tap(
        find.byKey(const ValueKey('mini-phone-camera-templates')),
      );
      await tester.pumpAndSettle();
      final sheetImages = tester
          .widgetList<GenesisStaticNetworkImage>(
            find.descendant(
              of: find.byType(PhoneCameraStyleSheet),
              matching: find.byType(GenesisStaticNetworkImage),
            ),
          )
          .where((image) => image.imageUrl.contains('/style.png'));
      expect(sheetImages, hasLength(1));
      final sheetUrl = Uri.parse(sheetImages.single.imageUrl);
      expect(
        sheetUrl.queryParameters['x-oss-process'],
        'image/resize,w_248/format,webp',
      );
      expect(sheetUrl.queryParameters['token'], 'keep');
      expect(tasks.style!.demoImageUrl, styleImage);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'album loading follows submission and all parallel task results',
    (tester) async {
      await size(tester, const Size(390, 844));
      final backend = PhoneBackend();
      final tasks = realTasks(backend);
      final receipt = Completer<Object?>();
      backend.respond = (r) =>
          r.uri.path.endsWith('/photo/create') ? receipt.future : null;
      await tester.pumpWidget(
        app(
          tasks: tasks,
          onOpenAlbum: () {},
          onCaptureRequested: () => tasks.submit(
            PhoneCameraRequest(
              requestId: 'r',
              worldId: 'w',
              characterIds: ['person-a'],
              aspectRatio: '2:3',
              style: 'selfie',
            ),
          ),
        ),
      );
      final album = find.byKey(const ValueKey('mini-phone-camera-album'));
      final spinner = find.descendant(
        of: album,
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinner, findsNothing);
      camera.togglePerson(_person);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mini-phone-camera-shutter')));
      await tester.pump();
      expect(spinner, findsOneWidget);
      receipt.complete(
        ok({
          'world_id': 'w',
          'source': 'camera',
          'photo': {
            'task_id': 'task',
            'client_request_id': 'r',
            'status': 'generating',
          },
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(spinner, findsOneWidget);
      tasks.accept(
        const PhotoTask(
          taskId: 'another',
          requestId: 'another',
          status: PhotoTaskStatus.generating,
        ),
      );
      tasks.accept(
        const PhotoTask(
          taskId: 'task',
          requestId: 'r',
          status: PhotoTaskStatus.failed,
        ),
      );
      await tester.pump();
      expect(spinner, findsOneWidget);
      tasks.accept(
        const PhotoTask(
          taskId: 'another',
          requestId: 'another',
          status: PhotoTaskStatus.succeeded,
          assetId: 99,
        ),
      );
      await tester.pump();
      expect(spinner, findsNothing);
      expect(
        find.descendant(of: album, matching: find.byIcon(Icons.circle)),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

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
    'template selection preserves the description and survives editing',
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
      expect(camera.prompt, isEmpty);
      expect(camera.selectedTemplate, MiniPhoneCameraTemplate.povSelfie);
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
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(MiniPhoneCameraTemplateChoice).at(1));
      await tester.pumpAndSettle();
      expect(camera.prompt, 'Edited template');
      expect(camera.selectedTemplate, MiniPhoneCameraTemplate.mirrorSelfie);
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
    'templates scroll horizontally and selecting the last preserves prompt',
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
      await tester.drag(scroll, const Offset(-550, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MiniPhoneCameraTemplateChoice).last);
      await tester.pumpAndSettle();
      expect(camera.prompt, isEmpty);
      expect(camera.selectedTemplate, MiniPhoneCameraTemplate.livePhoto);
      expect(find.byType(BottomSheet), findsNothing);
      expect(camera.selectedPeople, isEmpty);
      expect(camera.result, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final viewport in [const Size(390, 844), const Size(350, 740)]) {
    testWidgets(
      'only the focused prompt moves above the keyboard at $viewport',
      (tester) async {
        await size(tester, viewport);
        final scale = viewport.width < 390 ? 2.0 : 1.0;
        await tester.pumpWidget(app(scale: scale));
        final field = find.byType(TextField);
        final closeKeyboard = find.byKey(
          const ValueKey('mini-phone-camera-hide-keyboard'),
        );
        expect(closeKeyboard, findsNothing);
        final frame = find.byKey(
          const ValueKey('mini-phone-camera-viewfinder'),
        );
        final frameRect = tester.getRect(frame);
        final promptBottom = tester.getRect(field).bottom;
        final status = find.byKey(const ValueKey('mini-phone-camera-status'));
        final statusRect = tester.getRect(status);
        await tester.tap(field);
        await tester.pump();
        for (final inset in [220.0, 300.0, 360.0]) {
          await tester.pumpWidget(app(scale: scale, keyboardInset: inset));
          await tester.pumpAndSettle();
          expect(
            tester.getRect(field).bottom,
            lessThanOrEqualTo(viewport.height - inset - 8),
          );
          expect(closeKeyboard, findsNothing);
          expect(tester.getRect(frame), frameRect);
          expect(tester.getRect(status), statusRect);
          expect(field.hitTestable(), findsOneWidget);
        }
        await tester.enterText(
          field,
          'A longer scene description\nwith a second line\nand a third line',
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(field).bottom,
          lessThanOrEqualTo(viewport.height - 360 - 8),
        );
        expect(tester.getRect(field).top, greaterThanOrEqualTo(56));
        expect(tester.getRect(frame), frameRect);
        expect(camera.prompt, contains('third line'));
        expect(
          tester.widget<TextField>(field).textInputAction,
          TextInputAction.newline,
        );
        await tester.testTextInput.receiveAction(TextInputAction.newline);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        final draft = camera.prompt;
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
        expect(camera.prompt, draft);
        expect(closeKeyboard, findsNothing);
        await tester.pumpWidget(app(scale: scale));
        await tester.pumpAndSettle();
        expect(tester.getRect(frame), frameRect);
        expect(tester.getRect(field).bottom, closeTo(promptBottom, .01));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final bottomSafeArea in [24.0, 34.0]) {
    testWidgets(
      'photo stays fixed through keyboard safe-area changes at $bottomSafeArea',
      (tester) async {
        await size(tester, const Size(390, 844));
        await tester.pumpWidget(app(bottomSafeArea: bottomSafeArea));
        final frame = find.byKey(
          const ValueKey('mini-phone-camera-viewfinder'),
        );
        final field = find.byType(TextField);
        for (final ratio in CameraPhotoRatio.values) {
          camera.setPhotoRatio(ratio);
          await tester.pumpAndSettle();
          final originalFrame = tester.getRect(frame);
          await tester.tap(field);
          await tester.pump();
          expect(tester.getRect(frame), originalFrame);
          for (final inset in [1.0, 80.0, 220.0, 300.0, 360.0, 80.0, 0.0]) {
            await tester.pumpWidget(
              app(bottomSafeArea: bottomSafeArea, keyboardInset: inset),
            );
            expect(tester.getRect(frame), originalFrame);
            await tester.pumpAndSettle();
            expect(tester.getRect(frame), originalFrame);
            if (inset > 0) {
              expect(
                tester.getRect(field).bottom,
                lessThanOrEqualTo(844 - inset - 8),
              );
            }
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          expect(tester.getRect(frame), originalFrame);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform scrolling the prompt keeps focus and keyboard open',
      (tester) async {
        await size(tester, const Size(390, 844));
        await tester.pumpWidget(app(platform: platform));
        final field = find.byType(TextField);
        final draft = List.generate(
          20,
          (index) => 'Scene description line $index',
        ).join('\n');
        await tester.enterText(field, draft);
        await tester.pumpWidget(app(platform: platform, keyboardInset: 300));
        await tester.pumpAndSettle();
        final frame = find.byKey(
          const ValueKey('mini-phone-camera-viewfinder'),
        );
        final frameRect = tester.getRect(frame);
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: field, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.maxScrollExtent, greaterThan(0));
        final originalOffset = position.pixels;
        await tester.drag(field, const Offset(0, 48));
        await tester.pumpAndSettle();
        expect(position.pixels, lessThan(originalOffset));
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        final scrolledOffset = position.pixels;
        await tester.drag(field, const Offset(0, -48));
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(scrolledOffset));
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(camera.prompt, draft);
        expect(tester.getRect(frame), frameRect);
        await tester.tapAt(const Offset(20, 70));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
        expect(camera.prompt, draft);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

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
      expect(tester.getSize(thumbnailImage.first), const Size(36, 52));
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
        'https://camera.test/actual-thumbnail.webp?x-oss-process=image/resize,w_96/format,webp',
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
      expect(portraits, findsNWidgets(4));
      final frameRect = tester.getRect(frame);
      final portraitRows = <int>{};
      for (var index = 0; index < 4; index++) {
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
      expect(find.text('4 selected'), findsOneWidget);
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
        'assets/mini_phone/camera-templates/selfie.webp',
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
