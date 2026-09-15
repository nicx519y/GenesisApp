import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../../network/http_transport.dart';

import '../../../../network/chatroom/chatroom_http_api.dart';
import 'chatroom_inspiration_models.dart';
import 'chatroom_inspiration_storage.dart';

class ChatroomInspirationController extends ChangeNotifier {
  ChatroomInspirationController({
    required this.ownerUid,
    required this.worldId,
    required ChatroomHttpApi httpApi,
    ChatroomInspirationStorage? storage,
  }) : _http = httpApi,
       _storage = storage ?? SqfliteChatroomInspirationStorage();

  final String ownerUid, worldId;
  final ChatroomHttpApi _http;
  final ChatroomInspirationStorage _storage;
  final _contexts = <String, (int, int)>{};
  final _epochs = <String, int>{};
  final _renderedRounds = <String, int>{};
  final _views = <String, String>{};
  final _viewEpochs = <String, int>{};
  final _sourcesByKey = <String, ChatroomInspirationSource>{};
  final _memory = <String, ChatroomInspirationResponse>{};
  final _requests = <String, Future<ChatroomInspirationResponse?>>{};
  final _tokens = <String, NetworkCancellationToken>{};
  Future<void> _writes = Future.value();
  bool _disposed = false;

  int revision(String location) => _epochs[location] ?? 0;

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _writes.then((_) => work());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  /// Observe verified history and live progress, never a partial older page.
  void observe(
    String location, {
    required int roundId,
    required int tailMessageId,
    bool replacing = false,
  }) {
    if (_disposed || roundId <= 0) return;
    final old = _contexts[location];
    if (old != null && roundId < old.$1) return;
    _contexts[location] = (
      roundId,
      old != null && roundId == old.$1
          ? (tailMessageId > old.$2 ? tailMessageId : old.$2)
          : tailMessageId,
    );
    if (old == null || roundId > old.$1) _invalidate(location);
  }

  /// Called after the page renders a conversation (including its waiting slot).
  /// The round can be the exclusive lower bound of a waiting slot's captured
  /// predecessor when its server round ID has not arrived yet.
  /// Background observations only invalidate operations, never persisted lists.
  Future<void> conversationRendered(String location, int roundId) {
    if (_disposed || roundId <= (_renderedRounds[location] ?? 0)) {
      return Future.value();
    }
    _renderedRounds[location] = roundId;
    final activeRound = _contexts[location]?.$1;
    if (activeRound != null && activeRound < roundId) _invalidate(location);
    _memory.removeWhere(
      (key, value) =>
          _sourcesByKey[key]?.locationId == location &&
          value.conversationRoundId < roundId,
    );
    _sourcesByKey.removeWhere(
      (_, source) => source.locationId == location && source.roundId < roundId,
    );
    return _serial(
      () => _storage.clearLocation(
        ownerUid,
        worldId,
        location,
        beforeRound: roundId,
      ),
    );
  }

  void _invalidate(String location) {
    _epochs[location] = revision(location) + 1;
    cancelView(location);
    // In-flight results check their epoch before entering the write queue.
    _requests.removeWhere(
      (key, _) => _sourcesByKey[key]?.locationId == location,
    );
    if (!_disposed) notifyListeners();
  }

  void cancelView(String location) {
    if (_disposed) return;
    _views.remove(location);
    _viewEpochs[location] = (_viewEpochs[location] ?? 0) + 1;
    for (final entry in _tokens.entries.toList()) {
      if (_sourcesByKey[entry.key]?.locationId == location) {
        entry.value.cancel();
        _tokens.remove(entry.key);
      }
    }
    _requests.removeWhere(
      (key, _) => _sourcesByKey[key]?.locationId == location,
    );
  }

  void activate(ChatroomInspirationSource source) {
    if (_views[source.locationId] == source.key) return;
    cancelView(source.locationId);
    _views[source.locationId] = source.key;
    _sourcesByKey[source.key] = source;
  }

