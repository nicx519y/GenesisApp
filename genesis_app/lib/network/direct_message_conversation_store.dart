import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../platform/platform_services.dart';
import '../utils/genesis_timestamp_formatter.dart';
import 'direct_message_database.dart';
import 'genesis_api.dart';
import 'json_utils.dart';

class DirectMessageConversationRecord {
  DirectMessageConversationRecord({
    required this.conversationId,
    required this.peerUid,
    required this.lastMessageId,
    required this.avatarUrl,
    required this.peerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageAtTime,
    required this.unreadCount,
    required this.sortValue,
    required this.canSendNextMessage,
    required this.rawJson,
  });

  factory DirectMessageConversationRecord.fromJson(Map<String, dynamic> json) {
    final peer = asJsonMap(json['peer'] ?? const <String, dynamic>{});
    final time = parseFlexibleTimestamp(json['last_message_at']);
    return DirectMessageConversationRecord(
      conversationId: asString(json['conv_id']),
      peerUid: asString(peer['uid']),
      lastMessageId: asString(json['last_message_id']),
      avatarUrl: asImageUrl(peer['avatar']),
      peerName: asString(peer['name'], fallback: 'Unknown user'),
      lastMessage: asString(json['last_message']),
      lastMessageAt: formatGenesisTimestamp(json['last_message_at']),
      lastMessageAtTime: time,
      unreadCount: asInt(json['unread_cnt']),
      sortValue: time?.millisecondsSinceEpoch ?? 0,
      canSendNextMessage: asBool(json['can_send_next_message'], fallback: true),
      rawJson: jsonEncode(json),
    );
  }

  final String conversationId;
  final String peerUid;
  final String lastMessageId;
  final String avatarUrl;
  final String peerName;
  final String lastMessage;
  final String lastMessageAt;
  final DateTime? lastMessageAtTime;
  final int unreadCount;
  final int sortValue;
  final bool canSendNextMessage;
  final String rawJson;
}

abstract class DirectMessageConversationStorage {
  Future<List<DirectMessageConversationRecord>> loadConversations(
    String ownerUid,
  );

  Future<String?> readCursor(String ownerUid);

  Future<void> mergeConversations({
    required String ownerUid,
    required List<Map<String, dynamic>> conversations,
    required String? nextAfterMessageId,
  });

  Future<void> clearCache(String ownerUid);
}

