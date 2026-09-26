import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_tick_presenter.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/world_tick_event_item.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_http_models.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:genesis_flutter_android/network/chatroom/world_chatroom_service.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_reply_render_snapshot.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_typography.dart';

void _expectIconAndFirstLineCentered(WidgetTester tester, String text) {
  final label = find.text(text);
  final rowFinder = find.ancestor(of: label, matching: find.byType(Row)).last;
  final row = tester.widget<Row>(rowFinder);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: label, matching: find.byType(RichText)),
  );
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout(maxWidth: paragraph.size.width);
  final firstLine = painter.computeLineMetrics().first;
  final firstLineCenter =
      tester.getTopLeft(label).dy +
      firstLine.baseline -
      firstLine.ascent +
      firstLine.height / 2;
  painter.dispose();
  expect(
    tester
        .getCenter(
          find.descendant(
            of: rowFinder,
            matching: find.byWidget(row.children.first),
          ),
        )
        .dy,
    closeTo(firstLineCenter, 0.5),
    reason: 'The icon must center on the first line: $text',
  );
}

Map<String, dynamic> _status(String owner, String content) => {
  'owner': owner,
  'icon': '👩🏽‍🚀',
  'form': '记录 record',
  'content': content,
};
Map<String, dynamic> _chapter({int locations = 2, int statuses = 2}) => {
  'tick_no': 1,
  'sub_tick_no': 2,
  'current_time': '  Day 1 · 00:20 | 02/07/2026  ',
  'global': 'The city waits.',
  'global_status': [_status('world', 'World A'), _status('world', 'World B')],
  'story_events': [
    for (var i = 0; i < locations; i++)
      {
        'location_id': 'loc-$i',
        'text': 'Opening $i',
        'clue': 'Clue $i',
        'cast': [
          {'id': 'char-$i', 'name': 'Cast $i'},
        ],
        'status': [
          for (var j = 0; j < statuses; j++)
            _status('char-$i', 'Content $i-$j'),
        ],
      },
  ],
  'characters_moved': <Object?>[],
};

/// Presents a chapter as World Events does, keeping every location. A chat
/// presentation narrows to its own room; pass [restrictToLocationId] for that.
ChatTickPayloadVm _present(
  Map<String, dynamic> json, {
  bool? Function(String)? exists,
  String restrictToLocationId = '',
}) => presentChatTickChapter(
  ChatroomV2TickPayload.fromJson(json),
  locationName: (id) => 'Room $id',
  roleName: (id) => id == 'char-0' ? 'Profile name' : '',
  roleAvatarUrl: (_) => '',
  roleIsAi: (_) => true,
  locationExists: exists,
  isUserId: (id) => id == 'user',
  restrictToLocationId: restrictToLocationId,
  requireLegacyVisibility: true,
);
ChatMessageVm _message(ChatTickPayloadVm payload) => ChatMessageVm(
  localId: 'tick-1',
  isMe: false,
  status: 'sent',
  createdAt: DateTime(2026),
  senderId: 'tick',
  senderName: 'Tick',
  text: '',
  currentTime: _chapter()['current_time'] as String,
  senderType: 'tick',
  tickNo: 1,
  subTickNo: 2,
  timelinePayload: payload,
);
Map<String, dynamic> _envelope(Map<String, dynamic> payload) => {
  'type': 'tick',
  'stream_type': '',
  'world_id': 'world',
  'location_id': 'loc-0',
  'global_message_id': 10,
  'message_id': 8,
  'location_message_id': 3,
  'conversation_round_id': 1,
  'sender_type': 'tick',
  'sender_id': 'tick',
  'payload': payload,
  'err_no': 0,
  'err_msg': '',
};

