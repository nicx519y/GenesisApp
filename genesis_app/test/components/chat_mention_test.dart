import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/network/models/location_tree.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';

const _character = ChatMentionEntry(
  id: 'char-1',
  name: 'Alice',
  type: ChatMentionType.character,
);
const _location = ChatMentionEntry(
  id: 'loc-1',
  name: 'Moon Harbor',
  type: ChatMentionType.location,
);

ChatMentionCatalog _catalog() => ChatMentionCatalog(
  characters: const <ChatMentionEntry>[_character],
  locations: const <ChatMentionEntry>[_location],
);

void main() {
  testWidgets(
    'mention tags use transparent backgrounds and colored w600 text',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                ChatCharacterMentionTag(name: 'Alice'),
                ChatLocationMentionTag(name: 'Moon Harbor'),
              ],
            ),
          ),
        ),
      );

      final characterContainer = tester.widget<Container>(
        find
            .ancestor(of: find.text('@Alice'), matching: find.byType(Container))
            .first,
      );
      final locationContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('@Moon Harbor'),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(
        (characterContainer.decoration! as BoxDecoration).color,
        Colors.transparent,
      );
      expect(
        (locationContainer.decoration! as BoxDecoration).color,
        Colors.transparent,
      );
      expect(ChatCharacterMentionTag.textColor, const Color(0xFF39FF14));
      expect(ChatLocationMentionTag.textColor, const Color(0xFF5AC8FA));
      expect(
        tester.widget<Text>(find.text('@Alice')).style,
        const TextStyle(
          color: ChatCharacterMentionTag.textColor,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );
      expect(
        tester.widget<Text>(find.text('@Moon Harbor')).style,
        const TextStyle(
          color: ChatLocationMentionTag.textColor,
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );
    },
  );

  test('mention catalog filters self and keeps other player characters', () {
    final catalog = locationChatMentionCatalogForState(
      WorldChatroomState(world: _mentionWorld()),
      currentUserIds: const <String>['user-me'],
    );

    expect(catalog.characters.map((entry) => entry.id), <String>[
      'char-1',
      'char-2',
      'char-other',
    ]);
    expect(catalog.characters.map((entry) => entry.isPlayerControlled), <bool>[
      false,
      false,
      true,
    ]);
    expect(catalog.entryForId('char-self'), isNull);
    expect(catalog.locations.map((entry) => entry.id), <String>['loc-leaf']);
    expect(catalog.locations.map((entry) => entry.name), <String>[
      'Moon Harbor',
    ]);
    expect(catalog.locations.map((entry) => entry.subtitle), <String>[
      'Silver Coast',
    ]);
    expect(catalog.entryForId('loc-root'), isNull);
    expect(catalog.entryForId('loc-parent'), isNull);
  });

  test('mention parser recognizes known ids and leaves unknown ids raw', () {
    final tokens = parseKnownChatMentions(
      'Ask @Alice<char-1> at @Moon Harbor<loc-1> and @Ghost<missing>.',
      _catalog(),
    );

    expect(tokens.map((token) => token.name), <String>['Alice', 'Moon Harbor']);
    expect(tokens.map((token) => token.entry.type), <ChatMentionType>[
      ChatMentionType.character,
      ChatMentionType.location,
    ]);
  });

  test('mention controller serializes tags and deletes one tag atomically', () {
    final controller = LocationChatMentionEditingController(
      catalog: _catalog(),
    );
    addTearDown(controller.dispose);
    controller.setSerializedText('Ask @Alice<char-1> now');

    expect(controller.serializedText, 'Ask @Alice<char-1> now');
    expect(controller.text.length, 'Ask  now'.length + 1);

    final placeholderOffset = controller.text.indexOf('\uFFFC');
    controller.value = TextEditingValue(
      text: controller.text.replaceRange(
        placeholderOffset,
        placeholderOffset + 1,
        '',
      ),
      selection: TextSelection.collapsed(offset: placeholderOffset),
    );

    expect(controller.text, 'Ask  now');
    expect(controller.serializedText, 'Ask  now');
  });

  test(
    'mention controller detects at insertion and replaces it at the caret',
    () {
      final controller = LocationChatMentionEditingController(
        catalog: _catalog(),
      );
      addTearDown(controller.dispose);
      controller.value = const TextEditingValue(
        text: 'Ask @ now',
        selection: TextSelection.collapsed(offset: 5),
      );

      expect(controller.takeInsertedAtOffset(), 4);
      controller.insertMention(_character, replaceStart: 4, replaceEnd: 5);
      expect(controller.serializedText, 'Ask @Alice<char-1> now');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    },
  );

  testWidgets('mention controller renders its edit atom as a tag', (
    tester,
  ) async {
    final controller = LocationChatMentionEditingController(catalog: _catalog())
      ..setSerializedText('@Alice<char-1>');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(controller: controller)),
      ),
    );

    expect(find.byType(ChatCharacterMentionTag), findsOneWidget);
    expect(find.text('@Alice'), findsOneWidget);
  });

  testWidgets('LocationChat scope renders known mentions as colored tags', (
    tester,
  ) async {
    final message = ChatMessageVm(
      localId: 'mention-message',
      senderId: 'me',
      senderName: 'Me',
      text: 'Ask @Alice<char-1> at @Moon Harbor<loc-1>.',
      isMe: true,
      status: 'sent',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMentionScope(
            catalog: _catalog(),
            child: ChatMessageRow(message: message, showDateDivider: false),
          ),
        ),
      ),
    );

    expect(find.byType(ChatCharacterMentionTag), findsOneWidget);
    expect(find.byType(ChatLocationMentionTag), findsOneWidget);
    expect(
      tester
          .widget<ChatCharacterMentionTag>(find.byType(ChatCharacterMentionTag))
          .name,
      'Alice',
    );
    expect(
      tester
          .widget<ChatLocationMentionTag>(find.byType(ChatLocationMentionTag))
          .name,
      'Moon Harbor',
    );
  });

  testWidgets('chat bubbles outside LocationChat keep mention syntax raw', (
    tester,
  ) async {
    final message = ChatMessageVm(
      localId: 'plain-message',
      senderId: 'me',
      senderName: 'Me',
      text: 'Ask @Alice<char-1>.',
      isMe: true,
      status: 'sent',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageRow(message: message, showDateDivider: false),
        ),
      ),
    );

    expect(find.byType(ChatCharacterMentionTag), findsNothing);
    expect(find.textContaining('@Alice<char-1>'), findsOneWidget);
  });
}

