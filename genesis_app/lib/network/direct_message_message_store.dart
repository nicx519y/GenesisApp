import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../platform/platform_services.dart';
import '../utils/relative_time_formatter.dart';
import 'genesis_api.dart';
import 'json_utils.dart';

class DirectMessageSendStatus {
  const DirectMessageSendStatus._();

  static const sending = 'sending';
  static const sent = 'sent';
  static const failed = 'failed';
}

class DirectMessageMessageRecord {
  DirectMessageMessageRecord({
    required this.messageId,
    required this.localId,
    required this.conversationId,
    required this.senderUid,
    required this.receiverUid,
    required this.content,
    required this.createdAt,
    required this.sortValue,
    required this.sendStatus,
    required this.rawJson,
  });

  factory DirectMessageMessageRecord.fromJson(
    Map<String, dynamic> json, {
    String? localId,
    String sendStatus = DirectMessageSendStatus.sent,
  }) {
    final messageId = asString(json['msg_id']);
    final createdAt =
        parseFlexibleTimestamp(json['created_at']) ?? DateTime.now();
    return DirectMessageMessageRecord(
      messageId: messageId,
      localId: localId?.trim().isNotEmpty == true ? localId!.trim() : messageId,
      conversationId: asString(json['conv_id']),
      senderUid: asString(json['sender_uid']),
      receiverUid: asString(json['receiver_uid']),
      content: asString(json['content']),
      createdAt: createdAt,
      sortValue: createdAt.millisecondsSinceEpoch,
      sendStatus: sendStatus,
      rawJson: jsonEncode(json),
    );
  }

  final String messageId;
  final String localId;
  final String conversationId;
  final String senderUid;
  final String receiverUid;
  final String content;
  final DateTime createdAt;
  final int sortValue;
  final String sendStatus;
  final String rawJson;

  Map<String, dynamic> toJson() => asJsonMap(jsonDecode(rawJson));
}

abstract class DirectMessageMessageStorage {
  Future<List<DirectMessageMessageRecord>> loadMessages({
    required String ownerUid,
    required String peerUid,
  });

  Future<void> mergeMessages({
    required String ownerUid,
    required String peerUid,
    required List<Map<String, dynamic>> messages,
  });

  Future<void> upsertRecord({
    required String ownerUid,
    required String peerUid,
    required DirectMessageMessageRecord record,
  });

  Future<void> replaceLocalMessage({
    required String ownerUid,
    required String peerUid,
    required String localMessageId,
    required Map<String, dynamic> serverMessage,
  });

  Future<void> deleteMessage({
    required String ownerUid,
    required String peerUid,
    required String messageId,
  });

  Future<void> clearCache(String ownerUid);
}

