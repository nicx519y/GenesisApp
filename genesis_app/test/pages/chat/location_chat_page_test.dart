import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/routers/app_router.dart';

void main() {
  const localAvatar = 'https://example.test/local-avatar.webp';
  const fallbackAvatar = 'https://example.test/fallback-avatar.webp';
  const entityAvatar = 'https://example.test/entity-avatar.webp';

  test('location chat panel hides the inactive more button by default', () {
    const panel = LocationChatPanel(worldId: 'world-1', locationId: 'loc-1');

    expect(panel.showMoreButton, isFalse);
  });

  test('selected model code reads the user info sibling field', () {
    expect(
      selectedModelCodeFromUserInfo({
        'selected_model_code': 'cc_4_5',
        'user': {'selected_model_code': 'legacy_model'},
      }),
      'cc_4_5',
    );
  });

  test('selected model code accepts a nested compatibility fallback', () {
    expect(
      selectedModelCodeFromUserInfo({
        'user': {'selected_model_code': 'legacy_model'},
      }),
      'legacy_model',
    );
  });

  test('location chat model entry is server driven and world scoped', () {
    final source = File(
      'lib/pages/chat/location_chat_page.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("modelLabel: 'CC4.5'")));
    expect(source, contains('sessionStore.readUserInfo()'));
    expect(source, isNot(contains('api.v1.user.info()')));
    expect(source, contains('rootNavigator: true'));
    expect(source, contains('pushNamed<String>('));
    expect(source, contains("arguments: {'world_id': widget.worldId}"));
  });

  testWidgets('location chat model entry opens the current world model list', (
    tester,
  ) async {
    Object? routeArguments;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name != RouteNames.memoryModel) return null;
          routeArguments = settings.arguments;
          return MaterialPageRoute<String>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Model selection list')),
          );
        },
        home: Navigator(
          pages: const [
            MaterialPage<void>(
              child: LocationChatPanel(
                worldId: 'world-current',
                locationId: 'location-current',
                active: false,
              ),
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('memory-model-entry')));
    await tester.pumpAndSettle();

    expect(find.text('Model selection list'), findsOneWidget);
    expect(routeArguments, {'world_id': 'world-current'});
  });

  test('location chat background falls back to bundled default when empty', () {
    expect(
      resolveLocationChatBackgroundUrlForTesting(imageUrl: ''),
      'assets/images/map_default/location_default.webp',
    );
  });

  test('location chat background maps predata default CDN image to asset', () {
    expect(
      resolveLocationChatBackgroundUrlForTesting(
        imageUrl: 'https://cdn-001.worldo.ai/predata/location_default.webp',
      ),
      'assets/images/map_default/location_default.webp',
    );
  });

  test(
    'self message avatar falls back to local avatar before existing avatar',
    () {
      expect(
        resolveLocationChatMessageAvatarForTesting(
          isMine: true,
          localSelfAvatar: localAvatar,
          fallback: fallbackAvatar,
        ),
        localAvatar,
      );
    },
  );

  test('self message avatar keeps existing avatar when source is empty', () {
    expect(
      resolveLocationChatMessageAvatarForTesting(
        isMine: true,
        fallback: fallbackAvatar,
      ),
      fallbackAvatar,
    );
  });

  test('source avatar wins over local and existing avatar fallbacks', () {
    expect(
      resolveLocationChatMessageAvatarForTesting(
        entityUserAvatar: entityAvatar,
        isMine: true,
        localSelfAvatar: localAvatar,
        fallback: fallbackAvatar,
      ),
      entityAvatar,
    );
  });

  test('name list uses AI role names instead of real user names', () {
    const state = WorldChatroomState(
      entitiesByLocation: {
        'loc-1': [
          WorldChatroomEntity(
            id: 'ai-1',
            name: 'Alice',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-1',
            isAi: true,
          ),
          WorldChatroomEntity(
            id: 'user-1',
            name: 'Real User Role',
            avatarUrl: '',
            type: WorldChatroomEntityType.player,
            locationId: 'loc-1',
          ),
          WorldChatroomEntity(
            id: 'ai-2',
            name: 'Guide',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-1',
            isAi: true,
          ),
        ],
        'loc-alias': [
          WorldChatroomEntity(
            id: 'ai-1',
            name: 'Alice',
            avatarUrl: '',
            type: WorldChatroomEntityType.character,
            locationId: 'loc-alias',
            isAi: true,
          ),
        ],
      },
    );

    expect(
      resolveLocationChatAiRoleNamesForTesting(state, ['loc-1', 'loc-alias']),
      ['Alice', 'Guide'],
    );
  });

  test('message report target prefers global message id', () {
    expect(
      locationChatMessageReportTargetIdForTesting(
        ChatMessageVm(
          localId: 'local-fallback',
          clientMsgId: 'client-fallback',
          globalMessageId: 90001,
          messageId: 1001,
          locationMessageId: 101,
          senderId: 'u_peer',
          senderName: 'Peer',
          text: 'hello',
          isMe: false,
          status: 'sent',
        ),
      ),
      '90001',
    );
  });

  test('message report target is empty when global message id is absent', () {
    expect(
      locationChatMessageReportTargetIdForTesting(
        ChatMessageVm(
          localId: 'local-fallback',
          clientMsgId: 'client-fallback',
          messageId: 1001,
          locationMessageId: 101,
          senderId: 'u_peer',
          senderName: 'Peer',
          text: 'hello',
          isMe: false,
          status: 'sent',
        ),
      ),
      '',
    );

    expect(
      locationChatMessageReportTargetIdForTesting(
        ChatMessageVm(
          localId: 'local-fallback',
          clientMsgId: 'client-fallback',
          senderId: 'u_peer',
          senderName: 'Peer',
          text: 'pending',
          isMe: false,
          status: 'sending',
        ),
      ),
      '',
    );
  });

  test('message local id uses location message id as queue key', () {
    final first = _message(
      messageId: 1080,
      locationMessageId: 80,
      senderType: 'narrator',
      senderId: 'nar',
      content: 'narrator 80',
    );
    final second = _message(
      messageId: 1083,
      locationMessageId: 83,
      senderType: 'narrator',
      senderId: 'nar',
      content: 'narrator 83',
    );

    expect(locationChatMessageLocalIdForTesting(first), 'location-loc-1-80');
    expect(locationChatMessageLocalIdForTesting(second), 'location-loc-1-83');
    expect(
      locationChatMessageLocalIdForTesting(first),
      isNot(locationChatMessageLocalIdForTesting(second)),
    );
  });

  test('local hydrate ignores stale disposed provided chatroom services', () {
    final panelSource = File(
      'lib/pages/chat/location_chat_page.dart',
    ).readAsStringSync();
    final serviceSource = File(
      'lib/network/chatroom/world_chatroom_service.dart',
    ).readAsStringSync();

    expect(serviceSource, contains('bool get isDisposed => _disposed;'));
    expect(panelSource, contains('int _serviceGeneration = 0;'));
    expect(
      panelSource,
      contains('_startHydrateLocalMessages(provided, services);'),
    );
    expect(
      panelSource,
      isNot(contains('unawaited(_hydrateLocalMessages(provided, services))')),
    );
    expect(panelSource, contains('identical(_service, service)'));
    expect(panelSource, contains('!service.isDisposed'));
    expect(panelSource, contains('on ChatroomProtocolException catch (error)'));
    expect(
      panelSource,
      contains('.catchError((Object error, StackTrace stackTrace)'),
    );
    expect(
      panelSource,
      contains('Error.throwWithStackTrace(error, stackTrace)'),
    );
    expect(panelSource, contains('hydrateLocalStaleService'));
    expect(panelSource, contains('_serviceGeneration++;'));
  });

  test(
    'visible location chat messages keep latest continuous location id suffix',
    () {
      final visible = visibleLocationChatMessagesForTesting([
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
        _message(
          messageId: 30,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick before gap',
        ),
        _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
        _message(
          messageId: 45,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick in visible range',
        ),
        _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
      ]);

      expect(visible.map((message) => message.messageId), [40, 45, 50]);
      expect(
        locationChatMessageGapFillCursorForTesting([
          _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
          _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
          _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
        ]),
        4,
      );
    },
  );

  test(
    'visible location chat messages render all continuous location messages',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'one'),
        _message(
          messageId: 15,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'tick',
        ),
        _message(messageId: 20, locationMessageId: 2, content: 'two'),
        _message(messageId: 30, locationMessageId: 3, content: 'three'),
      ];

      expect(
        visibleLocationChatMessagesForTesting(
          source,
        ).map((message) => message.messageId),
        [10, 15, 20, 30],
      );
      expect(locationChatMessageGapFillCursorForTesting(source), 0);
    },
  );

  test(
    'visible location chat messages include leading tick in visible window',
    () {
      final source = [
        _message(
          messageId: 0,
          locationMessageId: 0,
          senderType: 'tick',
          content: 'Day 1, 20:00',
        ),
        _message(messageId: 55, locationMessageId: 55, content: 'turn 19'),
        _message(messageId: 56, locationMessageId: 56, content: 'narrator'),
      ];

      expect(
        visibleLocationChatMessagesForTesting(
          source,
        ).map((message) => message.content),
        ['Day 1, 20:00', 'turn 19', 'narrator'],
      );
    },
  );

  test('visible location chat messages keep leading cursorless records', () {
    final source = [
      _message(
        messageId: 1,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'Day 1, 20:00',
      ),
      _message(
        messageId: 5,
        locationMessageId: 0,
        senderType: 'character',
        content: 'dirty record without location id',
      ),
      _message(messageId: 45, locationMessageId: 12, content: 'first valid'),
      _message(messageId: 46, locationMessageId: 13, content: 'second valid'),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      [
        'Day 1, 20:00',
        'dirty record without location id',
        'first valid',
        'second valid',
      ],
    );
  });

  test('visible location chat messages collapse consecutive ticks', () {
    final source = [
      _message(messageId: 1, locationMessageId: 1, content: 'one'),
      _message(
        messageId: 2,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'older tick',
      ),
      _message(
        messageId: 3,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'newer tick',
      ),
      _message(messageId: 4, locationMessageId: 2, content: 'two'),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      ['one', 'newer tick', 'two'],
    );
  });

  test('visible location chat messages collapse consecutive leading ticks', () {
    final source = [
      _message(
        messageId: 1,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'older leading tick',
      ),
      _message(
        messageId: 2,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'newer leading tick',
      ),
      _message(messageId: 3, locationMessageId: 1, content: 'one'),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      ['newer leading tick', 'one'],
    );
  });

  test('visible location chat messages collapse tick-only queues', () {
    final source = [
      _message(
        messageId: 1,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'Tick 1',
      ),
      _message(
        messageId: 2,
        locationMessageId: 0,
        senderType: 'tick',
        content: 'Tick 2',
      ),
    ];

    expect(
      visibleLocationChatMessagesForTesting(
        source,
      ).map((message) => message.content),
      ['Tick 2'],
    );
  });

  test(
    'visible location chat messages keep rendered old data before new gaps',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
        _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
        _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
      ];

      expect(
        visibleLocationChatMessagesWithRenderedIdsForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
        ).map((message) => message.messageId),
        [10, 20],
      );
    },
  );

  test('visible location chat messages fill holes inside rendered span', () {
    final source = [
      _message(messageId: 193, locationMessageId: 160, content: 'hi'),
      _message(
        messageId: 194,
        locationMessageId: 161,
        senderType: 'narrator',
        content: 'narrator inside rendered span',
      ),
      _message(
        messageId: 195,
        locationMessageId: 162,
        senderType: 'character',
        content: 'character',
      ),
      _message(messageId: 197, locationMessageId: 164, content: 'new gap'),
    ];

    expect(
      visibleLocationChatMessagesWithRenderedIdsForTesting(
        source,
        renderedLocationMessageIds: const {160, 162},
      ).map((message) => message.locationMessageId),
      [160, 161, 162],
    );
  });

  test('visible location chat messages release unrecoverable gaps', () {
    final source = [
      _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
      _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
      _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
      _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
    ];

    expect(
      visibleLocationChatMessagesWithRenderedIdsForTesting(
        source,
        renderedLocationMessageIds: const {1, 2},
        releasedGapKeys: const {'loc-1\u001F2\u001F4'},
      ).map((message) => message.messageId),
      [10, 20, 40, 50],
    );
  });

  test(
    'oldest edge notice waits for rendered window to include oldest message',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
        _message(messageId: 40, locationMessageId: 4, content: 'new 4'),
        _message(messageId: 50, locationMessageId: 5, content: 'new 5'),
      ];

      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {4, 5},
        ),
        isFalse,
      );
      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
          releasedGapKeys: const {'loc-1\u001F2\u001F4'},
        ),
        isTrue,
      );
    },
  );

  test(
    'oldest edge notice waits while older loading or gap fill is active',
    () {
      final source = [
        _message(messageId: 10, locationMessageId: 1, content: 'old 1'),
        _message(messageId: 20, locationMessageId: 2, content: 'old 2'),
      ];

      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
          loadingOlderMessages: true,
        ),
        isFalse,
      );
      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
          hasPendingGapFill: true,
        ),
        isFalse,
      );
      expect(
        shouldShowLocationChatOldestEdgeNoticeForTesting(
          source,
          renderedLocationMessageIds: const {1, 2},
          hasMoreOlderMessages: true,
        ),
        isFalse,
      );
    },
  );
}

WorldChatroomMessage _message({
  required int messageId,
  required int locationMessageId,
  required String content,
  String senderType = 'user',
  String? senderId,
}) {
  return WorldChatroomMessage(
    messageId: messageId,
    locationMessageId: locationMessageId,
    conversationRoundId: '$messageId',
    roundOrder: 0,
    tickNo: senderType == 'tick' ? messageId : 0,
    locationId: 'loc-1',
    senderType: senderType,
    senderId: senderId ?? (senderType == 'tick' ? 'tick' : 'u_peer'),
    senderName: senderType == 'tick' ? 'Time' : 'Peer',
    content: content,
    createdAt: null,
  );
}