class SqfliteDirectMessageConversationStorage
    implements DirectMessageConversationStorage {
  SqfliteDirectMessageConversationStorage({
    DirectMessageDatabaseProvider? databaseProvider,
  }) : _databaseProvider =
           databaseProvider ?? DirectMessageDatabaseProvider.instance;

  final DirectMessageDatabaseProvider _databaseProvider;

  Future<Database> get _db => _databaseProvider.database;

  @override
  Future<List<DirectMessageConversationRecord>> loadConversations(
    String ownerUid,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'dm_conversations',
      where: 'owner_uid = ?',
      whereArgs: [ownerUid],
      orderBy: 'sort_value DESC',
    );
    return rows
        .map((row) => _recordFromRawJson('${row['raw_json']}'))
        .whereType<DirectMessageConversationRecord>()
        .toList(growable: false);
  }

  @override
  Future<String?> readCursor(String ownerUid) async {
    final db = await _db;
    final rows = await db.query(
      'dm_sync_meta',
      columns: const ['value'],
      where: 'owner_uid = ? AND key = ?',
      whereArgs: [ownerUid, directMessageCursorKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = '${rows.single['value']}'.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Future<void> mergeConversations({
    required String ownerUid,
    required List<Map<String, dynamic>> conversations,
    required String? nextAfterMessageId,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final json in conversations) {
        final record = DirectMessageConversationRecord.fromJson(json);
        if (record.conversationId.isEmpty) continue;
        await txn.insert('dm_conversations', {
          'owner_uid': ownerUid,
          'conv_id': record.conversationId,
          'raw_json': record.rawJson,
          'sort_value': record.sortValue,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final cursor = nextAfterMessageId?.trim();
      if (cursor != null && cursor.isNotEmpty) {
        await txn.insert('dm_sync_meta', {
          'owner_uid': ownerUid,
          'key': directMessageCursorKey,
          'value': cursor,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'dm_conversations',
        where: 'owner_uid = ?',
        whereArgs: [ownerUid],
      );
      await txn.delete(
        'dm_sync_meta',
        where: 'owner_uid = ?',
        whereArgs: [ownerUid],
      );
    });
  }
}

class MemoryDirectMessageConversationStorage
    implements DirectMessageConversationStorage {
  final Map<String, Map<String, DirectMessageConversationRecord>>
  _recordsByOwner = {};
  final Map<String, String> _cursorByOwner = {};

  @override
  Future<List<DirectMessageConversationRecord>> loadConversations(
    String ownerUid,
  ) async {
    final records =
        _recordsByOwner[ownerUid]?.values.toList(growable: false) ??
        const <DirectMessageConversationRecord>[];
    return _sorted(records);
  }

  @override
  Future<String?> readCursor(String ownerUid) async {
    final cursor = _cursorByOwner[ownerUid]?.trim();
    return cursor == null || cursor.isEmpty ? null : cursor;
  }

  @override
  Future<void> mergeConversations({
    required String ownerUid,
    required List<Map<String, dynamic>> conversations,
    required String? nextAfterMessageId,
  }) async {
    final ownerRecords = _recordsByOwner.putIfAbsent(
      ownerUid,
      () => <String, DirectMessageConversationRecord>{},
    );
    for (final json in conversations) {
      final record = DirectMessageConversationRecord.fromJson(json);
      if (record.conversationId.isEmpty) continue;
      ownerRecords[record.conversationId] = record;
    }
    final cursor = nextAfterMessageId?.trim();
    if (cursor != null && cursor.isNotEmpty) {
      _cursorByOwner[ownerUid] = cursor;
    }
  }

  @override
  Future<void> clearCache(String ownerUid) async {
    _recordsByOwner.remove(ownerUid);
    _cursorByOwner.remove(ownerUid);
  }
}

class DirectMessageConversationStore {
  DirectMessageConversationStore({
    required GenesisApi api,
    required UserSessionStore sessionStore,
    required DirectMessageConversationStorage storage,
  }) : _api = api,
       _sessionStore = sessionStore,
       _storage = storage;

  static const _fullSyncPageSize = 100;

  final GenesisApi _api;
  final UserSessionStore _sessionStore;
  final DirectMessageConversationStorage _storage;
  final ValueNotifier<List<String>> orderedConversationIds =
      ValueNotifier<List<String>>(const []);
  final Map<String, ValueNotifier<DirectMessageConversationRecord>>
  _rowNotifiers = {};

  String? _activeOwnerUid;
  Future<void>? _syncFuture;

  ValueListenable<DirectMessageConversationRecord>? rowListenable(
    String conversationId,
  ) {
    return _rowNotifiers[conversationId];
  }

  Future<void> loadFromDb() async {
    final ownerUid = await _ownerUid();
    _resetIfOwnerChanged(ownerUid);
    final records = await _storage.loadConversations(ownerUid);
    _applyRecords(records);
  }

  Future<void> syncConversations() {
    final inFlight = _syncFuture;
    if (inFlight != null) return inFlight;
    final stopwatch = _dmConversationMetricsEnabled
        ? (Stopwatch()..start())
        : null;
    final future = _syncConversations().whenComplete(() {
      if (stopwatch == null) return;
      debugPrint(
        '[Messages][DM] syncConversations '
        'elapsed=${stopwatch.elapsedMilliseconds}ms',
      );
    });
    _syncFuture = future.whenComplete(() => _syncFuture = null);
    return _syncFuture!;
  }

  Future<void> mergeConversationJson(Map<String, dynamic> conversation) async {
    final ownerUid = await _ownerUid();
    _resetIfOwnerChanged(ownerUid);
    await _storage.mergeConversations(
      ownerUid: ownerUid,
      conversations: [conversation],
      nextAfterMessageId: null,
    );
    _applyRecords(await _storage.loadConversations(ownerUid));
  }

  Future<void> markPeerRead(String peerUid) async {
    final cleanPeerUid = peerUid.trim();
    if (cleanPeerUid.isEmpty) return;
    final ownerUid = await _ownerUid();
    _resetIfOwnerChanged(ownerUid);
    final records = await _storage.loadConversations(ownerUid);
    final updated = <Map<String, dynamic>>[];
    for (final record in records) {
      if (record.peerUid != cleanPeerUid || record.unreadCount == 0) continue;
      final decoded = jsonDecode(record.rawJson);
      final json = asJsonMap(decoded);
      json['unread_cnt'] = 0;
      updated.add(json);
    }
    if (updated.isEmpty) return;
    await _storage.mergeConversations(
      ownerUid: ownerUid,
      conversations: updated,
      nextAfterMessageId: null,
    );
    _applyRecords(await _storage.loadConversations(ownerUid));
  }

  Future<void> clearCache() async {
    final ownerUid = await _ownerUid();
    await _storage.clearCache(ownerUid);
    if (_activeOwnerUid == null || _activeOwnerUid == ownerUid) {
      _activeOwnerUid = ownerUid;
      _rowNotifiers.clear();
      if (orderedConversationIds.value.isNotEmpty) {
        orderedConversationIds.value = const [];
      }
    }
  }

  Future<void> _syncConversations() async {
    final ownerUid = await _ownerUid();
    _resetIfOwnerChanged(ownerUid);
    final cursor = await _storage.readCursor(ownerUid);
    if (cursor == null || cursor.isEmpty) {
      await _fullSync(ownerUid);
    } else {
      await _deltaSync(ownerUid, cursor);
    }
    final records = await _storage.loadConversations(ownerUid);
    _applyRecords(records);
  }

  Future<void> _fullSync(String ownerUid) async {
    final all = <Map<String, dynamic>>[];
    String? nextAfterMessageId;
    var page = 1;
    while (true) {
      final data = await _api.v1.dm.conversations(
        pn: page,
        rn: _fullSyncPageSize,
      );
      final items = _conversationItems(data);
      all.addAll(items);
      nextAfterMessageId = _nextAfterMessageId(
        data,
        fallback: nextAfterMessageId,
      );
      if (items.length < _fullSyncPageSize) break;
      page += 1;
    }
    await _storage.mergeConversations(
      ownerUid: ownerUid,
      conversations: all,
      nextAfterMessageId: nextAfterMessageId,
    );
  }

  Future<void> _deltaSync(String ownerUid, String cursor) async {
    final data = await _api.v1.dm.conversations(afterMessageId: cursor);
    await _storage.mergeConversations(
      ownerUid: ownerUid,
      conversations: _conversationItems(data),
      nextAfterMessageId: _nextAfterMessageId(data, fallback: cursor),
    );
  }

  void _applyRecords(List<DirectMessageConversationRecord> records) {
    final sorted = _sorted(records);
    final nextIds = sorted.map((record) => record.conversationId).toList();
    for (final record in sorted) {
      final existing = _rowNotifiers[record.conversationId];
      if (existing == null) {
        _rowNotifiers[record.conversationId] =
            ValueNotifier<DirectMessageConversationRecord>(record);
      } else if (!_sameRecord(existing.value, record)) {
        existing.value = record;
      }
    }
    if (!_sameIds(orderedConversationIds.value, nextIds)) {
      orderedConversationIds.value = List.unmodifiable(nextIds);
    }
  }

  Future<String> _ownerUid() async {
    final uid = (await _sessionStore.readUid())?.trim();
    return uid == null || uid.isEmpty ? '__anonymous__' : uid;
  }

  void _resetIfOwnerChanged(String ownerUid) {
    if (_activeOwnerUid == ownerUid) return;
    _activeOwnerUid = ownerUid;
    _rowNotifiers.clear();
    orderedConversationIds.value = const [];
  }
}

List<DirectMessageConversationRecord> _sorted(
  Iterable<DirectMessageConversationRecord> records,
) {
  final sorted = records.toList(growable: false);
  sorted.sort((a, b) => b.sortValue.compareTo(a.sortValue));
  return sorted;
}

List<Map<String, dynamic>> _conversationItems(Map<String, dynamic> data) {
  final rawItems = data['list'] is List
      ? asJsonList(data['list'])
      : const <Object?>[];
  return rawItems.map((item) => asJsonMap(item)).toList(growable: false);
}

String? _nextAfterMessageId(Map<String, dynamic> data, {String? fallback}) {
  final cursor = asString(data['next_after_message_id']).trim();
  return cursor.isEmpty ? fallback : cursor;
}

DirectMessageConversationRecord? _recordFromRawJson(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson);
    return DirectMessageConversationRecord.fromJson(asJsonMap(decoded));
  } catch (_) {
    return null;
  }
}

bool _sameRecord(
  DirectMessageConversationRecord previous,
  DirectMessageConversationRecord next,
) {
  return previous.rawJson == next.rawJson &&
      previous.sortValue == next.sortValue;
}

bool _sameIds(List<String> previous, List<String> next) {
  if (previous.length != next.length) return false;
  for (var index = 0; index < previous.length; index += 1) {
    if (previous[index] != next[index]) return false;
  }
  return true;
}

bool get _dmConversationMetricsEnabled => kDebugMode || kProfileMode;