void main() {
  test(
    'WS, HTTP history and stored payload preserve new content and location cursor',
    () async {
      final raw = _chapter(locations: 10, statuses: 6);
      final wire = ChatroomV2Message.fromJson(_envelope(raw));
      final ws = chatroomEventFromV2Message(wire) as ChatroomTickAdvanceMessage;
      final history = ChatroomHttpMessage.fromV2Message(wire);
      expect(ws.v2TickPayload!.toJson(), history.v2TickPayload!.toJson());
      final store = MemoryChatroomMessageStorage();
      await store.mergeMessages(
        ownerUid: 'user',
        worldId: 'world',
        locationId: 'loc-0',
        messages: [
          {
            ..._envelope(raw),
            'sender_name': 'Tick',
            'content': '',
            'tick_no': 1,
            'sub_tick_no': 2,
          },
        ],
      );
      final saved = await store.loadLatestMessages(
        ownerUid: 'user',
        worldId: 'world',
        locationId: 'loc-0',
        limit: 20,
      );
      final restored = WorldChatroomMessage.fromStorageJson(saved.single);
      expect(restored.locationMessageId, 3);
      expect(restored.v2TickPayload!.toJson(), ws.v2TickPayload!.toJson());
      final vm = _present(
        restored.v2TickPayload!.toJson().cast<String, dynamic>(),
      );
      expect(vm.globalStatuses, hasLength(2));
      expect(vm.storyEvents!.paragraphs, hasLength(10));
      expect(vm.storyEvents!.paragraphs.last.statuses, hasLength(6));
      expect(
        vm.storyEvents!.paragraphs.last.statuses.last.content,
        'Content 9-5',
      );
      expect(
        _present(_chapter(locations: 6)).storyEvents!.paragraphs,
        hasLength(6),
      );
    },
  );

  test('legacy JSON content history and plain text remain readable', () {
    final raw = _chapter();
    final dto = ChatroomHttpMessage.fromJson({
      'sender_type': 'tick',
      'content': jsonEncode(raw),
      'tick_no': 1,
    });
    expect(dto.v2TickPayload!.storyEvents, hasLength(2));
    final restored = WorldChatroomMessage.fromStorageJson({
      'sender_type': 'tick',
      'content': jsonEncode(raw),
    });
    expect(restored.v2TickPayload!.globalStatus, hasLength(2));
    final plain = ChatroomHttpMessage.fromJson({
      'sender_type': 'tick',
      'content': 'Time moves on.',
    });
    expect(plain.v2TickPayload!.isFallback, isTrue);
    final broken = ChatroomHttpMessage.fromJson({
      'sender_type': 'tick',
      'content': '{broken',
    });
    expect(broken.v2TickPayload!.isMalformed, isTrue);
  });

  test('modern empty arrays are valid, missing structure is a placeholder', () {
    final empty = {..._chapter(locations: 0), 'global_status': <Object?>[]};
    final payload = ChatroomV2TickPayload.fromJson(empty);
    expect(payload.hasStatusFields, isTrue);
    expect(payload.isMalformed, isFalse);
    expect(_present(empty).storyEvents, isNull);
    final missing = {...empty}..remove('global');
    final broken = ChatroomV2TickPayload.fromJson(missing);
    expect(broken.isMalformed, isTrue);
    expect(
      ChatroomV2TickPayload.fromJson(
        broken.toJson().cast<String, dynamic>(),
      ).isMalformed,
      isTrue,
    );
    expect(
      ChatroomV2TickPayload.fromJson({
        ...empty,
        'story_events': 42,
      }).isMalformed,
      isTrue,
    );
  });

  test(
    'all three status arrays are independently optional in Tick result models',
    () {
      for (var fields = 0; fields < 8; fields++) {
        final paragraph = <String, dynamic>{
          'location_id': 'loc-0',
          'text': 'Opening',
          'clue': 'Clue',
          if (fields & 2 != 0)
            'cast': [
              {'id': 'char-0', 'name': 'Name'},
            ],
          if (fields & 4 != 0) 'status': [_status('char-0', 'Role status')],
        };
        final result = <String, dynamic>{
          'current_time': 'Day 1',
          'narrator': 'Global',
          if (fields & 1 != 0)
            'global_status': [_status('world', 'World status')],
          'paragraphs': [paragraph],
        };
        final payload = ChatroomV2TickPayload.fromTickResult(result);
        expect(
          payload.isMalformed,
          isFalse,
          reason: 'Optional fields mask $fields',
        );
        expect(payload.hasStatusFields, fields != 0);
        expect(payload.globalStatus, hasLength(fields & 1 != 0 ? 1 : 0));
        expect(
          payload.storyEvents.single.cast,
          hasLength(fields & 2 != 0 ? 1 : 0),
        );
        expect(
          payload.storyEvents.single.status,
          hasLength(fields & 4 != 0 ? 1 : 0),
        );
        expect(payload.storyEvents.single.clue, 'Clue');
        final chat = <String, dynamic>{
          'current_time': result['current_time'],
          'global': result['narrator'],
          if (result.containsKey('global_status'))
            'global_status': result['global_status'],
          'story_events': [paragraph],
        };
        final history = ChatroomHttpMessage.fromV2Json(
          _envelope(chat),
        ).v2TickPayload!;
        expect(history.isMalformed, isFalse);
        expect(history.globalStatus.length, payload.globalStatus.length);
        final restored = ChatroomV2TickPayload.fromJson(
          payload.toJson().cast<String, dynamic>(),
        );
        expect(restored.isMalformed, isFalse);
        expect(restored.hasStatusFields, payload.hasStatusFields);
        expect(
          restored.storyEvents.single.status.length,
          payload.storyEvents.single.status.length,
        );
      }
      for (final invalid in [
        null,
        'invalid',
        1,
        <String, dynamic>{},
        ['invalid'],
      ]) {
        final raw = _chapter()..['global_status'] = invalid;
        expect(ChatroomV2TickPayload.fromJson(raw).isMalformed, isTrue);
      }
    },
  );

  test(
    'optional cast and status preserve mixed chapters through history and cache',
    () async {
      for (final missing in [
        ['cast'],
        ['status'],
        ['cast', 'status'],
      ]) {
        final raw = _chapter(locations: 4, statuses: 1);
        final last = (raw['story_events'] as List).last as Map;
        for (final field in missing) {
          last.remove(field);
        }
        final wire = ChatroomV2Message.fromJson(_envelope(raw));
        final http = ChatroomHttpMessage.fromV2Message(wire);
        final message = WorldChatroomMessage.fromHttpMessage(http);
        final payload = message.v2TickPayload!;
        expect(payload.isMalformed, isFalse);
        expect(payload.storyEvents, hasLength(4));
        expect(payload.globalStatus, hasLength(2));
        expect(payload.storyEvents.first.status.single.content, 'Content 0-0');
        if (missing.contains('cast')) {
          expect(payload.storyEvents.last.cast, isEmpty);
        }
        if (missing.contains('status')) {
          expect(payload.storyEvents.last.status, isEmpty);
        }
        final store = MemoryChatroomMessageStorage();
        await store.mergeMessages(
          ownerUid: 'user',
          worldId: 'world',
          locationId: 'loc-0',
          messages: [_envelope(raw)],
        );
        final stored = await store.loadLatestMessages(
          ownerUid: 'user',
          worldId: 'world',
          locationId: 'loc-0',
          limit: 20,
        );
        final cached = WorldChatroomMessage.fromStorageJson(
          stored.single,
        ).v2TickPayload!;
        expect(cached.isMalformed, isFalse);
        expect(cached.storyEvents, hasLength(4));
        final restored = ChatroomV2TickPayload.fromJson(
          payload.toJson().cast<String, dynamic>(),
        );
        expect(restored.isMalformed, isFalse);
        final view = _present(restored.toJson().cast<String, dynamic>());
        expect(view.isMalformed, isFalse);
        expect(view.storyEvents!.paragraphs, hasLength(4));
        expect(view.storyEvents!.paragraphs.last.text, 'Opening 3');
        expect(view.storyEvents!.paragraphs.last.clue, 'Clue 3');
      }
      for (final field in ['cast', 'status']) {
        for (final invalid in [
          null,
          'invalid',
          1,
          <String, dynamic>{},
          ['invalid'],
        ]) {
          final raw =
              jsonDecode(jsonEncode(_chapter(locations: 1)))
                  as Map<String, dynamic>;
          ((raw['story_events'] as List).single as Map)[field] = invalid;
          expect(ChatroomV2TickPayload.fromJson(raw).isMalformed, isTrue);
        }
      }
    },
  );

  test(
    'owner validation, profile and cast fallback, empty cast and unknown locations',
    () {
      final raw = _chapter();
      final first = (raw['story_events'] as List).first as Map;
      (first['cast'] as List).add({'id': 'user', 'name': 'User'});
      (first['status'] as List).addAll(<Map<String, dynamic>>[
        _status('user', 'hidden user'),
        _status('outsider', 'hidden outsider'),
        _status('world', 'World local'),
      ]);
      final vm = _present(raw);
      expect(vm.storyEvents!.paragraphs.first.statuses, hasLength(3));
      expect(
        vm.storyEvents!.paragraphs.first.statuses.first.name,
        'Profile name',
      );
      expect(vm.storyEvents!.paragraphs.last.statuses.first.name, 'Cast 1');
      expect(vm.storyEvents!.paragraphs.first.statuses.last.name, '');
      expect(
        _present(raw, exists: (_) => null).storyEvents!.paragraphs,
        hasLength(2),
      );
      expect(
        _present(raw, exists: (id) => id == 'loc-0').storyEvents!.paragraphs,
        hasLength(1),
      );
      first['cast'] = <Object?>[];
      first['status'] = <Object?>[];
      final noCast = _present(raw).storyEvents!.paragraphs.first;
      expect(noCast.statuses, isEmpty);
      expect(noCast.text, 'Opening 0');
      expect(noCast.clue, 'Clue 0');
    },
  );

  test(
    'legacy visibility, differing times and source indices survive unified projection',
    () {
      final vm = _present({
        'current_time': 'Day 2',
        'global': 'Old narrator',
        'story_events': [
          {
            'location_id': 'elsewhere',
            'text': 'hidden',
            'visibility': 'public',
          },
          {
            'location_id': 'loc-0',
            'timestamp': 'Day 1',
            'text': 'Old event',
            'visibility': 'char_only',
            'visible_to': ['char-0'],
          },
        ],
      }, restrictToLocationId: 'loc-0');
      expect(vm.storyEvents!.paragraphs, hasLength(1));
      final paragraph = vm.storyEvents!.paragraphs.single;
      expect(paragraph.timestamp, 'Day 1');
      expect(paragraph.visibleRoles.single.name, 'Profile name');
      expect(paragraph.sourceIndex, 1);
    },
  );

  test(
    'a chat narrows every chapter to its own room; World keeps them all',
    () {
      final raw = _chapter(locations: 3, statuses: 0);
      List<String> rooms(ChatTickPayloadVm vm) => [
        for (final paragraph in vm.storyEvents!.paragraphs)
          paragraph.locationName,
      ];

      expect(rooms(_present(raw, restrictToLocationId: 'loc-1')), [
        'Room loc-1',
      ]);
      expect(rooms(_present(raw)), ['Room loc-0', 'Room loc-1', 'Room loc-2']);
      // A chat room the chapter never mentions carries no story events at all.
      expect(_present(raw, restrictToLocationId: 'loc-9').storyEvents, isNull);
    },
  );

  test(
    'status-only changes invalidate presentation; frozen collections and copy include statuses',
    () {
      final mutable = <ChatTickStatusVm>[
        const ChatTickStatusVm(
          owner: 'world',
          icon: '📋',
          form: 'log',
          content: 'before',
        ),
      ];
      final message = _message(ChatTickPayloadVm(globalStatuses: mutable));
      final frozen = freezeLocationChatReplyMessage(message);
      mutable[0] = const ChatTickStatusVm(
        owner: 'world',
        icon: '📋',
        form: 'log',
        content: 'after',
      );
      expect(
        locationChatReplyMessagePresentationEqual(message, frozen),
        isFalse,
      );
      expect(
        (frozen.timelinePayload as ChatTickPayloadVm)
            .globalStatuses
            .single
            .content,
        'before',
      );
      final raw = _chapter();
      final before = freezeLocationChatReplyMessage(_message(_present(raw)));
      (((raw['story_events'] as List).first as Map)['status'] as List)
              .first['content'] =
          'changed';
      final after = _message(_present(raw));
      expect(locationChatReplyMessagePresentationEqual(before, after), isFalse);
      expect(chatTickMessageCopyText(after), contains('changed'));
      expect(chatTickMessageCopyText(after), contains('World B'));
      expect(chatTickMessageCopyText(after), contains('Cast 1'));
    },
  );

  testWidgets(
    'chat and World share chapter layout, typography and unformatted time',
    (tester) async {
      final raw = _chapter();
      final payload = _present(raw);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChatTickMessageBubble(
                message: _message(payload),
                style: kLocationChatStyle,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ChatTickChapterContent), findsOneWidget);
      expect(find.text(raw['current_time'] as String), findsOneWidget);
      expect(find.text('World B'), findsOneWidget);
      expect(find.text('Room loc-1'), findsOneWidget);
      expect(find.text('world'), findsNothing);
      final name = tester.widget<Text>(find.text('Profile name').first);
      expect(name.style!.fontSize, GenesisTypography.bodyStrong.fontSize);
      expect(name.style!.fontWeight, GenesisTypography.bodyStrong.fontWeight);
      expect(name.style!.height, GenesisTypography.bodyStrong.height);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorldTickEventItem(
                tick: {
                  'tick_result': {
                    'current_time': raw['current_time'],
                    'narrator': raw['global'],
                    'global_status': raw['global_status'],
                    'paragraphs': raw['story_events'],
                  },
                },
                tickNumber: 1,
                subTickNumber: 2,
                fallbackBody: '',
                useChatEventStyle: true,
                locationsById: const {
                  'loc-0': {'name': 'Room loc-0'},
                  'loc-1': {'name': 'Room loc-1'},
                },
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ChatTickChapterContent), findsOneWidget);
      expect(find.text('World B'), findsOneWidget);
      expect(find.text('Content 1-1'), findsOneWidget);
      expect(find.text(raw['current_time'] as String), findsOneWidget);
      _expectIconAndFirstLineCentered(tester, raw['current_time'] as String);
      _expectIconAndFirstLineCentered(tester, 'Room loc-0');
      _expectIconAndFirstLineCentered(tester, 'Clue 0');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('multiline Tick labels keep icons centered on the first line', (
    tester,
  ) async {
    final raw = _chapter(locations: 1, statuses: 0);
    final event = (raw['story_events'] as List).single as Map;
    const locationId =
        'a very long location with several words over several lines';
    const time = 'Day 123456 at 12:30 in a very long chapter time description';
    const clue =
        'Look out at the gate where many people have gathered and wait for a signal.';
    event['location_id'] = locationId;
    event['clue'] = clue;
    raw['global_status'] = <Object?>[];
    for (final scale in [1.0, 2.0, 3.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SizedBox(
                width: 220,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ChatTickHeader(
                        label: 'Tick 1234567890-1234567890',
                        style: kLocationChatStyle,
                      ),
                      ChatTickChapterContent(
                        payload: _present(raw),
                        currentTime: time,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final label in [
        time,
        'Room $locationId',
        clue,
        'Tick 1234567890-1234567890',
      ]) {
        _expectIconAndFirstLineCentered(tester, label);
      }
      expect(
        tester.getSize(find.text(time)).height,
        greaterThan(
          GenesisTypography.body.fontSize! *
              GenesisTypography.body.height! *
              scale,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Tick header dot centers on Inter letterforms at each text scale', (
    tester,
  ) async {
    final fontData = await rootBundle.load('assets/fonts/InterVariable.ttf');
    await (FontLoader('Inter')..addFont(Future.value(fontData))).load();
    // Read the bundled font's cap height rather than assuming an em-box center.
    int tableOffset(String name) {
      for (var i = 0; i < fontData.getUint16(4); i++) {
        final record = 12 + 16 * i;
        final tag = String.fromCharCodes([
          for (var j = 0; j < 4; j++) fontData.getUint8(record + j),
        ]);
        if (tag == name) return fontData.getUint32(record + 8);
      }
      throw StateError('Missing font table: $name');
    }

    final unitsPerEm = fontData.getUint16(tableOffset('head') + 18);
    final capHeight = fontData.getInt16(tableOffset('OS/2') + 88);
    for (final scale in [1.0, 2.0, 3.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: DefaultTextStyle(
                style: const TextStyle(
                  leadingDistribution: TextLeadingDistribution.proportional,
                ),
                child: ChatTickHeader(
                  label: 'Tick 1-2',
                  style: kLocationChatStyle,
                ),
              ),
            ),
          ),
        ),
      );
      final title = find.text('Tick 1-2');
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: title, matching: find.byType(RichText)),
      );
      final baseline = paragraph.getDryBaseline(
        BoxConstraints.tight(paragraph.size),
        TextBaseline.alphabetic,
      )!;
      final letterCenter =
          tester.getTopLeft(title).dy +
          baseline -
          GenesisTypography.bodyStrong.fontSize! *
              scale *
              capHeight /
              unitsPerEm /
              2;
      expect(
        tester.getCenter(find.byKey(const ValueKey('chat-tick-header-dot'))).dy,
        closeTo(letterCenter, 0.3),
        reason: 'Text scale $scale',
      );
      final textStyle = tester.widget<Text>(title).style!;
      expect(textStyle.fontSize, GenesisTypography.bodyStrong.fontSize);
      expect(textStyle.height, GenesisTypography.bodyStrong.height);
      expect(textStyle.fontWeight, GenesisTypography.bodyStrong.fontWeight);
    }
  });

  testWidgets('narrow large text, long labels and unicode do not overflow', (
    tester,
  ) async {
    final raw = _chapter(locations: 1, statuses: 1);
    final event = (raw['story_events'] as List).single as Map;
    (event['status'] as List).single['form'] = 'Very long label ' * 20;
    final payload = _present(raw);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: SingleChildScrollView(
                  child: ChatTickMessageBubble(
                    message: _message(payload),
                    style: kLocationChatStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(find.text('Very long label ' * 20));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(find.text('👩🏽‍🚀'), findsNWidgets(3));
    _expectIconAndFirstLineCentered(tester, raw['current_time'] as String);
    _expectIconAndFirstLineCentered(tester, 'Room loc-0');
    _expectIconAndFirstLineCentered(tester, 'Clue 0');
  });

  testWidgets(
    'status headings center icons and use even leading at all scales',
    (tester) async {
      final payload = _present(_chapter(locations: 1, statuses: 1));
      for (final scale in [1.0, 2.0, 3.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: DefaultTextStyle(
                  style: const TextStyle(
                    leadingDistribution: TextLeadingDistribution.proportional,
                  ),
                  child: SingleChildScrollView(
                    child: ChatTickChapterContent(
                      payload: payload,
                      currentTime: 'Day 1',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.text('👩🏽‍🚀'), findsNWidgets(3));
        for (final element in find.text('👩🏽‍🚀').evaluate()) {
          final icon = find.byElementPredicate(
            (candidate) => candidate == element,
          );
          final row = find.ancestor(of: icon, matching: find.byType(Row)).last;
          final label = find.descendant(
            of: row,
            matching: find.text('记录 record'),
          );
          expect(
            tester.getCenter(icon).dy,
            closeTo(tester.getCenter(label).dy, 0.01),
          );
          for (final text in tester.widgetList<Text>(
            find.descendant(
              of: row,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    const [
                      '👩🏽‍🚀',
                      '记录 record',
                      'Profile name',
                      ' · ',
                    ].contains(widget.data),
              ),
            ),
          )) {
            expect(
              text.style?.leadingDistribution,
              TextLeadingDistribution.even,
            );
            expect(text.style?.fontSize, GenesisTypography.body.fontSize);
            expect(text.style?.height, GenesisTypography.body.height);
          }
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('malformed chapter is static and replaced by recovered content', (
    tester,
  ) async {
    Widget host(ChatTickPayloadVm payload) => MaterialApp(
      home: Scaffold(
        body: ChatTickChapterContent(payload: payload, currentTime: 'Day 1'),
      ),
    );
    await tester.pumpWidget(host(const ChatTickPayloadVm(isMalformed: true)));
    expect(find.byKey(const ValueKey('tick-chapter-skeleton')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(host(_present(_chapter(locations: 0))));
    expect(find.byKey(const ValueKey('tick-chapter-skeleton')), findsNothing);
    expect(find.text('World A'), findsOneWidget);
  });

  testWidgets('chapter preview and legacy World details', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    if (Platform.environment['TICK_PREVIEW_PATH'] != null) {
      await tester.runAsync(() async {
        await (FontLoader('Inter')
              ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'))
              ..addFont(
                rootBundle.load('assets/fonts/InterVariable-Italic.ttf'),
              ))
            .load();
      });
    }
    final boundary = GlobalKey();
    final raw = _chapter(locations: 1, statuses: 2);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(textTheme: GenesisTypography.textTheme),
        home: Scaffold(
          backgroundColor: const Color(0xFF151517),
          body: RepaintBoundary(
            key: boundary,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ChatTickMessageBubble(
                message: _message(_present(raw)),
                style: kLocationChatStyle,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final output = Platform.environment['TICK_PREVIEW_PATH'];
    if (output != null) {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorldTickEventItem(
            tick: {
              'tick_result': {
                'current_time': 'Day 2',
                'narrator': 'Old narrator',
                'paragraphs': [
                  {
                    'location_id': 'loc-0',
                    'timestamp': 'Day 1',
                    'text': 'Old content',
                    'clue': 'Old clue',
                    'visibility': 'char_only',
                    'visible_to': ['char-0'],
                    'character_deltas': [
                      {'name': 'Old name', 'delta': 3},
                    ],
                  },
                ],
              },
            },
            tickNumber: 1,
            fallbackBody: '',
            useChatEventStyle: true,
            locationsById: const {
              'loc-0': {'name': 'Room'},
            },
            charactersById: const {
              'char-0': {'name': 'Old name'},
            },
          ),
        ),
      ),
    );
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);
    expect(find.text('Old name'), findsOneWidget);
    expect(find.text('Old name +3'), findsOneWidget);
    expect(find.text('Old clue'), findsOneWidget);
  });
}