WorldDetail _mentionWorld() {
  const leaf = LocationTreeNode<Map<String, dynamic>>(
    id: 'loc-leaf',
    parentId: 'loc-parent',
    depth: 2,
    value: <String, dynamic>{
      'location_id': 'loc-leaf',
      'location_name': 'Moon Harbor',
    },
    children: <LocationTreeNode<Map<String, dynamic>>>[],
  );
  const parent = LocationTreeNode<Map<String, dynamic>>(
    id: 'loc-parent',
    parentId: 'loc-root',
    depth: 1,
    value: <String, dynamic>{
      'location_id': 'loc-parent',
      'location_name': 'Silver Coast',
    },
    children: <LocationTreeNode<Map<String, dynamic>>>[leaf],
  );
  const root = LocationTreeNode<Map<String, dynamic>>(
    id: 'loc-root',
    parentId: '',
    depth: 0,
    value: <String, dynamic>{
      'location_id': 'loc-root',
      'location_name': 'Root Hall',
    },
    children: <LocationTreeNode<Map<String, dynamic>>>[parent],
  );
  return WorldDetail(
    id: 1,
    worldId: 'world-1',
    originId: 1,
    ownerUid: 'owner-1',
    name: 'Mention World',
    tickCount: 0,
    connectCount: 0,
    characterCount: 4,
    playerCount: 0,
    currentTime: '',
    latestTickAt: null,
    latestNarrator: '',
    isProgressing: false,
    relationStatus: 'owner',
    metric: const <String, dynamic>{},
    inviteToken: '',
    createdAt: null,
    updatedAt: null,
    origin: const OriginSummary(
      id: 1,
      oid: 'origin-1',
      name: 'Mention Origin',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 0,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    ),
    characters: const <Map<String, dynamic>>[
      {'char_id': 'char-1', 'name': 'Alice'},
      {'char_id': 'char-1', 'name': 'Duplicate Alice'},
      {'character_id': 'char-2', 'name': 'Bob'},
      {
        'character_id': 'char-self',
        'name': 'My Character',
        'player_uid': 'user-me',
      },
      {
        'character_id': 'char-other',
        'name': 'Other Player',
        'player_uid': 'user-other',
      },
    ],
    ticks: const <Map<String, dynamic>>[],
    locations: const <Map<String, dynamic>>[],
    locationTree: const <LocationTreeNode<Map<String, dynamic>>>[root],
    characterPositions: const <Map<String, dynamic>>[],
    userPositions: const <Map<String, dynamic>>[],
  );
}
