import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../json_utils.dart';

abstract class ChatroomMessageStorage {
  Future<List<Map<String, dynamic>>> loadLatestMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int limit,
  });

  Future<List<Map<String, dynamic>>> loadMessagesBefore({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int beforeMessageId,
    required int limit,
  });

  Future<void> mergeMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required List<Map<String, dynamic>> messages,
    int maxMessagesPerLocation = 200,
  });

  Future<void> upsertMessage({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required Map<String, dynamic> message,
    int maxMessagesPerLocation = 200,
  });

  Future<void> clearCache(String ownerUid);
}

class SqfliteChatroomMessageStorage implements ChatroomMessageStorage {
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final databasePath = await getDatabasesPath();
    final db = await openDatabase(
      '$databasePath/genesis_chatroom_messages.db',
      version: 3,
      onCreate: (db, _) async {
        await db.execute(_createChatroomMessagesSql);
        await db.execute(_createChatroomMessagesIndexSql);
        await db.execute(_createChatroomMessagesLocationUniqueSql);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE chatroom_messages '
            'ADD COLUMN global_msg_id INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE chatroom_messages '
            'ADD COLUMN location_msg_id INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 3) {
          await db.execute(_createChatroomMessagesIndexSql);
          await db.execute(_createChatroomMessagesLocationUniqueSql);
        }
      },
    );
    _database = db;
    return db;
  }

  @override
  Future<List<Map<String, dynamic>>> loadLatestMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int limit,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'chatroom_messages',
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [ownerUid, worldId, locationId],
      orderBy: _locationQueueOrderByDescending,
      limit: limit,
    );
    final messages = rows
        .map(_messageFromRow)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    return _sortMessageJson(messages);
  }

  @override
  Future<List<Map<String, dynamic>>> loadMessagesBefore({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int beforeMessageId,
    required int limit,
  }) async {
    if (beforeMessageId <= 0) return const <Map<String, dynamic>>[];
    final db = await _db;
    final rows = await db.query(
      'chatroom_messages',
      where:
          'owner_uid = ? AND world_id = ? AND location_id = ? '
          'AND $_locationQueueIdSql < ?',
      whereArgs: [ownerUid, worldId, locationId, beforeMessageId],
      orderBy: _locationQueueOrderByDescending,
      limit: limit,
    );
    final messages = rows
        .map(_messageFromRow)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    return _sortMessageJson(messages);
  }

  @override
  Future<void> mergeMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required List<Map<String, dynamic>> messages,
    int maxMessagesPerLocation = 200,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final message in messages) {
        await _insertMessage(txn, ownerUid, worldId, locationId, message);
      }
      await _pruneLocation(
        txn,
        ownerUid: ownerUid,
        worldId: worldId,
        locationId: locationId,
        maxMessages: maxMessagesPerLocation,
      );
    });
  }

  @override
  Future<void> upsertMessage({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required Map<String, dynamic> message,
    int maxMessagesPerLocation = 200,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _insertMessage(txn, ownerUid, worldId, locationId, message);
      await _pruneLocation(
        txn,
        ownerUid: ownerUid,
        worldId: worldId,
        locationId: locationId,
        maxMessages: maxMessagesPerLocation,
      );
    });
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    final db = await _db;
    await db.delete(
      'chatroom_messages',
      where: 'owner_uid = ?',
      whereArgs: [ownerUid],
    );
  }

  Future<void> _insertMessage(
    DatabaseExecutor executor,
    String ownerUid,
    String worldId,
    String locationId,
    Map<String, dynamic> message,
  ) async {
    final messageId = _messageId(message);
    final locationMessageId = _locationMessageId(message);
    final locationQueueMessageId = _locationQueueMessageId(message);
    final resolvedLocationId = locationId.trim().isNotEmpty
        ? locationId.trim()
        : asString(message['location_id']).trim();
    if (locationQueueMessageId <= 0 || resolvedLocationId.isEmpty) return;
    await executor.insert('chatroom_messages', {
      'owner_uid': ownerUid,
      'world_id': worldId,
      'location_id': resolvedLocationId,
      'global_msg_id': _globalMessageId(message),
      'msg_id': messageId,
      'location_msg_id': locationMessageId,
      'raw_json': jsonEncode(message),
      'created_at': _messageSortValue(message),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _pruneLocation(
    DatabaseExecutor executor, {
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int maxMessages,
  }) async {
    if (maxMessages <= 0) return;
    final rows = await executor.query(
      'chatroom_messages',
      columns: const ['msg_id', 'location_msg_id'],
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [ownerUid, worldId, locationId],
      orderBy: _locationQueueOrderByDescending,
      limit: 1000000,
      offset: maxMessages,
    );
    for (final row in rows) {
      await executor.delete(
        'chatroom_messages',
        where:
            'owner_uid = ? AND world_id = ? AND location_id = ? '
            'AND location_msg_id = ? AND msg_id = ?',
        whereArgs: [
          ownerUid,
          worldId,
          locationId,
          row['location_msg_id'],
          row['msg_id'],
        ],
      );
    }
  }
}

class MemoryChatroomMessageStorage implements ChatroomMessageStorage {
  final Map<String, Map<int, Map<String, dynamic>>> _messages = {};

  @override
  Future<List<Map<String, dynamic>>> loadLatestMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int limit,
  }) async {
    final descending = _sortMessageJson(
      _bucket(ownerUid, worldId, locationId).values,
    ).reversed.toList(growable: false);
    final messages = _sortMessageJson(descending.take(limit));
    return messages;
  }

  @override
  Future<List<Map<String, dynamic>>> loadMessagesBefore({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int beforeMessageId,
    required int limit,
  }) async {
    if (beforeMessageId <= 0) return const <Map<String, dynamic>>[];
    final descending = _sortMessageJson(
      _bucket(ownerUid, worldId, locationId).values.where(
        (message) => _locationQueueMessageId(message) < beforeMessageId,
      ),
    ).reversed.toList(growable: false);
    final messages = _sortMessageJson(descending.take(limit));
    return messages;
  }

  @override
  Future<void> mergeMessages({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required List<Map<String, dynamic>> messages,
    int maxMessagesPerLocation = 200,
  }) async {
    final bucket = _bucket(ownerUid, worldId, locationId);
    for (final message in messages) {
      final queueMessageId = _locationQueueMessageId(message);
      if (queueMessageId <= 0) continue;
      bucket[queueMessageId] = Map<String, dynamic>.from(message);
    }
    _prune(bucket, maxMessagesPerLocation);
  }

  @override
  Future<void> upsertMessage({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required Map<String, dynamic> message,
    int maxMessagesPerLocation = 200,
  }) async {
    final queueMessageId = _locationQueueMessageId(message);
    if (queueMessageId <= 0) return;
    final bucket = _bucket(ownerUid, worldId, locationId);
    bucket[queueMessageId] = Map<String, dynamic>.from(message);
    _prune(bucket, maxMessagesPerLocation);
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    _messages.removeWhere((key, _) => key.startsWith('$ownerUid\u001F'));
  }

  Map<int, Map<String, dynamic>> _bucket(
    String ownerUid,
    String worldId,
    String locationId,
  ) {
    return _messages.putIfAbsent(
      '$ownerUid\u001F$worldId\u001F$locationId',
      () => <int, Map<String, dynamic>>{},
    );
  }

  void _prune(Map<int, Map<String, dynamic>> bucket, int maxMessages) {
    if (maxMessages <= 0 || bucket.length <= maxMessages) return;
    final keep = _sortMessageJson(
      bucket.values,
    ).reversed.take(maxMessages).map(_locationQueueMessageId).toSet();
    bucket.removeWhere((queueMessageId, _) => !keep.contains(queueMessageId));
  }
}

