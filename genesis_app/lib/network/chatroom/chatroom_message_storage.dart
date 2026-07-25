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

  Future<void> deleteMessagesAtOrBefore({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int maxLocationMessageId,
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
    );
    final messages = rows
        .map(_messageFromRow)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final descending = _sortMessageJson(
      messages,
    ).reversed.toList(growable: false);
    return _sortMessageJson(descending.take(limit));
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
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [ownerUid, worldId, locationId],
    );
    final descending = _sortMessageJson(
      rows
          .map(_messageFromRow)
          .whereType<Map<String, dynamic>>()
          .where(
            (message) =>
                _messageIsBeforeLocationCursor(message, beforeMessageId),
          ),
    ).reversed.toList(growable: false);
    return _sortMessageJson(descending.take(limit));
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
  Future<void> deleteMessagesAtOrBefore({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int maxLocationMessageId,
  }) async {
    if (maxLocationMessageId <= 0) return;
    final db = await _db;
    final rows = await db.query(
      'chatroom_messages',
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [ownerUid, worldId, locationId],
    );
    for (final row in rows.where((row) {
      final message = _messageFromRow(row);
      return message != null &&
          _messageIsAtOrBeforeLocationCursor(message, maxLocationMessageId);
    })) {
      await db.delete(
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
    final resolvedLocationId = locationId.trim().isNotEmpty
        ? locationId.trim()
        : asString(message['location_id']).trim();
    if (messageId <= 0 || resolvedLocationId.isEmpty) return;
    final existingRows = await executor.query(
      'chatroom_messages',
      columns: const ['raw_json', 'global_msg_id', 'location_msg_id'],
      where: locationMessageId > 0
          ? 'owner_uid = ? AND world_id = ? AND location_id = ? AND location_msg_id = ?'
          : 'owner_uid = ? AND world_id = ? AND location_id = ? AND location_msg_id = 0 AND msg_id = ?',
      whereArgs: locationMessageId > 0
          ? [ownerUid, worldId, resolvedLocationId, locationMessageId]
          : [ownerUid, worldId, resolvedLocationId, messageId],
      limit: 1,
    );
    final existing = existingRows.isEmpty
        ? null
        : _messageFromRow(existingRows.first);
    final messageForStorage = _messageForStorage(
      _preservingLlmStreamFlag(message, existing),
      locationMessageId,
    );
    await executor.insert('chatroom_messages', {
      'owner_uid': ownerUid,
      'world_id': worldId,
      'location_id': resolvedLocationId,
      'global_msg_id': _globalMessageId(message),
      'msg_id': messageId,
      'location_msg_id': locationMessageId,
      'raw_json': jsonEncode(messageForStorage),
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
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [ownerUid, worldId, locationId],
      limit: 1000000,
    );
    final messages = rows
        .map(_messageFromRow)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final removeKeys = _sortMessageJson(
      messages,
    ).reversed.skip(maxMessages).map(_messageStorageKey).toSet();
    for (final row in rows.where((row) {
      return removeKeys.contains(_messageStorageKey(_messageFromRow(row)));
    })) {
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
  final Map<String, Map<String, Map<String, dynamic>>> _messages = {};

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
        (message) => _messageIsBeforeLocationCursor(message, beforeMessageId),
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
      if (_messageId(message) <= 0) continue;
      final key = _messageStorageKey(message);
      bucket[key] = _messageForStorage(
        _preservingLlmStreamFlag(message, bucket[key]),
        _locationMessageId(message),
      );
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
    if (_messageId(message) <= 0) return;
    final bucket = _bucket(ownerUid, worldId, locationId);
    final key = _messageStorageKey(message);
    bucket[key] = _messageForStorage(
      _preservingLlmStreamFlag(message, bucket[key]),
      _locationMessageId(message),
    );
    _prune(bucket, maxMessagesPerLocation);
  }

  @override
  Future<void> deleteMessagesAtOrBefore({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int maxLocationMessageId,
  }) async {
    if (maxLocationMessageId <= 0) return;
    final bucket = _bucket(ownerUid, worldId, locationId);
    bucket.removeWhere((_, message) {
      return _messageIsAtOrBeforeLocationCursor(message, maxLocationMessageId);
    });
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    _messages.removeWhere((key, _) => key.startsWith('$ownerUid\u001F'));
  }

  Map<String, Map<String, dynamic>> _bucket(
    String ownerUid,
    String worldId,
    String locationId,
  ) {
    return _messages.putIfAbsent(
      '$ownerUid\u001F$worldId\u001F$locationId',
      () => <String, Map<String, dynamic>>{},
    );
  }

  void _prune(Map<String, Map<String, dynamic>> bucket, int maxMessages) {
    if (maxMessages <= 0 || bucket.length <= maxMessages) return;
    final keep = _sortMessageJson(
      bucket.values,
    ).reversed.take(maxMessages).map(_messageStorageKey).toSet();
    bucket.removeWhere((key, _) => !keep.contains(key));
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

Map<String, dynamic>? _messageFromRow(Map<String, Object?> row) {
  try {
    final message = asJsonMap(jsonDecode('${row['raw_json']}'));
    message.putIfAbsent('global_msg_id', () => asInt(row['global_msg_id']));
    message['location_msg_id'] = asInt(row['location_msg_id']);
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
    final aIsTick = _isTickMessageJson(a);
    final bIsTick = _isTickMessageJson(b);
    if (aIsTick || bIsTick) {
      final byMessage = _messageId(a).compareTo(_messageId(b));
      if (byMessage != 0) return byMessage;
      final byLocation = _locationMessageId(a).compareTo(_locationMessageId(b));
      if (byLocation != 0) return byLocation;
    } else {
      final aHasLocationMessageId = _locationMessageId(a) > 0;
      final bHasLocationMessageId = _locationMessageId(b) > 0;
      if (aHasLocationMessageId && bHasLocationMessageId) {
        final byLocationMessage = _locationMessageId(
          a,
        ).compareTo(_locationMessageId(b));
        if (byLocationMessage != 0) return byLocationMessage;
      } else if (aHasLocationMessageId != bHasLocationMessageId) {
        return aHasLocationMessageId ? 1 : -1;
      }
    }
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

bool _isTickMessageJson(Map<String, dynamic> message) {
  return asString(message['sender_type']).trim().toLowerCase() == 'tick';
}

bool _messageIsBeforeLocationCursor(
  Map<String, dynamic> message,
  int beforeMessageId,
) {
  if (beforeMessageId <= 0) return false;
  if (_isTickMessageJson(message)) {
    return _messageId(message) > 0 && _messageId(message) < beforeMessageId;
  }
  final locationMessageId = _locationMessageId(message);
  if (locationMessageId <= 0) return true;
  return locationMessageId < beforeMessageId;
}

bool _messageIsAtOrBeforeLocationCursor(
  Map<String, dynamic> message,
  int maxLocationMessageId,
) {
  if (maxLocationMessageId <= 0) return false;
  if (_isTickMessageJson(message)) {
    return _messageId(message) > 0 &&
        _messageId(message) <= maxLocationMessageId;
  }
  final locationMessageId = _locationMessageId(message);
  if (locationMessageId <= 0) return true;
  return locationMessageId <= maxLocationMessageId;
}

String _messageStorageKey(Map<String, dynamic>? message) {
  if (message == null) return '';
  final locationMessageId = _locationMessageId(message);
  if (locationMessageId > 0) return 'location:$locationMessageId';
  return 'message:${_messageId(message)}';
}

Map<String, dynamic> _messageForStorage(
  Map<String, dynamic> message,
  int locationMessageId,
) {
  return Map<String, dynamic>.from(message)
    ..['location_msg_id'] = locationMessageId;
}

Map<String, dynamic> _preservingLlmStreamFlag(
  Map<String, dynamic> incoming,
  Map<String, dynamic>? existing,
) {
  if (asBool(existing?['is_llm_stream']) &&
      !asBool(incoming['is_llm_stream'])) {
    return <String, dynamic>{...incoming, 'is_llm_stream': true};
  }
  return incoming;
}

int _messageSortValue(Map<String, dynamic> message) {
  final parsed = asDateTime(message['ts']) ?? asDateTime(message['created_at']);
  return parsed?.millisecondsSinceEpoch ?? _messageId(message);
}
