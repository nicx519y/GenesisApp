import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_scene_plate_tokens.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/chat_photo.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_colors.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';

void main() {
  for (final deviceDpr in [1.0, 3.0]) {
    testWidgets('photo card uses DPR=2 CDN width tier on device DPR=$deviceDpr', (
      tester,
    ) async {
      tester.view.devicePixelRatio = deviceDpr;
      tester.view.physicalSize = Size(390 * deviceDpr, 600 * deviceDpr);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final requests = <String>[];
      final pending = Completer<ImageInfo>();
      debugGenesisStaticNetworkImageCompleter = (key) {
        requests.add(key.imageUrl);
        return _ControlledCompleter(pending.future);
      };
      addTearDown(() => debugGenesisStaticNetworkImageCompleter = null);
      await tester.pumpWidget(_photoHost());
      await tester.pump();
      const width = 390.0;
      final size = tester.getSize(find.byType(AspectRatio));
      expect(size.width, closeTo(width, .001));
      expect(size.height, closeTo(width * 1.5, .001));
      expect(
        requests.single,
        'https://cdn.worldo.ai/photo.png?x-oss-process=image/resize,w_1080/format,webp',
      );
      // Loading tiles cannot open a viewer using a null/default preview.
      await tester.tap(find.byType(AspectRatio));
      await tester.pump();
      expect(find.byType(GenesisImageViewerOverlay), findsNothing);
      pending.complete(ImageInfo(image: _frame(20, 30)));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'nearby photo widths share a CDN tier and cross-tier widths change URL',
    (tester) async {
      final providers = <GenesisStaticNetworkImageProvider>[];
      final pending = Completer<ImageInfo>();
      debugGenesisStaticNetworkImageCompleter = (key) {
        providers.add(key);
        return _ControlledCompleter(pending.future);
      };
      addTearDown(() => debugGenesisStaticNetworkImageCompleter = null);
      ImageProvider<Object>? previous;
      for (final entry in const [
        (160.0, 360),
        (170.0, 360),
        (200.0, 720),
        (320.0, 720),
        (400.0, 1080),
      ]) {
        await tester.pumpWidget(_photoHost(availableWidth: entry.$1));
        await tester.pump();
        expect(tester.getSize(find.byType(AspectRatio)).width, entry.$1);
        final provider = tester
            .widget<GenesisImageViewerSourceAnchor>(
              find.byType(GenesisImageViewerSourceAnchor),
            )
            .previewImageProvider;
        expect(
          (provider as GenesisStaticNetworkImageProvider).imageUrl,
          'https://cdn.worldo.ai/photo.png?x-oss-process=image/resize,w_${entry.$2}/format,webp',
        );
        if (previous != null) {
          final sameTier = entry.$1 == 170 || entry.$1 == 320;
          expect(provider == previous, sameTier);
        }
        previous = provider;
      }
      expect(providers.length, 3);
      pending.complete(ImageInfo(image: _frame(20, 30)));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      expect(tester.takeException(), isNull);
    },
  );

  for (final failFullImage in [false, true]) {
    testWidgets(
      'photo preview retains clicked frame through flight, cache eviction and full-image ${failFullImage ? 'failure' : 'load'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final thumbnail = Completer<ImageInfo>();
        final full = Completer<ImageInfo>();
        debugGenesisStaticNetworkImageCompleter = (key) => _ControlledCompleter(
          key.cacheWidth == null ? thumbnail.future : full.future,
        );
        addTearDown(() => debugGenesisStaticNetworkImageCompleter = null);
        await tester.pumpWidget(_photoHost());
        thumbnail.complete(ImageInfo(image: _frame(56, 84)));
        await tester.pump();
        await tester.pump();
        final sourceRect = tester.getRect(find.byType(AspectRatio));
        await tester.tap(find.byType(AspectRatio));
        await tester.pump();
        final flight = find.byKey(
          const ValueKey('genesis-image-viewer-opening-image'),
        );
        expect(tester.getRect(flight), sourceRect);
        final viewer = tester.widget<GenesisImageViewerOverlay>(
          find.byType(GenesisImageViewerOverlay),
        );
        final frame = viewer.source.previewImage.image;
        expect(
          tester
              .widget<RawImage>(
                find.descendant(of: flight, matching: find.byType(RawImage)),
              )
              .image,
          same(frame),
        );
        await tester.pump(const Duration(milliseconds: 160));
        final middle = tester.getRect(flight);
        expect(middle.width, closeTo(390, .001));
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await tester.pump(const Duration(milliseconds: 200));
        final preview = find.byKey(
          const ValueKey('genesis-image-viewer-preview-0'),
        );
        expect(
          tester
              .widget<RawImage>(
                find.descendant(of: preview, matching: find.byType(RawImage)),
              )
              .image,
          same(frame),
        );
        expect(find.byIcon(Icons.image_outlined), findsNothing);
        if (failFullImage) {
          full.completeError(StateError('controlled image failure'));
        } else {
          full.complete(ImageInfo(image: _frame(78, 117)));
        }
        await tester.pump();
        await tester.pump();
        expect(preview, failFullImage ? findsOneWidget : findsNothing);
        expect(find.byIcon(Icons.image_outlined), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('genesis-image-viewer-close')),
        );
        await tester.pump();
        expect(frame.debugDisposed, isFalse);
        await tester.pumpAndSettle();
        expect(frame.debugDisposed, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      },
    );
  }

  Widget describedPhoto(String description) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ChatImageMessage(
          message: ChatMessageVm(
            localId: 'photo',
            senderId: '',
            senderName: '',
            isMe: false,
            status: 'sent',
            senderType: 'image',
            text: '',
            imageUrl: 'https://example.com/image.png',
            photo: ChatPhoto(
              taskId: 'task',
              requestId: '',
              status: ChatPhotoStatus.succeeded,
              imageUrl: 'https://example.com/image.png',
              description: description,
            ),
          ),
          style: kLocationChatStyle,
        ),
      ),
    ),
  );

  testWidgets('photo description is a centered plate under the image', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(describedPhoto('A quiet shot'));
    await tester.pump();
    final caption = find.text('「A quiet shot」');
    final plate = find.byKey(const ValueKey<String>('chat-photo-description'));
    expect(caption, findsOneWidget);
    final text = tester.widget<Text>(caption);
    expect(text.textAlign, TextAlign.center);
    expect(text.style!.fontSize, 13);
    expect(text.style!.height, closeTo(18 / 13, .001));
    expect(text.style!.color, GenesisColors.darkTextPrimary);
    expect(text.style!.fontFamily, GenesisTypography.fontFamily);
    final decoration =
        tester.widget<DecoratedBox>(plate).decoration as BoxDecoration;
    expect(decoration.color, kChatNarratorBubbleColor);
    expect(decoration.borderRadius, BorderRadius.circular(8));
    final image = tester.getRect(find.byType(AspectRatio));
    final plateRect = tester.getRect(plate);
    expect(plateRect.top - image.bottom, 8);
    expect(plateRect.center.dx, closeTo(image.center.dx, .5));
    final textRect = tester.getRect(caption);
    expect(textRect.left - plateRect.left, 12);
    expect(textRect.top - plateRect.top, 6);

    // A long description wraps inside the plate; nothing is cut off.
    final long = List.filled(20, 'quiet').join(' ');
    await tester.pumpWidget(describedPhoto(long));
    await tester.pump();
    expect(tester.getSize(plate).width, lessThanOrEqualTo(282));
    expect(tester.getSize(plate).height, greaterThan(18 * 2));
    final longText = tester.widget<Text>(find.text('「$long」'));
    expect(longText.maxLines, isNull);
    expect(longText.overflow, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  for (final entry in const {
    '  “Already quoted”  ': '「Already quoted」',
    '「已有括號」': '「已有括號」',
    '"(Nested)"': '「Nested」',
    'Ends with (a note)': '「Ends with (a note)」',
    '(Starts) and (ends)': '「Starts) and (ends」',
    '""': null,
  }.entries) {
    testWidgets('photo description brackets: ${entry.key}', (tester) async {
      await tester.pumpWidget(describedPhoto(entry.key));
      await tester.pump();
      final plate = find.byKey(
        const ValueKey<String>('chat-photo-description'),
      );
      if (entry.value == null) {
        expect(plate, findsNothing);
      } else {
        expect(find.text(entry.value!), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
  }

  testWidgets(
    'photo states keep image geometry and only success opens viewer',
    (tester) async {
      Size? size;
      for (final status in ChatPhotoStatus.values) {
        final photo = ChatPhoto(
          taskId: 'task',
          requestId: '',
          status: status,
          imageUrl: status == ChatPhotoStatus.succeeded
              ? 'https://example.com/image.png'
              : '',
          description: 'Photo caption',
          failureCode: 'generation_failed',
          failureMessage: 'Localized failure',
        );
        final message = ChatMessageVm(
          localId: 'photo',
          senderId: '',
          senderName: '',
          isMe: false,
          status: 'sent',
          senderType: 'image',
          text: '',
          imageUrl: photo.imageUrl,
          photo: photo,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: ChatImageMessage(
                  message: message,
                  style: kLocationChatStyle,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final image = find.byType(AspectRatio);
        expect(image, findsOneWidget);
        size ??= tester.getSize(image);
        expect(tester.getSize(image), size);
        expect(size.aspectRatio, closeTo(2 / 3, .001));
        final interactive = find.descendant(
          of: image,
          matching: find.byWidgetPredicate(
            (w) => w is GestureDetector && w.onTap != null,
          ),
        );
        expect(
          interactive,
          status == ChatPhotoStatus.succeeded ? findsOneWidget : findsNothing,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text('「Photo caption」'),
          status == ChatPhotoStatus.succeeded ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Localized failure'),
          status == ChatPhotoStatus.failed ? findsOneWidget : findsNothing,
        );
        // Test HTTP returns a download error; task status remains succeeded.
        expect(message.photo!.status, status);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'only successful photo cards dispatch long press without opening',
    (tester) async {
      var presses = 0;
      for (final status in ChatPhotoStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: ChatImageMessage(
                  message: ChatMessageVm(
                    localId: 'photo-$status',
                    senderId: 'image',
                    senderName: '',
                    text: '',
                    isMe: false,
                    status: 'sent',
                    photo: ChatPhoto(
                      taskId: 'task',
                      requestId: '',
                      status: status,
                      imageUrl: status == ChatPhotoStatus.succeeded
                          ? 'assets/images/map_default/location_default.webp'
                          : '',
                    ),
                  ),
                  style: kLocationChatStyle,
                  onLongPressStart: (_) => presses++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = presses;
        await tester.longPress(find.byType(AspectRatio));
        await tester.pump();
        expect(presses - before, status == ChatPhotoStatus.succeeded ? 1 : 0);
        expect(find.byType(GenesisImageViewerOverlay), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

ui.Image _frame(int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.pink, BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  addTearDown(image.dispose);
  return image;
}

Widget _photoHost({double? availableWidth}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: SizedBox(
        width: availableWidth,
        child: ChatImageMessage(
          message: ChatMessageVm(
            localId: 'photo',
            senderId: '',
            senderName: '',
            isMe: false,
            status: 'sent',
            senderType: 'image',
            text: '',
            imageUrl: 'https://cdn.worldo.ai/photo.png',
            photo: const ChatPhoto(
              taskId: 'task',
              requestId: '',
              status: ChatPhotoStatus.succeeded,
              imageUrl: 'https://cdn.worldo.ai/photo.png',
            ),
          ),
          style: kLocationChatStyle,
        ),
      ),
    ),
  ),
);

class _ControlledCompleter extends ImageStreamCompleter {
  _ControlledCompleter(Future<ImageInfo> pending) {
    final handle = keepAlive();
    pending
        .then<void>(
          (info) => setImage(info.clone()),
          onError: (Object error, StackTrace stack) {
            reportError(exception: error, stack: stack, silent: true);
          },
        )
        .whenComplete(handle.dispose);
  }
}
