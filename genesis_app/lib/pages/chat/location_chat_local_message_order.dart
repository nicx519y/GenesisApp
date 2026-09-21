import '../../components/chat/shared/chat_ui.dart';

/// Ordering metadata only: never stores geometry, scroll offsets or fake IDs.
/// Its lifetime is the page's local outbox, not the server history/cache.
class LocationChatLocalMessageOrder {
  final _slots = <String, _LocalMessageSlot>{};

  static bool isUnconfirmed(ChatMessageVm message) =>
      message.isMe &&
      (message.status == 'sending' ||
          message.status == 'failed' ||
          (message.status == 'sent' &&
              message.locationMessageId <= 0 &&
              message.globalMessageId <= 0 &&
              (message.messageId ?? 0) <= 0));

  void clear() => _slots.clear();
  void remove(String localId) => _slots.remove(localId);
  bool contains(ChatMessageVm message) =>
      _slots.containsKey(message.localId) && isUnconfirmed(message);

  /// An empty/regenerating card still occupies the same logical slot.
  String? firstLocalAfterRound(String round, List<ChatMessageVm> messages) {
    if (round.isEmpty) return null;
    for (final message in messages) {
      if (contains(message) &&
          _slots[message.localId]?.before?.round == round) {
        return message.localId;
      }
    }
    return null;
  }

  void retain(Iterable<ChatMessageVm> messages) {
    final ids = messages
        .where(isUnconfirmed)
        .map((message) => message.localId)
        .toSet();
    _slots.removeWhere((id, _) => !ids.contains(id));
  }

  void capture(
    ChatMessageVm message, {
    required List<ChatMessageVm> before,
    Iterable<ChatMessageVm> canonical = const [],
    Set<String> cardMessageIds = const {},
  }) {
    if (_slots.containsKey(message.localId)) return;
    final preceding = before
        .where(
          (row) => row.localId != message.localId && !row.isAiContentDisclaimer,
        )
        .toList();
    var boundary = 0;
    for (final row in [...canonical, ...preceding]) {
      if (row.locationMessageId > boundary) boundary = row.locationMessageId;
    }
    _slots[message.localId] = _LocalMessageSlot(
      preceding.isEmpty ? null : _OrderNeighbor(preceding.last, cardMessageIds),
      boundary,
    );
  }

  /// Call after card projection so a candidate-to-history handoff cannot move
  /// a local row across the card. All consumers get this same final sequence.
  List<ChatMessageVm> apply(
    List<ChatMessageVm> source, {
    Iterable<ChatMessageVm> localMessages = const [],
    Set<String> cardMessageIds = const {},
    bool rememberFollowing = true,
  }) {
    final locals = <String, ChatMessageVm>{
      for (final row in [...source, ...localMessages])
        if (_slots.containsKey(row.localId) && isUnconfirmed(row))
          row.localId: row,
    };
    if (locals.isEmpty) return source;
    final result = source
        .where((row) => !locals.containsKey(row.localId))
        .toList();
    var previousLocalIndex = -1;
    for (final entry in _slots.entries) {
      final local = locals[entry.key];
      if (local == null) continue;
      final slot = entry.value;
      final left =
          slot.before?.indexIn(result, cardMessageIds, last: true) ?? -1;
      final right =
          slot.after?.indexIn(result, cardMessageIds, last: false) ?? -1;
      final promotedBoundary = slot.before?.canonicalBoundary ?? 0;
      final boundary = promotedBoundary > slot.boundary
          ? promotedBoundary
          : slot.boundary;
      var index = left >= 0 ? left + 1 : _boundaryIndex(result, boundary);
      // A predecessor may itself have been retried and promoted to a later
      // server position. Do not drag the remaining failed rows along with it.
      if (right >= 0 && (left < 0 || index > right)) index = right;
      if (index <= previousLocalIndex) index = previousLocalIndex + 1;
      // A card is one layout entry, never insert between its message VMs.
      if (index > 0 &&
          index < result.length &&
          cardMessageIds.contains(result[index - 1].localId) &&
          cardMessageIds.contains(result[index].localId)) {
        while (index < result.length &&
            cardMessageIds.contains(result[index].localId)) {
          index++;
        }
      }
      result.insert(index, local);
      previousLocalIndex = index;
      if (rememberFollowing && slot.after == null) {
        for (final row in result.skip(index + 1)) {
          if (!isUnconfirmed(row) && !row.isAiContentDisclaimer) {
            slot.after = _OrderNeighbor(row, cardMessageIds);
            break;
          }
        }
      }
    }
    return result;
  }

  int _boundaryIndex(List<ChatMessageVm> rows, int boundary) {
    var index = 0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.isAiContentDisclaimer ||
          (row.locationMessageId > 0 && row.locationMessageId <= boundary)) {
        index = i + 1;
      }
      if (row.locationMessageId > boundary) break;
    }
    return index;
  }
}

class _LocalMessageSlot {
  _LocalMessageSlot(this.before, this.boundary);
  final _OrderNeighbor? before;
  final int boundary;
  _OrderNeighbor? after;
}

class _OrderNeighbor {
  _OrderNeighbor(this.message, Set<String> cardMessageIds)
    : wasUnconfirmed = LocationChatLocalMessageOrder.isUnconfirmed(message),
      round =
          cardMessageIds.contains(message.localId) && message.roundId.isNotEmpty
          ? message.roundId
          : null;

  // The VM is retained intentionally: reconciliation assigns canonical IDs to
  // it in place. No separate, stale copy of the client/server identity is kept.
  ChatMessageVm message;
  final bool wasUnconfirmed;
  final String? round;

  int get canonicalBoundary => wasUnconfirmed ? 0 : message.locationMessageId;

  int indexIn(
    List<ChatMessageVm> rows,
    Set<String> cardMessageIds, {
    required bool last,
  }) {
    if (round != null) {
      bool belongsToCard(ChatMessageVm row) =>
          row.roundId == round && cardMessageIds.contains(row.localId);
      final index = last
          ? rows.lastIndexWhere(belongsToCard)
          : rows.indexWhere(belongsToCard);
      if (index >= 0) {
        // Follow the selected card, then its actual business identity when it
        // is promoted to history. Other messages in the same round are NOT
        // card members and must not pull a failed row past later arrivals.
        message = rows[index];
        return index;
      }
    }
    bool matches(ChatMessageVm row) =>
        row.localId == message.localId ||
        (message.locationMessageId > 0 &&
            row.locationMessageId == message.locationMessageId) ||
        (message.globalMessageId > 0 &&
            row.globalMessageId == message.globalMessageId) ||
        (message.clientMsgId.isNotEmpty &&
            row.clientMsgId == message.clientMsgId);
    return last ? rows.lastIndexWhere(matches) : rows.indexWhere(matches);
  }
}
