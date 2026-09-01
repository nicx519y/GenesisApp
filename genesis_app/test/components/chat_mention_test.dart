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
const _secondCharacter = ChatMentionEntry(
  id: 'char-2',
  name: 'Bob',
  type: ChatMentionType.character,
);
const _location = ChatMentionEntry(
  id: 'loc-1',
  name: 'Moon Harbor',
  type: ChatMentionType.location,
);
const _secondLocation = ChatMentionEntry(
  id: 'loc-2',
  name: 'Sun Plaza',
  type: ChatMentionType.location,
);

ChatMentionCatalog _catalog() => ChatMentionCatalog(
  characters: const <ChatMentionEntry>[_character, _secondCharacter],
  locations: const <ChatMentionEntry>[_location, _secondLocation],
);

void main() {
  testWidgets(
    'mention tags inherit the surrounding text style without decoration',
    (tester) async {
      const inheritedStyle = TextStyle(
        color: Color(0xD9FFFFFF),
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: inheritedStyle,
              child: Column(
                children: <Widget>[
                  ChatCharacterMentionTag(name: 'Alice'),
                  ChatLocationMentionTag(name: 'Moon Harbor'),
                ],
              ),
            ),
          ),
        ),
      );

      final characterText = tester.widget<Text>(find.text('Alice'));
      final locationText = tester.widget<Text>(find.text('Moon Harbor'));
      expect(characterText.style?.color, inheritedStyle.color);
      expect(characterText.style?.fontStyle, inheritedStyle.fontStyle);
      expect(locationText.style?.color, inheritedStyle.color);
      expect(locationText.style?.fontStyle, inheritedStyle.fontStyle);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);
    },
  );

  test('mention catalog filters self and keeps other player characters', () {
    final catalog = locationChatMentionCatalogForState(
      WorldChatroomState(world: _mentionWorld()),
      currentUserIds: const <String>['user-me'],
      currentLocationIds: const <String>['loc-leaf'],
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
    expect(catalog.currentLocationCharacters.map((entry) => entry.id), <String>[
      'char-1',
    ]);
    expect(catalog.locations.map((entry) => entry.id), <String>['loc-leaf']);
    expect(catalog.locations.map((entry) => entry.name), <String>[
      'Moon Harbor',
    ]);
    expect(catalog.locations.map((entry) => entry.subtitle), <String>[
      'Silver Coast',
    ]);
    expect(catalog.locations.single.isCurrentLocation, isTrue);
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
      expect(controller.selection, const TextSelection.collapsed(offset: 6));
    },
  );

  test('mention insertion appends one space and places the caret after it', () {
    final controller = LocationChatMentionEditingController(
      catalog: _catalog(),
    );
    addTearDown(controller.dispose);
    controller.value = const TextEditingValue(
      text: '@',
      selection: TextSelection.collapsed(offset: 1),
    );

    controller.insertMention(_character, replaceStart: 0, replaceEnd: 1);

    expect(controller.text, '\uFFFC ');
    expect(controller.serializedText, '@Alice<char-1> ');
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
  });

  testWidgets('mention controller renders its edit atom as a tag', (
    tester,
  ) async {
    const inputStyle = TextStyle(
      color: Color(0xF2FFFFFF),
      fontSize: 15,
      height: 1.4,
      fontWeight: FontWeight.w400,
    );
    final controller = LocationChatMentionEditingController(catalog: _catalog())
      ..setSerializedText('@Alice<char-1>');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(controller: controller, style: inputStyle),
        ),
      ),
    );

    expect(find.byType(ChatCharacterMentionTag), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.textContaining('@Alice'), findsNothing);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    final mentionText = tester.widget<Text>(find.text('Alice'));
    expect(mentionText.style?.color, inputStyle.color);
    expect(mentionText.style?.fontSize, inputStyle.fontSize);
    expect(mentionText.style?.height, inputStyle.height);
    expect(mentionText.style?.fontWeight, inputStyle.fontWeight);
  });

  testWidgets('each adjacent input mention keeps its own icon', (tester) async {
    final controller = LocationChatMentionEditingController(catalog: _catalog())
      ..setSerializedText(
        '@Alice<char-1> @Bob<char-2> @Moon Harbor<loc-1> '
        '@Sun Plaza<loc-2> ',
      );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(controller: controller)),
      ),
    );

    expect(find.byIcon(Icons.person_outline_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.place_outlined), findsNWidgets(2));
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Moon Harbor'), findsOneWidget);
    expect(find.text('Sun Plaza'), findsOneWidget);
    expect(controller.serializedText, contains('@Alice<char-1> @Bob<char-2>'));
  });

  testWidgets('LocationChat mentions inherit plain and markdown styles', (
    tester,
  ) async {
    final message = ChatMessageVm(
      localId: 'mention-message',
      senderId: 'me',
      senderName: 'Me',
      text:
          'Ask @Alice<char-1> @Bob<char-2> at '
          '*@Moon Harbor<loc-1> @Sun Plaza<loc-2>*.',
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

    expect(find.byType(ChatCharacterMentionTag), findsNothing);
    expect(find.byType(ChatLocationMentionTag), findsNothing);
    final bubbleText = tester.widget<Text>(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byType(Text),
      ),
    );
    final rootSpan = bubbleText.textSpan! as TextSpan;
    final characterMention = _textSpanFor(rootSpan, 'Alice');
    final secondCharacterMention = _textSpanFor(rootSpan, 'Bob');
    final locationMention = _textSpanFor(rootSpan, 'Moon Harbor');
    final secondLocationMention = _textSpanFor(rootSpan, 'Sun Plaza');
    expect(characterMention, isNotNull);
    expect(characterMention!.style?.color, isNull);
    expect(secondCharacterMention, isNotNull);
    expect(secondCharacterMention!.style?.color, isNull);
    expect(rootSpan.style?.color, isNotNull);
    expect(locationMention, isNotNull);
    expect(locationMention!.style?.color, const Color(0xFF888888));
    expect(locationMention.style?.fontStyle, FontStyle.italic);
    expect(secondLocationMention, isNotNull);
    expect(secondLocationMention!.style?.color, const Color(0xFF888888));
    expect(secondLocationMention.style?.fontStyle, FontStyle.italic);
    expect(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byIcon(Icons.person_outline_rounded),
      ),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: find.byType(ChatMessageBubble),
        matching: find.byIcon(Icons.place_outlined),
      ),
      findsNWidgets(2),
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

TextSpan? _textSpanFor(InlineSpan root, String text) {
  TextSpan? result;
  root.visitChildren((child) {
    if (child is TextSpan && child.text == text) {
      result = child;
      return false;
    }
    return true;
  });
  return result;
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
    characterPositions: const <Map<String, dynamic>>[
      {
        'location_id': 'loc-leaf',
        'character': {'id': 'char-1', 'name': 'Alice'},
      },
    ],
    userPositions: const <Map<String, dynamic>>[],
  );
}