const _createChatroomMessagesSql = '''
  CREATE TABLE IF NOT EXISTS chatroom_messages (
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

const _createChatroomMessagesIndexSql = '''
  CREATE INDEX IF NOT EXISTS idx_chatroom_messages_location_created
  ON chatroom_messages(owner_uid, world_id, location_id, location_msg_id, msg_id)
''';

const _createChatroomMessagesLocationUniqueSql = '''
  CREATE UNIQUE INDEX IF NOT EXISTS idx_chatroom_messages_location_msg
  ON chatroom_messages(owner_uid, world_id, location_id, location_msg_id)
  WHERE location_msg_id > 0
''';

const _locationQueueIdSql = '''
  CASE WHEN location_msg_id > 0 THEN location_msg_id ELSE msg_id END
''';

const _locationQueueOrderByDescending =
    '$_locationQueueIdSql DESC, msg_id DESC';

Map<String, dynamic>? _messageFromRow(Map<String, Object?> row) {
  try {
    final message = asJsonMap(jsonDecode('${row['raw_json']}'));
    message.putIfAbsent('global_msg_id', () => asInt(row['global_msg_id']));
    message.putIfAbsent('location_msg_id', () => asInt(row['location_msg_id']));
    return message;
  } catch (_) {
    return null;
  }
}

List<Map<String, dynamic>> _sortMessageJson(
  Iterable<Map<String, dynamic>> messages,
) {
  final sorted = messages
      .map((message) => Map<String, dynamic>.from(message))
      .toList(growable: false);
  sorted.sort((a, b) {
    final byLocationMessage = _locationQueueMessageId(
      a,
    ).compareTo(_locationQueueMessageId(b));
    if (byLocationMessage != 0) return byLocationMessage;
    return _messageId(a).compareTo(_messageId(b));
  });
  return sorted;
}

int _messageId(Map<String, dynamic> message) {
  return asInt(message['msg_id'], fallback: asInt(message['message_id']));
}

int _globalMessageId(Map<String, dynamic> message) {
  return asInt(
    message['global_msg_id'],
    fallback: asInt(message['global_message_id']),
  );
}

int _locationMessageId(Map<String, dynamic> message) {
  return asInt(
    message['location_msg_id'],
    fallback: asInt(message['location_message_id']),
  );
}

int _locationQueueMessageId(Map<String, dynamic> message) {
  final locationMessageId = _locationMessageId(message);
  return locationMessageId > 0 ? locationMessageId : _messageId(message);
}

int _messageSortValue(Map<String, dynamic> message) {
  final parsed = asDateTime(message['ts']) ?? asDateTime(message['created_at']);
  return parsed?.millisecondsSinceEpoch ?? _messageId(message);
}