  bool isCurrent(ChatroomInspirationSource source, int epoch) =>
      !_disposed &&
      source.ownerUid == ownerUid &&
      source.worldId == worldId &&
      _contexts[source.locationId]?.$1 == source.roundId &&
      source.roundId >= (_renderedRounds[source.locationId] ?? 0) &&
      revision(source.locationId) == epoch;

  // A formal source with unknown card ID is an alias resolved by the server.
  // Keep that alias separate from the explicit original card (also source 0).
  String _memoryKey(ChatroomInspirationSource source) =>
      source.cardId == null && source.sourceCardId == 0
      ? '${source.key}:formal'
      : source.key;

  void _remember(
    ChatroomInspirationSource source,
    ChatroomInspirationResponse value,
  ) {
    final key = _memoryKey(source);
    _sourcesByKey[key] = source;
    _memory[key] = value;
  }

  /// Reads only local storage; callers check generation quotas only on a miss.
  Future<ChatroomInspirationResponse?> readCached(
    ChatroomInspirationSource source,
  ) async {
    final epoch = revision(source.locationId);
    if (!isCurrent(source, epoch)) return null;
    activate(source);
    final viewEpoch = _viewEpochs[source.locationId];
    bool matches(ChatroomInspirationResponse? value) =>
        value != null &&
        value.conversationRoundId == source.roundId &&
        (value.sourceCardId == source.sourceCardId ||
            (source.cardId == null && source.sourceCardId == 0));
    var cached = _memory[_memoryKey(source)];
    if (!matches(cached)) cached = await _serial(() => _storage.load(source));
    if (!isCurrent(source, epoch) ||
        _views[source.locationId] != source.key ||
        _viewEpochs[source.locationId] != viewEpoch) {
      return null;
    }
    if (!matches(cached)) return null;
    _remember(source, cached!);
    return cached;
  }

  Future<ChatroomInspirationResponse?> load(ChatroomInspirationSource source) {
    final epoch = revision(source.locationId);
    if (!isCurrent(source, epoch)) return Future.value(null);
    activate(source);
    final pending = _requests[source.key];
    if (pending != null) return pending;
    late final Future<ChatroomInspirationResponse?> task;
    task = _load(source, epoch, _viewEpochs[source.locationId] ?? 0)
        .whenComplete(() {
          if (identical(_requests[source.key], task)) {
            _requests.remove(source.key);
          }
        });
    _requests[source.key] = task;
    return task;
  }

  Future<ChatroomInspirationResponse?> _load(
    ChatroomInspirationSource source,
    int epoch,
    int viewEpoch,
  ) async {
    bool current() =>
        isCurrent(source, epoch) &&
        _views[source.locationId] == source.key &&
        _viewEpochs[source.locationId] == viewEpoch;
    final cached = await readCached(source);
    if (!current()) return null;
    if (cached != null) return cached;
    final token = NetworkCancellationToken();
    _tokens[source.key] = token;
    late final ChatroomInspirationResponse response;
    try {
      response = await _http.getInspirations(
        worldId: worldId,
        locationId: source.locationId,
        conversationRoundId: source.roundId,
        cardId: source.cardId,
        cancellationToken: token,
      );
    } catch (_) {
      if (!current()) return null;
      rethrow;
    } finally {
      if (identical(_tokens[source.key], token)) _tokens.remove(source.key);
    }
    if (!current()) return null;
    // A formal reply owned by another user may already be a selected candidate.
    // Its card group is private; the endpoint resolves the authoritative source.
    if (response.sourceCardId != source.sourceCardId &&
        !(source.cardId == null && source.sourceCardId == 0)) {
      throw StateError(
        'The inspiration source changed. Please reopen inspiration.',
      );
    }
    await _serial(() async {
      if (!current()) return;
      await _storage.save(source.resolved(response.sourceCardId), response);
      if (current()) _remember(source, response);
    });
    return current() ? response : null;
  }

  void suspend() {
    for (final location in _contexts.keys.toList()) {
      _invalidate(location);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    _views.clear();
    _memory.clear();
    unawaited(_serial(_storage.close).catchError((Object _) {}));
    super.dispose();
  }
}
