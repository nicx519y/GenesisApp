import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'mini_phone_cache.dart';
import 'mini_phone_models.dart';

abstract class MiniPhoneCacheStorage {
  Future<MiniPhoneCache> load(MiniPhoneCacheScope scope);
  Future<void> save(MiniPhoneCacheScope scope, Map<String, dynamic> snapshot);
  Future<List<PhoneMessage>> loadBefore(
    MiniPhoneCacheScope scope,
    int sessionId,
    int beforeId,
    int limit,
  );
}

class SqliteMiniPhoneCacheStorage implements MiniPhoneCacheStorage {
  SqliteMiniPhoneCacheStorage({DatabaseFactory? factory, this.path})
    : _factory = factory;
  static final instance = SqliteMiniPhoneCacheStorage();
  final DatabaseFactory? _factory;
  final String? path;
  Future<Database>? _opening;

  Future<Database> get _database => _opening ??= _open().catchError((Object e) {
    _opening = null;
    throw e;
  });

  Future<Database> _open() async {
    final factory = _factory ?? databaseFactory;
    final file =
        path ?? '${await factory.getDatabasesPath()}/genesis_mini_phone.db';
    return factory.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE phone_messages (
          scope TEXT NOT NULL, message_id INTEGER NOT NULL,
          session_id INTEGER NOT NULL, raw_json TEXT NOT NULL,
          unread_revision INTEGER,
          PRIMARY KEY(scope, message_id))''');
          await db.execute('''CREATE INDEX phone_history
          ON phone_messages(scope, session_id, message_id)''');
          await db.execute('''CREATE INDEX phone_unread
          ON phone_messages(scope, unread_revision, message_id)''');
          await db.execute('''CREATE TABLE phone_sessions (
          scope TEXT NOT NULL, char_id TEXT NOT NULL, position INTEGER NOT NULL,
          raw_json TEXT NOT NULL, PRIMARY KEY(scope, char_id))''');
          await db.execute('''CREATE TABLE phone_sync (
          scope TEXT PRIMARY KEY, raw_json TEXT NOT NULL)''');
          await db.execute('''CREATE TABLE phone_pending_reads (
          scope TEXT NOT NULL, session_id INTEGER NOT NULL,
          revision INTEGER NOT NULL, through_id INTEGER NOT NULL,
          PRIMARY KEY(scope, session_id))''');
        },
      ),
    );
  }

  @override
  Future<MiniPhoneCache> load(MiniPhoneCacheScope scope) async {
    final db = await _database;
    return db.transaction((tx) async {
      final meta = await tx.query(
        'phone_sync',
        where: 'scope = ?',
        whereArgs: [scope.key],
      );
      final rows = await tx.query(
        'phone_messages',
        where: 'scope = ?',
        whereArgs: [scope.key],
      );
      final sessions = await tx.query(
        'phone_sessions',
        where: 'scope = ?',
        whereArgs: [scope.key],
        orderBy: 'position ASC',
      );
      final reads = await tx.query(
        'phone_pending_reads',
        where: 'scope = ?',
        whereArgs: [scope.key],
      );
      return MiniPhoneCache.fromJson({
        if (meta.isNotEmpty)
          ...phoneMap(jsonDecode(meta.single['raw_json'] as String)),
        'messages': [
          for (final row in rows) jsonDecode(row['raw_json'] as String),
        ],
        'sessions': [
          for (final row in sessions) jsonDecode(row['raw_json'] as String),
        ],
        'unread': {
          for (final row in rows)
            if (row['unread_revision'] != null)
              '${row['message_id']}': row['unread_revision'],
        },
        'pending_reads': {
          for (final row in reads)
            '${row['session_id']}': {
              'revision': row['revision'],
              'through_id': row['through_id'],
            },
        },
      });
    });
  }

  @override
  Future<void> save(
    MiniPhoneCacheScope scope,
    Map<String, dynamic> snapshot,
  ) async {
    final db = await _database;
    await db.transaction((tx) async {
      final existing = {
        for (final row in await tx.query(
          'phone_messages',
          where: 'scope = ?',
          whereArgs: [scope.key],
        ))
          row['message_id'] as int: row,
      };
      final unread = phoneMap(snapshot['unread']);
      final batch = tx.batch();
      for (final item in snapshot['messages'] as List) {
        final m = phoneMap(item), id = m['message_id'] as int;
        final encoded = jsonEncode(m), stamp = unread['$id'];
        final old = existing.remove(id);
        if (old?['raw_json'] == encoded && old?['unread_revision'] == stamp) {
          continue;
        }
        batch.insert('phone_messages', {
          'scope': scope.key,
          'message_id': id,
          'session_id': m['dm_session_id'],
          'raw_json': encoded,
          'unread_revision': stamp,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final id in existing.keys) {
        batch.delete(
          'phone_messages',
          where: 'scope = ? AND message_id = ?',
          whereArgs: [scope.key, id],
        );
      }
      batch.delete(
        'phone_sessions',
        where: 'scope = ?',
        whereArgs: [scope.key],
      );
      final sessions = snapshot['sessions'] as List;
      for (var i = 0; i < sessions.length; i++) {
        final s = phoneMap(sessions[i]);
        batch.insert('phone_sessions', {
          'scope': scope.key,
          'char_id': s['char_id'],
          'position': i,
          'raw_json': jsonEncode(s),
        });
      }
      batch.delete(
        'phone_pending_reads',
        where: 'scope = ?',
        whereArgs: [scope.key],
      );
      for (final e in phoneMap(snapshot['pending_reads']).entries) {
        batch.insert('phone_pending_reads', {
          'scope': scope.key,
          'session_id': int.parse(e.key),
          ...phoneMap(e.value),
        });
      }
      final meta = Map<String, dynamic>.of(snapshot)
        ..remove('messages')
        ..remove('sessions')
        ..remove('unread')
        ..remove('pending_reads');
      batch.insert('phone_sync', {
        'scope': scope.key,
        'raw_json': jsonEncode(meta),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<PhoneMessage>> loadBefore(
    MiniPhoneCacheScope scope,
    int sessionId,
    int beforeId,
    int limit,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'phone_messages',
      where: 'scope = ? AND session_id = ? AND message_id < ?',
      whereArgs: [scope.key, sessionId, beforeId],
      orderBy: 'message_id DESC',
      limit: limit,
    );
    return [
      for (final row in rows)
        PhoneMessage.fromJson(phoneMap(jsonDecode(row['raw_json'] as String))),
    ];
  }

  Future<void> close() async {
    final opening = _opening;
    _opening = null;
    if (opening != null) await (await opening).close();
  }
}
