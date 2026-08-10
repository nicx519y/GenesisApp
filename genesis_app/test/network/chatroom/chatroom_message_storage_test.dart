import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('canonical V2 tick uses its positive location cursor', () async {
    final storage = MemoryChatroomMessageStorage();
    await storage.mergeMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      messages: <Map<String, dynamic>>[
        _message(messageId: 100, locationMessageId: 10),
        _message(
          messageId: 90,
          locationMessageId: 11,
          senderType: 'tick',
          type: 'tick',
          payload: const <String, Object?>{
            'current_time': 'Day 2, 10:00',
            'tick_no': 4,
            'sub_tick_no': 1,
          },
        ),
        _message(messageId: 110, senderType: 'tick'),
      ],
    );

    final older = await storage.loadMessagesBefore(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      beforeMessageId: 12,
      limit: 20,
    );

    expect(older.map((message) => message['msg_id']), <int>[100, 90]);
    expect(older.map((message) => message['location_msg_id']), <int>[10, 11]);

    await storage.deleteMessagesAtOrBefore(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      maxLocationMessageId: 11,
    );
    final remaining = await storage.loadLatestMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      limit: 20,
    );
    expect(remaining.map((message) => message['msg_id']), <int>[110]);
    expect(remaining.single['location_msg_id'], 0);
  });

  test(
    'cursorless non-tick timelines do not repeat or delete at a location cursor',
    () async {
      final storage = MemoryChatroomMessageStorage();
      await storage.mergeMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        messages: <Map<String, dynamic>>[
          _message(messageId: 100, locationMessageId: 10),
          _message(messageId: 105, senderType: 'user_enter_location'),
          _message(messageId: 110, senderType: 'tick'),
          _message(messageId: 115, senderType: 'story_events'),
          _message(messageId: 116, senderType: 'characters_moved'),
          _message(messageId: 120, locationMessageId: 11),
        ],
      );

      final older = await storage.loadMessagesBefore(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        beforeMessageId: 12,
        beforeWorldMessageId: 120,
        limit: 20,
      );

      expect(older.map((message) => message['msg_id']), <int>[100, 110, 120]);

      await storage.deleteMessagesAtOrBefore(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        maxLocationMessageId: 11,
        maxWorldMessageId: 120,
      );
      final remaining = await storage.loadLatestMessages(
        ownerUid: 'user-1',
        worldId: 'world-1',
        locationId: 'loc-1',
        limit: 20,
      );

      expect(remaining.map((message) => message['msg_id']), <int>[
        105,
        115,
        116,
      ]);
      expect(remaining.map((message) => message['sender_type']), <String>[
        'user_enter_location',
        'story_events',
        'characters_moved',
      ]);
    },
  );

  test('database v4 removes only old cursorless supplemental rows', () async {
    sqfliteFfiInit();
    final tempDirectory = await Directory.systemTemp.createTemp(
      'genesis-chatroom-storage-test-',
    );
    final databasePath = '${tempDirectory.path}/chatroom.db';
    final oldDatabase = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute(_createV3TableSql);
        },
      ),
    );
    for (final row in <Map<String, Object?>>[
      _row(_message(messageId: 1, locationMessageId: 1)),
      _row(_message(messageId: 2, senderType: 'tick')),
      _row(_message(messageId: 3, senderType: 'story_events')),
      _row(_message(messageId: 4, senderType: 'characters_moved')),
      _row(_message(messageId: 5, senderType: 'user_enter_location')),
      _row(
        _message(
          messageId: 6,
          locationMessageId: 6,
          senderType: 'tick',
          type: 'tick',
          payload: const <String, Object?>{'tick_no': 1},
        ),
        storedLocationMessageId: 0,
      ),
    ]) {
      await oldDatabase.insert('chatroom_messages', row);
    }
    await oldDatabase.close();

    final storage = SqfliteChatroomMessageStorage(
      databaseFactoryOverride: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(() async {
      await storage.close();
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final messages = await storage.loadLatestMessages(
      ownerUid: 'user-1',
      worldId: 'world-1',
      locationId: 'loc-1',
      limit: 20,
    );

    expect(messages.map((message) => message['msg_id']), <int>[5, 1]);
    expect(messages.map((message) => message['sender_type']), <String>[
      'user_enter_location',
      'user',
    ]);
  });
}

Map<String, dynamic> _message({
  required int messageId,
  int locationMessageId = 0,
  String senderType = 'user',
  String type = '',
  Map<String, Object?>? payload,
}) {
  return <String, dynamic>{
    'global_msg_id': 90000 + messageId,
    'msg_id': messageId,
    'location_msg_id': locationMessageId,
    'location_id': 'loc-1',
    'conversation_round_id': 1,
    'sender_type': senderType,
    'sender_id': 'sender-$messageId',
    'sender_name': 'Sender $messageId',
    'content': '',
    if (type.isNotEmpty) 'type': type,
    if (payload != null) 'payload': payload,
    'ts': messageId,
  };
}

Map<String, Object?> _row(
  Map<String, dynamic> message, {
  int? storedLocationMessageId,
}) {
  return <String, Object?>{
    'owner_uid': 'user-1',
    'world_id': 'world-1',
    'location_id': 'loc-1',
    'global_msg_id': message['global_msg_id'],
    'msg_id': message['msg_id'],
    'location_msg_id': storedLocationMessageId ?? message['location_msg_id'],
    'raw_json': jsonEncode(message),
    'created_at': message['ts'],
  };
}

const String _createV3TableSql = '''
  CREATE TABLE chatroom_messages (
    owner_uid TEXT NOT NULL,
    world_id TEXT NOT NULL,
    location_id TEXT NOT NULL,
    global_msg_id INTEGER NOT NULL DEFAULT 0,
    msg_id INTEGER NOT NULL,
    location_msg_id INTEGER NOT NULL DEFAULT 0,
    raw_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY(owner_uid, world_id, location_id, location_msg_id, msg_id)
  )
''';
