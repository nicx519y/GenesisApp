import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../platform/platform_services.dart';
import '../utils/genesis_timestamp_formatter.dart';
import 'direct_message_database.dart';
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

class DirectMessageMessagePage {
  const DirectMessageMessagePage({
    required this.records,
    required this.hasMoreBefore,
  });

  final List<DirectMessageMessageRecord> records;
  final bool hasMoreBefore;
}

abstract class DirectMessageMessageStorage {
  Future<List<DirectMessageMessageRecord>> loadMessages({
    required String ownerUid,
    required String peerUid,
  });

  Future<DirectMessageMessagePage> loadLatestMessages({
    required String ownerUid,
    required String peerUid,
    required int limit,
  });

  Future<DirectMessageMessagePage> loadMessagesBefore({
    required String ownerUid,
    required String peerUid,
    required int beforeSortValue,
    required String beforeMessageId,
    required int limit,
  });

  Future<String> loadDraft({required String ownerUid, required String peerUid});

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

  Future<void> saveDraft({
    required String ownerUid,
    required String peerUid,
    required String content,
  });

  Future<void> clearDraft({required String ownerUid, required String peerUid});

  Future<void> clearCache(String ownerUid);
}

class SqfliteDirectMessageMessageStorage
    implements DirectMessageMessageStorage {
  SqfliteDirectMessageMessageStorage({
    DirectMessageDatabaseProvider? databaseProvider,
  }) : _databaseProvider =
           databaseProvider ?? DirectMessageDatabaseProvider.instance;

  final DirectMessageDatabaseProvider _databaseProvider;

  Future<Database> get _db => _databaseProvider.database;

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
  Future<DirectMessageMessagePage> loadLatestMessages({
    required String ownerUid,
    required String peerUid,
    required int limit,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'dm_messages',
      where: 'owner_uid = ? AND peer_uid = ?',
      whereArgs: [ownerUid, peerUid],
      orderBy: 'created_at DESC, msg_id DESC',
      limit: limit + 1,
    );
    return _pageFromRows(rows, limit);
  }

  @override
  Future<DirectMessageMessagePage> loadMessagesBefore({
    required String ownerUid,
    required String peerUid,
    required int beforeSortValue,
    required String beforeMessageId,
    required int limit,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'dm_messages',
      where:
          'owner_uid = ? AND peer_uid = ? AND '
          '(created_at < ? OR (created_at = ? AND msg_id < ?))',
      whereArgs: [
        ownerUid,
        peerUid,
        beforeSortValue,
        beforeSortValue,
        beforeMessageId,
      ],
      orderBy: 'created_at DESC, msg_id DESC',
      limit: limit + 1,
    );
    return _pageFromRows(rows, limit);
  }

  @override
  Future<String> loadDraft({
    required String ownerUid,
    required String peerUid,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'dm_message_drafts',
      columns: const ['content'],
      where: 'owner_uid = ? AND peer_uid = ?',
      whereArgs: [ownerUid, peerUid],
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return '${rows.first['content'] ?? ''}';
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
  Future<void> saveDraft({
    required String ownerUid,
    required String peerUid,
    required String content,
  }) async {
    if (content.trim().isEmpty) {
      await clearDraft(ownerUid: ownerUid, peerUid: peerUid);
      return;
    }
    final db = await _db;
    await db.insert('dm_message_drafts', {
      'owner_uid': ownerUid,
      'peer_uid': peerUid,
      'content': content,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> clearDraft({
    required String ownerUid,
    required String peerUid,
  }) async {
    final db = await _db;
    await db.delete(
      'dm_message_drafts',
      where: 'owner_uid = ? AND peer_uid = ?',
      whereArgs: [ownerUid, peerUid],
    );
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'dm_messages',
        where: 'owner_uid = ?',
        whereArgs: [ownerUid],
      );
      await txn.delete(
        'dm_message_drafts',
        where: 'owner_uid = ?',
        whereArgs: [ownerUid],
      );
    });
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

  DirectMessageMessagePage _pageFromRows(
    List<Map<String, Object?>> rows,
    int limit,
  ) {
    final records = rows
        .map(_recordFromRow)
        .whereType<DirectMessageMessageRecord>()
        .toList(growable: false);
    final pageRecords = records.take(limit).toList(growable: false);
    return DirectMessageMessagePage(
      records: _sorted(pageRecords),
      hasMoreBefore: records.length > limit,
    );
  }
}

class MemoryDirectMessageMessageStorage implements DirectMessageMessageStorage {
  final Map<String, Map<String, DirectMessageMessageRecord>> _records = {};
  final Map<String, String> _drafts = {};

  @override
  Future<List<DirectMessageMessageRecord>> loadMessages({
    required String ownerUid,
    required String peerUid,
  }) async {
    return _sorted(_bucket(ownerUid, peerUid).values);
  }

  @override
  Future<DirectMessageMessagePage> loadLatestMessages({
    required String ownerUid,
    required String peerUid,
    required int limit,
  }) async {
    final descending = _sorted(
      _bucket(ownerUid, peerUid).values,
    ).reversed.toList(growable: false);
    return _pageFromDescendingRecords(descending, limit);
  }

  @override
  Future<DirectMessageMessagePage> loadMessagesBefore({
    required String ownerUid,
    required String peerUid,
    required int beforeSortValue,
    required String beforeMessageId,
    required int limit,
  }) async {
    final descending = _sorted(_bucket(ownerUid, peerUid).values)
        .where(
          (record) =>
              record.sortValue < beforeSortValue ||
              (record.sortValue == beforeSortValue &&
                  record.messageId.compareTo(beforeMessageId) < 0),
        )
        .toList(growable: false)
        .reversed
        .toList(growable: false);
    return _pageFromDescendingRecords(descending, limit);
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
  Future<String> loadDraft({
    required String ownerUid,
    required String peerUid,
  }) async {
    return _drafts[_key(ownerUid, peerUid)] ?? '';
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
  Future<void> saveDraft({
    required String ownerUid,
    required String peerUid,
    required String content,
  }) async {
    final key = _key(ownerUid, peerUid);
    if (content.trim().isEmpty) {
      _drafts.remove(key);
      return;
    }
    _drafts[key] = content;
  }

  @override
  Future<void> clearDraft({
    required String ownerUid,
    required String peerUid,
  }) async {
    _drafts.remove(_key(ownerUid, peerUid));
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    _records.removeWhere((key, _) => key.startsWith('$ownerUid\u001F'));
    _drafts.removeWhere((key, _) => key.startsWith('$ownerUid\u001F'));
  }

  Map<String, DirectMessageMessageRecord> _bucket(
    String ownerUid,
    String peerUid,
  ) {
    return _records.putIfAbsent(
      _key(ownerUid, peerUid),
      () => <String, DirectMessageMessageRecord>{},
    );
  }

  String _key(String ownerUid, String peerUid) => '$ownerUid\u001F$peerUid';

  DirectMessageMessagePage _pageFromDescendingRecords(
    List<DirectMessageMessageRecord> records,
    int limit,
  ) {
    final pageRecords = records.take(limit).toList(growable: false);
    return DirectMessageMessagePage(
      records: _sorted(pageRecords),
      hasMoreBefore: records.length > limit,
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
  int _knownRemoteTotal = -1;
  bool _hasMoreLocalOlder = true;
  bool _hasMoreRemoteOlder = true;
  bool _loadingOlder = false;
  Future<void>? _syncFuture;
  String? _syncFutureOwnerUid;
  String? _syncFuturePeerUid;

  bool get hasMoreOlder => _hasMoreLocalOlder || _hasMoreRemoteOlder;

  ValueListenable<DirectMessageMessageRecord>? rowListenable(String messageId) {
    return _rowNotifiers[messageId];
  }

  Future<void> loadFromDb(String peerUid) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    _resetIfTargetChanged(ownerUid, cleanPeerUid);
    final page = await _storage.loadLatestMessages(
      ownerUid: ownerUid,
      peerUid: cleanPeerUid,
      limit: pageSize,
    );
    if (!_isActiveTarget(ownerUid, cleanPeerUid)) return;
    _hasMoreLocalOlder = page.hasMoreBefore;
    _hasMoreRemoteOlder = false;
    _nextOlderPage = 2;
    _knownRemoteTotal = -1;
    _applyRecords(page.records);
  }

  Future<String> loadDraft(String peerUid) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    return _storage.loadDraft(ownerUid: ownerUid, peerUid: cleanPeerUid);
  }

  Future<void> saveDraft({
    required String peerUid,
    required String content,
  }) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    if (cleanPeerUid.isEmpty) return;
    await _storage.saveDraft(
      ownerUid: ownerUid,
      peerUid: cleanPeerUid,
      content: content,
    );
  }

  Future<void> clearDraft(String peerUid) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    if (cleanPeerUid.isEmpty) return;
    await _storage.clearDraft(ownerUid: ownerUid, peerUid: cleanPeerUid);
  }

  Future<void> syncLatest(String peerUid) async {
    final ownerUid = await _ownerUid();
    final cleanPeerUid = peerUid.trim();
    final inFlight = _syncFuture;
    if (inFlight != null &&
        _syncFutureOwnerUid == ownerUid &&
        _syncFuturePeerUid == cleanPeerUid) {
      return inFlight;
    }
    _syncFutureOwnerUid = ownerUid;
    _syncFuturePeerUid = cleanPeerUid;
    final stopwatch = _dmMessageMetricsEnabled ? (Stopwatch()..start()) : null;
    late final Future<void> trackedFuture;
    trackedFuture = _syncLatest(ownerUid: ownerUid, peerUid: cleanPeerUid)
        .whenComplete(() {
          if (stopwatch != null) {
            debugPrint(
              '[ChatPage][DM] syncLatest peer=$cleanPeerUid '
              'elapsed=${stopwatch.elapsedMilliseconds}ms',
            );
          }
          if (identical(_syncFuture, trackedFuture)) {
            _syncFuture = null;
            _syncFutureOwnerUid = null;
            _syncFuturePeerUid = null;
          }
        });
    _syncFuture = trackedFuture;
    return trackedFuture;
  }

  Future<void> loadOlder(String peerUid) async {
    if (_loadingOlder || !hasMoreOlder) return;
    _loadingOlder = true;
    try {
      final ownerUid = await _ownerUid();
      final cleanPeerUid = peerUid.trim();
      _resetIfTargetChanged(ownerUid, cleanPeerUid);
      if (_hasMoreLocalOlder) {
        final earliest = _earliestVisibleRecord;
        if (earliest != null) {
          final page = await _storage.loadMessagesBefore(
            ownerUid: ownerUid,
            peerUid: cleanPeerUid,
            beforeSortValue: earliest.sortValue,
            beforeMessageId: earliest.messageId,
            limit: pageSize,
          );
          if (!_isActiveTarget(ownerUid, cleanPeerUid)) return;
          _hasMoreLocalOlder = page.hasMoreBefore;
          if (page.records.length >= pageSize) {
            _nextOlderPage += 1;
            _hasMoreRemoteOlder = _hasRemotePage(_nextOlderPage);
          }
          if (page.records.isNotEmpty) {
            _mergeVisibleRecords(page.records);
            return;
          }
        }
        _hasMoreLocalOlder = false;
      }
      if (!_hasMoreRemoteOlder) return;
      final page = _nextOlderPage;
      final data = await _api.v1.dm.list(
        peerUid: cleanPeerUid,
        pn: page,
        rn: pageSize,
      );
      final messages = _messageItems(
        data,
      ).take(pageSize).toList(growable: false);
      await _storage.mergeMessages(
        ownerUid: ownerUid,
        peerUid: cleanPeerUid,
        messages: messages,
      );
      if (!_isActiveTarget(ownerUid, cleanPeerUid)) return;
      _knownRemoteTotal = asInt(data['total'], fallback: -1);
      _nextOlderPage = page + 1;
      _hasMoreRemoteOlder = _hasNextPage(data, page, messages.length);
      _mergeVisibleRecords(_recordsFromMessages(messages));
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
    if (_isActiveTarget(ownerUid, cleanPeerUid)) {
      _mergeVisibleRecords([record]);
    }
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
    final record = DirectMessageMessageRecord.fromJson(
      serverMessage,
      localId: localMessageId,
      sendStatus: DirectMessageSendStatus.sent,
    );
    if (_isActiveTarget(ownerUid, cleanPeerUid) &&
        record.messageId.isNotEmpty) {
      _removeVisibleRecord(localMessageId);
      _mergeVisibleRecords([record]);
    }
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
    if (_isActiveTarget(ownerUid, cleanPeerUid)) {
      _removeVisibleRecord(messageId);
    }
  }

  Future<void> clearCache() async {
    final ownerUid = await _ownerUid();
    await _storage.clearCache(ownerUid);
    if (_activeOwnerUid == null || _activeOwnerUid == ownerUid) {
      _activeOwnerUid = ownerUid;
      _activePeerUid = null;
      _nextOlderPage = 2;
      _knownRemoteTotal = -1;
      _hasMoreLocalOlder = true;
      _hasMoreRemoteOlder = true;
      _rowNotifiers.clear();
      if (orderedMessageIds.value.isNotEmpty) {
        orderedMessageIds.value = const [];
      }
    }
  }

  Future<void> _syncLatest({
    required String ownerUid,
    required String peerUid,
  }) async {
    _resetIfTargetChanged(ownerUid, peerUid);
    final data = await _api.v1.dm.list(peerUid: peerUid, pn: 1, rn: pageSize);
    final messages = _messageItems(data).take(pageSize).toList(growable: false);
    await _storage.mergeMessages(
      ownerUid: ownerUid,
      peerUid: peerUid,
      messages: messages,
    );
    if (!_isActiveTarget(ownerUid, peerUid)) return;
    _knownRemoteTotal = asInt(data['total'], fallback: -1);
    _hasMoreRemoteOlder = _hasNextPage(data, 1, messages.length);
    final records = _recordsFromMessages(messages);
    if (orderedMessageIds.value.isEmpty) {
      final page = await _storage.loadLatestMessages(
        ownerUid: ownerUid,
        peerUid: peerUid,
        limit: pageSize,
      );
      if (!_isActiveTarget(ownerUid, peerUid)) return;
      _hasMoreLocalOlder = page.hasMoreBefore;
      _applyRecords(page.records);
      return;
    }
    _mergeVisibleRecords(records);
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

  void _mergeVisibleRecords(List<DirectMessageMessageRecord> records) {
    if (records.isEmpty) return;
    final byId = <String, DirectMessageMessageRecord>{};
    for (final messageId in orderedMessageIds.value) {
      final record = _rowNotifiers[messageId]?.value;
      if (record != null) byId[messageId] = record;
    }
    for (final record in records) {
      if (record.messageId.isNotEmpty) byId[record.messageId] = record;
    }
    _applyRecords(byId.values.toList(growable: false));
  }

  void _removeVisibleRecord(String messageId) {
    final nextRecords = <DirectMessageMessageRecord>[];
    for (final id in orderedMessageIds.value) {
      if (id == messageId) continue;
      final record = _rowNotifiers[id]?.value;
      if (record != null) nextRecords.add(record);
    }
    _applyRecords(nextRecords);
  }

  DirectMessageMessageRecord? get _earliestVisibleRecord {
    for (final messageId in orderedMessageIds.value) {
      final record = _rowNotifiers[messageId]?.value;
      if (record != null) return record;
    }
    return null;
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
    _knownRemoteTotal = -1;
    _hasMoreLocalOlder = true;
    _hasMoreRemoteOlder = true;
    _rowNotifiers.clear();
    orderedMessageIds.value = const [];
  }

  bool _isActiveTarget(String ownerUid, String peerUid) {
    return _activeOwnerUid == ownerUid && _activePeerUid == peerUid;
  }

  bool _hasRemotePage(int page) {
    if (_knownRemoteTotal < 0) return _hasMoreRemoteOlder;
    return (page - 1) * pageSize < _knownRemoteTotal;
  }
}

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

List<DirectMessageMessageRecord> _recordsFromMessages(
  List<Map<String, dynamic>> messages,
) {
  return messages
      .map(DirectMessageMessageRecord.fromJson)
      .where((record) => record.messageId.isNotEmpty)
      .toList(growable: false);
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

bool get _dmMessageMetricsEnabled => kDebugMode || kProfileMode;
