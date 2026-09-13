part of 'chatroom_message_storage.dart';

// Companions of formal history: no wall-clock expiration and no message cursors.
Future<void> _createReplySnapshotTables(DatabaseExecutor db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS chatroom_reply_snapshots (
    owner_uid TEXT NOT NULL, world_id TEXT NOT NULL, location_id TEXT NOT NULL,
    round_id INTEGER NOT NULL, value TEXT NOT NULL,
    PRIMARY KEY (owner_uid, world_id, location_id, round_id))''');
  await db.execute('''CREATE TABLE IF NOT EXISTS chatroom_reply_migrations (
    owner_uid TEXT NOT NULL, world_id TEXT NOT NULL, location_id TEXT NOT NULL,
    PRIMARY KEY (owner_uid, world_id, location_id))''');
}

Map<String, dynamic> _copyReplyJson(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

bool _replySourceMatchesStoredMessages(
  Map<String, dynamic> value,
  Iterable<Map<String, dynamic>> messages,
  int round,
) {
  final source = value['source_messages'];
  if (source is! Map) return true;
  for (final message in messages) {
    if (asInt(message['conversation_round_id']) != round) continue;
    final id = asInt(message['global_msg_id'] ?? message['global_message_id']);
    if (id <= 0) continue;
    if (!source.containsKey('$id') || source['$id'] != message['content']) {
      return false;
    }
  }
  return true;
}

mixin _SqliteReplySnapshots {
  Future<Database> get _db;

  Future<Set<int>> _storedReplyRounds(
    DatabaseExecutor db,
    String owner,
    String world,
    String location,
  ) async {
    final rows = await db.query(
      'chatroom_messages',
      columns: ['raw_json'],
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [owner, world, location],
    );
    return {
      for (final row in rows)
        if (_messageFromRow(row) case final message?)
          if (asInt(message['conversation_round_id']) > 0)
            asInt(message['conversation_round_id']),
    };
  }

  Future<void> _pruneReplySnapshots(
    DatabaseExecutor db,
    String owner,
    String world,
    String location,
  ) async {
    final rounds = await _storedReplyRounds(db, owner, world, location);
    final rows = await db.query(
      'chatroom_reply_snapshots',
      columns: ['round_id'],
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [owner, world, location],
    );
    for (final row in rows) {
      if (rounds.contains(row['round_id'])) continue;
      await db.delete(
        'chatroom_reply_snapshots',
        where:
            'owner_uid = ? AND world_id = ? AND location_id = ? AND round_id = ?',
        whereArgs: [owner, world, location, row['round_id']],
      );
    }
  }

  Future<void> _markReplySnapshotsStale(
    DatabaseExecutor db,
    String owner,
    String world,
    String location,
    int? start,
    int? end,
  ) async {
    final rows = await db.query(
      'chatroom_reply_snapshots',
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [owner, world, location],
    );
    for (final row in rows) {
      final round = row['round_id'] as int;
      if (start != null && (round < start || round > end!)) continue;
      final value = _decodeReplySnapshot(row['value']);
      if (value == null) continue;
      value['needs_refresh'] = true;
      await db.update(
        'chatroom_reply_snapshots',
        {'value': jsonEncode(value)},
        where:
            'owner_uid = ? AND world_id = ? AND location_id = ? AND round_id = ?',
        whereArgs: [owner, world, location, round],
      );
    }
  }

  Future<List<Map<String, dynamic>>> loadReplySnapshots({
    required String ownerUid,
    required String worldId,
    required String locationId,
  }) async {
    final rows = await (await _db).query(
      'chatroom_reply_snapshots',
      where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
      whereArgs: [ownerUid, worldId, locationId],
      orderBy: 'round_id ASC',
    );
    return [
      for (final row in rows)
        if (_decodeReplySnapshot(row['value']) case final value?) value,
    ];
  }

  Future<void> saveReplySnapshot({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int roundId,
    required Map<String, dynamic> value,
    bool Function()? isCurrent,
  }) async {
    final frozen = jsonEncode(value);
    await (await _db).transaction((txn) async {
      if (isCurrent?.call() == false) return;
      final rounds = await _storedReplyRounds(
        txn,
        ownerUid,
        worldId,
        locationId,
      );
      if (!rounds.contains(roundId)) return;
      final messages = await txn.query(
        'chatroom_messages',
        columns: ['raw_json'],
        where: 'owner_uid = ? AND world_id = ? AND location_id = ?',
        whereArgs: [ownerUid, worldId, locationId],
      );
      if (!_replySourceMatchesStoredMessages(
        value,
        messages.map(_messageFromRow).whereType<Map<String, dynamic>>(),
        roundId,
      )) {
        return;
      }

      await txn.insert('chatroom_reply_snapshots', {
        'owner_uid': ownerUid,
        'world_id': worldId,
        'location_id': locationId,
        'round_id': roundId,
        'value': frozen,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (isCurrent?.call() == false) throw StateError('Stale reply snapshot');
    });
  }

  Future<void> importLegacyReplySnapshots({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required List<Map<String, dynamic>> values,
  }) async {
    await (await _db).transaction((txn) async {
      final markers = await txn.query(
        'chatroom_reply_migrations',
        where:
            'owner_uid = ? AND ((world_id = ? AND location_id = ?) OR (world_id = ? AND location_id = ?))',
        whereArgs: [ownerUid, worldId, locationId, '*', '*'],
      );
      if (markers.isNotEmpty) return;
      final rounds = await _storedReplyRounds(
        txn,
        ownerUid,
        worldId,
        locationId,
      );
      for (final value in values) {
        final round = asInt(value['round_id']);
        if (!rounds.contains(round) || value['cards_cache'] == null) continue;
        await txn.insert('chatroom_reply_snapshots', {
          'owner_uid': ownerUid,
          'world_id': worldId,
          'location_id': locationId,
          'round_id': round,
          'value': jsonEncode({...value, 'snapshot_version': 1}),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.insert('chatroom_reply_migrations', {
        'owner_uid': ownerUid,
        'world_id': worldId,
        'location_id': locationId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }
}

Map<String, dynamic>? _decodeReplySnapshot(Object? raw) {
  try {
    final value = jsonDecode(raw as String);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  } catch (_) {
    return null;
  }
}

mixin _MemoryReplySnapshots {
  final _replySnapshots = <String, Map<int, Map<String, dynamic>>>{};
  final _replyMigrations = <String>{};
  final _clearedReplyOwners = <String>{};
  Map<String, Map<String, dynamic>> _bucket(
    String owner,
    String world,
    String location,
  );
  String _replyKey(String owner, String world, String location) =>
      '$owner\u001F$world\u001F$location';
  Map<int, Map<String, dynamic>> _replyBucket(
    String owner,
    String world,
    String location,
  ) => _replySnapshots.putIfAbsent(_replyKey(owner, world, location), () => {});
  Set<int> _replyRounds(String owner, String world, String location) => {
    for (final message in _bucket(owner, world, location).values)
      if (asInt(message['conversation_round_id']) > 0)
        asInt(message['conversation_round_id']),
  };
  void _pruneReplies(String owner, String world, String location) {
    final rounds = _replyRounds(owner, world, location);
    _replyBucket(
      owner,
      world,
      location,
    ).removeWhere((round, _) => !rounds.contains(round));
  }

  Future<List<Map<String, dynamic>>> loadReplySnapshots({
    required String ownerUid,
    required String worldId,
    required String locationId,
  }) async => _replyBucket(
    ownerUid,
    worldId,
    locationId,
  ).values.map(_copyReplyJson).toList();
  Future<void> saveReplySnapshot({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required int roundId,
    required Map<String, dynamic> value,
    bool Function()? isCurrent,
  }) async {
    if (isCurrent?.call() == false ||
        !_replyRounds(ownerUid, worldId, locationId).contains(roundId)) {
      return;
    }
    if (!_replySourceMatchesStoredMessages(
      value,
      _bucket(ownerUid, worldId, locationId).values,
      roundId,
    )) {
      return;
    }
    _replyBucket(ownerUid, worldId, locationId)[roundId] = _copyReplyJson(
      value,
    );
  }

  Future<void> importLegacyReplySnapshots({
    required String ownerUid,
    required String worldId,
    required String locationId,
    required List<Map<String, dynamic>> values,
  }) async {
    if (_clearedReplyOwners.contains(ownerUid) ||
        !_replyMigrations.add(_replyKey(ownerUid, worldId, locationId))) {
      return;
    }
    final rounds = _replyRounds(ownerUid, worldId, locationId);
    final bucket = _replyBucket(ownerUid, worldId, locationId);
    for (final value in values) {
      final round = asInt(value['round_id']);
      if (!rounds.contains(round) || value['cards_cache'] == null) continue;
      bucket.putIfAbsent(
        round,
        () => _copyReplyJson({...value, 'snapshot_version': 1}),
      );
    }
  }
}