class SqfliteDirectMessageMessageStorage
    implements DirectMessageMessageStorage {
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;
    final databasePath = await getDatabasesPath();
    final db = await openDatabase(
      '$databasePath/genesis_direct_messages.db',
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS dm_conversations (
            owner_uid TEXT NOT NULL,
            conv_id TEXT NOT NULL,
            raw_json TEXT NOT NULL,
            sort_value INTEGER NOT NULL,
            PRIMARY KEY(owner_uid, conv_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS dm_sync_meta (
            owner_uid TEXT NOT NULL,
            key TEXT NOT NULL,
            value TEXT NOT NULL,
            PRIMARY KEY(owner_uid, key)
          )
        ''');
        await db.execute(_createDmMessagesSql);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) {
          await db.execute(_createDmMessagesSql);
        }
      },
    );
    _database = db;
    return db;
  }

  @override
  Future<List<DirectMessageMessageRecord>> loadMessages({
    required String ownerUid,
    required String peerUid,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'dm_messages',
      where: 'owner_uid = ? AND peer_uid = ?',
      whereArgs: [ownerUid, peerUid],
      orderBy: 'created_at ASC',
    );
    return rows
        .map(_recordFromRow)
        .whereType<DirectMessageMessageRecord>()
        .toList(growable: false);
  }

  @override
  Future<void> mergeMessages({
    required String ownerUid,
    required String peerUid,
    required List<Map<String, dynamic>> messages,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final json in messages) {
        final record = DirectMessageMessageRecord.fromJson(json);
        if (record.messageId.isEmpty) continue;
        await _insertRecord(txn, ownerUid, peerUid, record);
      }
    });
  }

  @override
  Future<void> upsertRecord({
    required String ownerUid,
    required String peerUid,
    required DirectMessageMessageRecord record,
  }) async {
    final db = await _db;
    await _insertRecord(db, ownerUid, peerUid, record);
  }

  @override
  Future<void> replaceLocalMessage({
    required String ownerUid,
    required String peerUid,
    required String localMessageId,
    required Map<String, dynamic> serverMessage,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final record = DirectMessageMessageRecord.fromJson(serverMessage);
      if (record.messageId.isEmpty) return;
      await txn.delete(
        'dm_messages',
        where: 'owner_uid = ? AND peer_uid = ? AND msg_id = ? AND msg_id <> ?',
        whereArgs: [ownerUid, peerUid, record.messageId, localMessageId],
      );
      final updated = await txn.update(
        'dm_messages',
        {
          'msg_id': record.messageId,
          'local_id': localMessageId,
          'raw_json': record.rawJson,
          'created_at': record.sortValue,
          'send_status': DirectMessageSendStatus.sent,
        },
        where: 'owner_uid = ? AND peer_uid = ? AND msg_id = ?',
        whereArgs: [ownerUid, peerUid, localMessageId],
      );
      if (updated == 0) {
        await _insertRecord(txn, ownerUid, peerUid, record);
      }
    });
  }

  @override
  Future<void> deleteMessage({
    required String ownerUid,
    required String peerUid,
    required String messageId,
  }) async {
    final db = await _db;
    await db.delete(
      'dm_messages',
      where: 'owner_uid = ? AND peer_uid = ? AND msg_id = ?',
      whereArgs: [ownerUid, peerUid, messageId],
    );
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    final db = await _db;
    await db.delete(
      'dm_messages',
      where: 'owner_uid = ?',
      whereArgs: [ownerUid],
    );
  }

  Future<void> _insertRecord(
    DatabaseExecutor executor,
    String ownerUid,
    String peerUid,
    DirectMessageMessageRecord record,
  ) {
    return executor.insert('dm_messages', {
      'owner_uid': ownerUid,
      'peer_uid': peerUid,
      'msg_id': record.messageId,
      'local_id': record.localId,
      'raw_json': record.rawJson,
      'created_at': record.sortValue,
      'send_status': record.sendStatus,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class MemoryDirectMessageMessageStorage implements DirectMessageMessageStorage {
  final Map<String, Map<String, DirectMessageMessageRecord>> _records = {};

  @override
  Future<List<DirectMessageMessageRecord>> loadMessages({
    required String ownerUid,
    required String peerUid,
  }) async {
    return _sorted(_bucket(ownerUid, peerUid).values);
  }

  @override
  Future<void> mergeMessages({
    required String ownerUid,
    required String peerUid,
    required List<Map<String, dynamic>> messages,
  }) async {
    final bucket = _bucket(ownerUid, peerUid);
    for (final json in messages) {
      final record = DirectMessageMessageRecord.fromJson(json);
      if (record.messageId.isEmpty) continue;
      bucket[record.messageId] = record;
    }
  }

  @override
  Future<void> upsertRecord({
    required String ownerUid,
    required String peerUid,
    required DirectMessageMessageRecord record,
  }) async {
    _bucket(ownerUid, peerUid)[record.messageId] = record;
  }

  @override
  Future<void> replaceLocalMessage({
    required String ownerUid,
    required String peerUid,
    required String localMessageId,
    required Map<String, dynamic> serverMessage,
  }) async {
    final bucket = _bucket(ownerUid, peerUid);
    final record = DirectMessageMessageRecord.fromJson(serverMessage);
    if (record.messageId.isEmpty) return;
    bucket.remove(record.messageId);
    final existing = bucket.remove(localMessageId);
    bucket[record.messageId] = DirectMessageMessageRecord.fromJson(
      serverMessage,
      localId: existing?.localId ?? record.localId,
      sendStatus: DirectMessageSendStatus.sent,
    );
  }

  @override
  Future<void> deleteMessage({
    required String ownerUid,
    required String peerUid,
    required String messageId,
  }) async {
    _bucket(ownerUid, peerUid).remove(messageId);
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    _records.removeWhere((key, _) => key.startsWith('$ownerUid\u001F'));
  }

  Map<String, DirectMessageMessageRecord> _bucket(
    String ownerUid,
    String peerUid,
  ) {
    return _records.putIfAbsent(
      '$ownerUid\u001F$peerUid',
      () => <String, DirectMessageMessageRecord>{},
    );
  }
}

class DirectMessageMessageStore {
  DirectMessageMessageStore({
    required GenesisApi api,
    required UserSessionStore sessionStore,
    required DirectMessageMessageStorage storage,
  }) : _api = api,
       _sessionStore = sessionStore,
       _storage = storage;

  static const pageSize = 20;

  final GenesisApi _api;
  final UserSessionStore _sessionStore;
  final DirectMessageMessageStorage _storage;
  final ValueNotifier<List<String>> orderedMessageIds =
      ValueNotifier<List<String>>(const []);
  final Map<String, ValueNotifier<DirectMessageMessageRecord>> _rowNotifiers =
      {};

  String? _activeOwnerUid;
  String? _activePeerUid;
  int _nextOlderPage = 2;
  bool _hasMoreOlder = true;
  bool _loadingOlder = false;
  Future<void>? _syncFuture;

  bool get hasMoreOlder => _hasMoreOlder;

  ValueListenable<DirectMessageMessageRecord>? rowListenable(String messageId) {
    return _rowNotifiers[messageId];
  }

  Future<void> loadFromDb(String peerUid) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    _resetIfTargetChanged(ownerUid, cleanPeerUid);
    _applyRecords(
      await _storage.loadMessages(ownerUid: ownerUid, peerUid: cleanPeerUid),
    );
  }

  Future<void> syncLatest(String peerUid) {
    final inFlight = _syncFuture;
    if (inFlight != null) return inFlight;
    final future = _syncLatest(peerUid);
    _syncFuture = future.whenComplete(() => _syncFuture = null);
    return _syncFuture!;
  }

  Future<void> loadOlder(String peerUid) async {
    if (_loadingOlder || !_hasMoreOlder) return;
    _loadingOlder = true;
    try {
      final ownerUid = await _ownerUid();
      final cleanPeerUid = peerUid.trim();
      _resetIfTargetChanged(ownerUid, cleanPeerUid);
      final page = _nextOlderPage;
      final data = await _api.v1.dm.list(
        peerUid: cleanPeerUid,
        pn: page,
        rn: pageSize,
      );
      final messages = _messageItems(data);
      await _storage.mergeMessages(
        ownerUid: ownerUid,
        peerUid: cleanPeerUid,
        messages: messages,
      );
      _nextOlderPage = page + 1;
      _hasMoreOlder = _hasNextPage(data, page, messages.length);
      _applyRecords(
        await _storage.loadMessages(ownerUid: ownerUid, peerUid: cleanPeerUid),
      );
    } finally {
      _loadingOlder = false;
    }
  }

  Future<String> insertLocalMessage({
    required String peerUid,
    required String senderUid,
    required String content,
  }) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    _resetIfTargetChanged(ownerUid, cleanPeerUid);
    final localId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc();
    final json = {
      'msg_id': localId,
      'conv_id': '',
      'sender_uid': senderUid,
      'receiver_uid': cleanPeerUid,
      'content': content,
      'created_at': now.millisecondsSinceEpoch ~/ 1000,
    };
    final record = DirectMessageMessageRecord.fromJson(
      json,
      localId: localId,
      sendStatus: DirectMessageSendStatus.sending,
    );
    await _storage.upsertRecord(
      ownerUid: ownerUid,
      peerUid: cleanPeerUid,
      record: record,
    );
    _applyRecords(
      await _storage.loadMessages(ownerUid: ownerUid, peerUid: cleanPeerUid),
    );
    return localId;
  }

  Future<void> replaceLocalMessage({
    required String peerUid,
    required String localMessageId,
    required Map<String, dynamic> serverMessage,
  }) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    _resetIfTargetChanged(ownerUid, cleanPeerUid);
    await _storage.replaceLocalMessage(
      ownerUid: ownerUid,
      peerUid: cleanPeerUid,
      localMessageId: localMessageId,
      serverMessage: serverMessage,
    );
    _applyRecords(
      await _storage.loadMessages(ownerUid: ownerUid, peerUid: cleanPeerUid),
    );
  }

  Future<void> deleteMessage({
    required String peerUid,
    required String messageId,
  }) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    _resetIfTargetChanged(ownerUid, cleanPeerUid);
    await _storage.deleteMessage(
      ownerUid: ownerUid,
      peerUid: cleanPeerUid,
      messageId: messageId,
    );
    _applyRecords(
      await _storage.loadMessages(ownerUid: ownerUid, peerUid: cleanPeerUid),
    );
  }

  Future<void> clearCache() async {
    final ownerUid = await _ownerUid();
    await _storage.clearCache(ownerUid);
    if (_activeOwnerUid == null || _activeOwnerUid == ownerUid) {
      _activeOwnerUid = ownerUid;
      _activePeerUid = null;
      _nextOlderPage = 2;
      _hasMoreOlder = true;
      _rowNotifiers.clear();
      if (orderedMessageIds.value.isNotEmpty) {
        orderedMessageIds.value = const [];
      }
    }
  }

  Future<void> _syncLatest(String peerUid) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    _resetIfTargetChanged(ownerUid, cleanPeerUid);
    final data = await _api.v1.dm.list(
      peerUid: cleanPeerUid,
      pn: 1,
      rn: pageSize,
    );
    final messages = _messageItems(data);
    await _storage.mergeMessages(
      ownerUid: ownerUid,
      peerUid: cleanPeerUid,
      messages: messages,
    );
    _hasMoreOlder = _hasNextPage(data, 1, messages.length);
    _nextOlderPage = 2;
    _applyRecords(
      await _storage.loadMessages(ownerUid: ownerUid, peerUid: cleanPeerUid),
    );
  }

  void _applyRecords(List<DirectMessageMessageRecord> records) {
    final sorted = _sorted(records);
    final nextIds = sorted.map((record) => record.messageId).toList();
    for (final record in sorted) {
      final existing = _rowNotifiers[record.messageId];
      if (existing == null) {
        _rowNotifiers[record.messageId] =
            ValueNotifier<DirectMessageMessageRecord>(record);
      } else if (!_sameRecord(existing.value, record)) {
        existing.value = record;
      }
    }
    final liveIds = nextIds.toSet();
    _rowNotifiers.removeWhere((id, _) => !liveIds.contains(id));
    if (!_sameIds(orderedMessageIds.value, nextIds)) {
      orderedMessageIds.value = List.unmodifiable(nextIds);
    }
  }

  Future<String> _ownerUid() async {
    final uid = (await _sessionStore.readUid())?.trim();
    return uid == null || uid.isEmpty ? '__anonymous__' : uid;
  }

  void _resetIfTargetChanged(String ownerUid, String peerUid) {
    if (_activeOwnerUid == ownerUid && _activePeerUid == peerUid) return;
    _activeOwnerUid = ownerUid;
    _activePeerUid = peerUid;
    _nextOlderPage = 2;
    _hasMoreOlder = true;
    _rowNotifiers.clear();
    orderedMessageIds.value = const [];
  }
}

const _createDmMessagesSql = '''
  CREATE TABLE IF NOT EXISTS dm_messages (
    owner_uid TEXT NOT NULL,
    peer_uid TEXT NOT NULL,
    msg_id TEXT NOT NULL,
    local_id TEXT NOT NULL,
    raw_json TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    send_status TEXT NOT NULL,
    PRIMARY KEY(owner_uid, peer_uid, msg_id)
  )
''';

List<DirectMessageMessageRecord> _sorted(
  Iterable<DirectMessageMessageRecord> records,
) {
  final sorted = records.toList(growable: false);
  sorted.sort((a, b) {
    final byTime = a.sortValue.compareTo(b.sortValue);
    if (byTime != 0) return byTime;
    return a.messageId.compareTo(b.messageId);
  });
  return sorted;
}

List<Map<String, dynamic>> _messageItems(Map<String, dynamic> data) {
  final rawItems = data['list'] is List
      ? asJsonList(data['list'])
      : const <Object?>[];
  return rawItems.map((item) => asJsonMap(item)).toList(growable: false);
}

bool _hasNextPage(Map<String, dynamic> data, int page, int itemCount) {
  final total = asInt(data['total'], fallback: -1);
  if (total >= 0) return page * DirectMessageMessageStore.pageSize < total;
  return itemCount >= DirectMessageMessageStore.pageSize;
}

DirectMessageMessageRecord? _recordFromRow(Map<String, Object?> row) {
  try {
    return DirectMessageMessageRecord.fromJson(
      asJsonMap(jsonDecode('${row['raw_json']}')),
      localId: asString(row['local_id']),
      sendStatus: asString(
        row['send_status'],
        fallback: DirectMessageSendStatus.sent,
      ),
    );
  } catch (_) {
    return null;
  }
}

bool _sameRecord(
  DirectMessageMessageRecord previous,
  DirectMessageMessageRecord next,
) {
  return previous.rawJson == next.rawJson &&
      previous.localId == next.localId &&
      previous.sortValue == next.sortValue &&
      previous.sendStatus == next.sendStatus;
}

bool _sameIds(List<String> previous, List<String> next) {
  if (previous.length != next.length) return false;
  for (var index = 0; index < previous.length; index += 1) {
    if (previous[index] != next[index]) return false;
  }
  return true;
}
