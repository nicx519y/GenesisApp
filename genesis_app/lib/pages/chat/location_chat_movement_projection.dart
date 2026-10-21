import '../../network/chatroom/chatroom_timeline_payload.dart';
import '../../network/chatroom/world_chatroom_service.dart';

/// View-only: canonical messages, cursors, persistence and World History are
/// untouched. A normal chat/Tick record ends a consecutive movement group.
List<WorldChatroomMessage> collapseLocationCharacterMovements(
  List<WorldChatroomMessage> source,
) {
  final ordered = _positionLiveMovements(source);
  final result = <WorldChatroomMessage>[];
  final group = <WorldChatroomMessage>[];
  final destinations = <String, ChatroomCharacterMovement>{};

  void flush() {
    if (group.isEmpty) return;
    final last = group.last;
    final payload = last.timelinePayload as ChatroomCharactersMovedPayload;
    if (group.length == 1 && destinations.length == payload.movements.length) {
      result.add(last);
    } else {
      final merged = ChatroomCharactersMovedPayload(
        movements: destinations.values.toList(growable: false),
      );
      result.add(
        last.copyWith(
          timelinePayload: merged,
          content: encodeChatroomTimelinePayload(merged),
        ),
      );
    }
    group.clear();
    destinations.clear();
  }

  for (final message in ordered) {
    final payload = message.timelinePayload;
    if (message.senderType != chatroomCharactersMovedSenderType ||
        payload is! ChatroomCharactersMovedPayload ||
        payload.movements.isEmpty) {
      flush();
      result.add(message);
      continue;
    }
    group.add(message);
    for (final movement in payload.movements) {
      destinations[movement.charId] = movement;
    }
  }
  flush();
  if (result.length == source.length &&
      Iterable<int>.generate(
        source.length,
      ).every((i) => identical(result[i], source[i]))) {
    return source;
  }
  return result;
}

bool _liveMovement(WorldChatroomMessage message) =>
    message.senderType == chatroomCharactersMovedSenderType &&
    message.locationMessageId <= 0 &&
    message.conversationRoundId.startsWith('ws-event:');

/// Cursorless world notifications have no location cursor. Position only these
/// live notices using server timestamps, leaving canonical row order intact.
/// Without timestamp anchors they remain at the live tail; never invent IDs.
List<WorldChatroomMessage> _positionLiveMovements(
  List<WorldChatroomMessage> source,
) {
  if (!source.any(_liveMovement)) return source;
  final base = source.where((m) => !_liveMovement(m)).toList();
  final anchors =
      <(DateTime, int)>[
        for (var i = 0; i < base.length; i++)
          if (base[i].createdAt != null) (base[i].createdAt!, i),
      ]..sort((a, b) {
        final time = a.$1.compareTo(b.$1);
        return time == 0 ? a.$2.compareTo(b.$2) : time;
      });
  final buckets = <int, List<WorldChatroomMessage>>{};
  for (final notice in source.where(_liveMovement)) {
    var position = base.length;
    final time = notice.createdAt;
    if (time != null && anchors.isNotEmpty) {
      var lo = 0, hi = anchors.length;
      while (lo < hi) {
        final mid = (lo + hi) ~/ 2;
        if (anchors[mid].$1.isAfter(time)) {
          hi = mid;
        } else {
          lo = mid + 1;
        }
      }
      position = lo == 0 ? 0 : anchors[lo - 1].$2 + 1;
    }
    (buckets[position] ??= []).add(notice);
  }
  for (final bucket in buckets.values) {
    bucket.sort((a, b) {
      final time = a.createdAt != null && b.createdAt != null
          ? a.createdAt!.compareTo(b.createdAt!)
          : 0;
      return time == 0 ? a.messageId.compareTo(b.messageId) : time;
    });
  }
  return [
    for (var i = 0; i <= base.length; i++) ...[
      ...?buckets[i],
      if (i < base.length) base[i],
    ],
  ];
}
