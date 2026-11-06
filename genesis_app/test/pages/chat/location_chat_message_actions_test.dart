import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/app/bootstrap/app_services_scope.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/common/genesis_image_viewer_overlay.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/genesis_api.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_scroll_coordinator.dart';
import 'package:genesis_flutter_android/ui/components/genesis_static_network_image.dart';

import '../../support/mini_phone_chat_backend.dart';
import '../../support/mini_phone_music_services.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final isPhoto in [false, true]) {
    testWidgets('location image report and tap viewer: photo=$isPhoto', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1200);
      addTearDown(tester.view.reset);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.pink, BlendMode.src);
      final picture = recorder.endRecording();
      final frame = picture.toImageSync(20, 30);
      picture.dispose();
      addTearDown(frame.dispose);
      debugGenesisStaticNetworkImageCompleter = (_) =>
          OneFrameImageStreamCompleter(
            Future.value(ImageInfo(image: frame.clone())),
          );
      addTearDown(() => debugGenesisStaticNetworkImageCompleter = null);
      final backend = PhoneBackend();
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final services = musicTestServices(
        GenesisApi(useMock: false, apiClient: backend.api.client),
      );
      debugDefaultTargetPlatformOverride = previousPlatform;
      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: MaterialApp(
            home: LocationChatPanel(
              worldId: 'w',
              locationId: 'loc',
              active: false,
              openingPreviewMessages: [_imageMessage(isPhoto)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = find.byType(ChatImageMessage);
      expect(image, findsOneWidget);
      final surface = isPhoto
          ? find.byType(AspectRatio)
          : find.byType(GenesisImageViewerSourceAnchor);
      expect(surface, findsOneWidget);
      await tester.longPress(surface);
      await tester.pump();
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Report'), findsOneWidget);
      expect(find.byType(GenesisImageViewerOverlay), findsNothing);
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('genesis-report-content-input')),
        'Image reason',
      );
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(backend.body(backend.calls('report/create').single), {
        'target_type': 'message',
        'target_id': '86123',
        'content': 'Image reason',
      });
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(surface);
      await tester.pumpAndSettle();
      expect(find.byType(GenesisImageViewerOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
  }

  for (final tick in [false, true]) {
    testWidgets('location text menu copies full content: tick=$tick', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LocationChatPanel(
            worldId: 'w',
            locationId: 'loc',
            active: false,
            openingPreviewMessages: [
              WorldChatroomMessage(
                globalMessageId: 86123,
                messageId: 123,
                locationMessageId: 3,
                conversationRoundId: '1',
                roundOrder: 0,
                locationId: 'loc',
                senderType: tick ? 'tick' : 'user',
                senderId: tick ? 'tick' : 'peer-user',
                senderName: '',
                content: tick ? '' : 'Text body',
                tickNo: tick ? 2 : 0,
                subTickNo: tick ? 1 : 0,
                createdAt: null,
                v2TickPayload: tick
                    ? const ChatroomV2TickPayload(
                        currentTime: '',
                        tickNo: 2,
                        subTickNo: 1,
                        globalText: 'The clock turns.',
                        storyEvents: [],
                        charactersMoved: [],
                        fallbackContent: '',
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(
        find.text(tick ? 'The clock turns.' : 'Text body'),
      );
      await tester.pump();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(copied, tick ? 'Tick 2-1\nGlobal\nThe clock turns.' : 'Text body');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('location image without report ID has no copy or report menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocationChatPanel(
          worldId: 'w',
          locationId: 'loc',
          active: false,
          openingPreviewMessages: [_imageMessage(false, globalId: 0)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPressAt(
      tester.getTopLeft(find.byType(ChatImageMessage)) + const Offset(30, 30),
    );
    await tester.pump();
    expect(find.text('Copy'), findsNothing);
    expect(find.text('Report'), findsNothing);

    // Check the scene policy as well as the photo widget's gesture filtering.
    final list = tester.widget<LocationChatAnchoredMessageList>(
      find.byType(LocationChatAnchoredMessageList),
    );
    for (final status in [ChatPhotoStatus.generating, ChatPhotoStatus.failed]) {
      final message = ChatMessageVm(
        localId: 'photo-$status',
        globalMessageId: 86123,
        senderId: 'image',
        senderName: '',
        text: '',
        isMe: false,
        status: 'sent',
        photo: ChatPhoto(taskId: 'task', requestId: '', status: status),
      );
      expect(locationChatMessageCanReportForTesting(message), isFalse);
      list.onMessageLongPressStart!(
        tester.element(find.byType(ChatImageMessage)),
        message,
        const LongPressStartDetails(globalPosition: Offset(200, 300)),
      );
      await tester.pump();
      expect(find.text('Copy'), findsNothing);
      expect(find.text('Report'), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

WorldChatroomMessage _imageMessage(bool photo, {int globalId = 86123}) =>
    WorldChatroomMessage(
      globalMessageId: globalId,
      messageId: 123,
      locationMessageId: 3,
      conversationRoundId: '1',
      roundOrder: 0,
      locationId: 'loc',
      senderType: 'narrator',
      businessType: photo ? 'live_photo' : 'narrator',
      senderId: 'image',
      senderName: '',
      content: photo ? '' : 'https://cdn.worldo.ai/plain_200x300.png',
      messageType: 'image',
      createdAt: null,
      rawPayload: photo
          ? {
              'photo': {
                'task_id': 'task',
                'client_request_id': null,
                'status': 'succeeded',
                'image': {
                  'asset_id': 1,
                  'chat_global_message_id': globalId,
                  'image_url': 'https://cdn.worldo.ai/photo.png',
                  'description': 'Photo description',
                },
                'failure': null,
              },
            }
          : {},
    );
