import 'dart:convert';
import '../../../../network/direct_message_conversation_store.dart';
import '../../../../platform/session/user_session_store.dart';
import '../../fixtures/http/mock_response_overrides.dart';

/// Owns only the current QA identity's collection cache and GET response lease.
class PrivateCollection {
  PrivateCollection({
    required this.session,
    required this.store,
    required this.storage,
    required this.resource,
    required this.currentResource,
  });
  final UserSessionStore session;
  final DirectMessageConversationStore store;
  final DirectMessageConversationStorage storage;
  final String resource;
  final bool Function() currentResource;
  QaMockResponseLease? _lease;
  String? _owner, _cursor;
  List<Map<String, dynamic>>? _before;
  bool _restored = false;

  Future<String> _identity() async {
    final uid = await session.readLoginUid();
    if (!currentResource() ||
        uid == null ||
        !uid.startsWith('qa_test_') ||
        (_owner != null && uid != _owner)) {
      throw StateError(
        'Private collection requires the same isolated QA identity and resource',
      );
    }
    return uid;
  }

  Future<List<Object?>> read() async {
    await _identity();
    await store.loadFromDb();
    await _identity();
    return store.orderedConversationIds.value.map((id) {
      final row = store.rowListenable(id)?.value;
      if (row == null) throw StateError('Missing actual conversation row');
      return jsonDecode(row.rawJson);
    }).toList();
  }

  Future<List<Object?>> prepare() async {
    if (!QaMockResponseOverrides.enabled)
      throw StateError('Requires internal mock QA build');
    final owner = await _identity();
    if (_before != null) {
      if (_restored) throw StateError('Collection lease already restored');
      return read();
    }
    final before = await storage.loadConversations(owner);
    final cursor = await storage.readCursor(owner);
    final lease = QaMockResponseOverrides.install(
      resource: resource,
      ownerUid: owner,
      currentOwner: session.readLoginUid,
      currentResource: currentResource,
      responses: const {
        'GET /api/v1/direct_message/conversations': {
          'err_no': 0,
          'err_msg': 'succ',
          'data': {
            'list': [],
            'total': 0,
            'pn': 1,
            'rn': 100,
            'next_after_message_id': '',
          },
        },
      },
    );
    _owner = owner;
    _before = before
        .map((r) => jsonDecode(r.rawJson) as Map<String, dynamic>)
        .toList();
    _cursor = cursor;
    _lease = lease;
    // Failure retains the lease/snapshot so explicit cleanup can still restore.
    // Drain any previous sync, then replace its cache through the empty source.
    await store.syncConversations();
    await _identity();
    await store.clearCache();
    await store.syncConversations();
    return read();
  }

  Future<String> cleanup() async {
    final owner = await _identity();
    if (_before == null) throw StateError('No collection lease to restore');
    final failures = <({Object error, StackTrace stack})>[];
    if (!_restored) {
      // A failed request has settled too; it must not prevent lease release.
      try {
        await store.syncConversations();
      } catch (error, stack) {
        failures.add((error: error, stack: stack));
      }
      try {
        await _identity();
        _lease!.restore();
        await storage.clearCache(owner);
        await storage.mergeConversations(
          ownerUid: owner,
          conversations: _before!,
          nextAfterMessageId: _cursor,
        );
        await store.loadFromDb();
      } catch (error, stack) {
        failures.add((error: error, stack: stack));
      }
    }
    try {
      final restored = await read();
      if (jsonEncode(restored) != jsonEncode(_before) ||
          await storage.readCursor(owner) != _cursor) {
        throw StateError('Private collection cache or cursor was not restored');
      }
      // Only a successfully restored lease may make cleanup idempotent.
      if (failures.isEmpty) _restored = true;
    } catch (error, stack) {
      failures.add((error: error, stack: stack));
    }
    if (failures.isNotEmpty) throw PrivateCollectionCleanupFailure(failures);
    return 'restored';
  }
}

class PrivateCollectionCleanupFailure implements Exception {
  PrivateCollectionCleanupFailure(this.failures);
  final List<({Object error, StackTrace stack})> failures;
  @override
  String toString() =>
      'Private collection cleanup failed: ' +
      failures.map((f) => '${f.error}\n${f.stack}').join('\nCaused by: ');
}
