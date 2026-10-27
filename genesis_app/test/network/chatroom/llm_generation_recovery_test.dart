import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/utils/llm_generation.dart';

void main() {
  for (final sqlite in [false, true]) {
    test(
      'attempt cache deletion preserves reused IDs and authoritative rows sqlite=$sqlite',
      () async {
        sqfliteFfiInit();
        final ChatroomMessageStorage storage = sqlite
            ? SqfliteChatroomMessageStorage(
                databaseFactoryOverride: databaseFactoryFfi,
                databasePath: inMemoryDatabasePath,
              )
            : MemoryChatroomMessageStorage();
        if (storage is SqfliteChatroomMessageStorage) {
          addTearDown(storage.close);
        }
        Map<String, dynamic> row(int id, String content, [int? attempt]) => {
          'global_message_id': id,
          'message_id': id,
          'location_message_id': id,
          'conversation_round_id': 1,
          'sender_type': 'character',
          'content': content,
          if (attempt != null)
            'llm_attempt_source': {'key': 'generation', 'number': attempt},
        };
        await storage.mergeMessages(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          messages: [
            row(1, 'old', 1),
            row(2, 'old sibling', 1),
            row(3, 'confirmed'),
          ],
        );
        await storage.upsertMessage(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          message: row(1, 'new', 2),
        );
        await storage.removeGenerationAttempts(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          generationKey: 'generation',
          shouldRemove: (number) => number == 1,
          isCurrent: () => true,
        );
        final rows = await storage.loadLatestMessages(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          limit: 100,
        );
        expect(rows.map((r) => r['content']), ['new', 'confirmed']);
      },
    );
  }

  test('larger attempts invalidate all output; expected is not received', () {
    final state = LlmGenerationState(const LlmGenerationId('w', 'l', '1', 'r'));
    final first = state.accept(1, 10, end: true)!;
    expect(state.accept(1, 10, end: false), isNull);
    state.retract(1, retrying: true, next: 3);
    expect(state.latest, 1);
    expect(first.invalidated, isTrue);
    final third = state.accept(3, 10, end: false)!;
    expect(third.number, 3);
    expect(state.accept(2, 11, end: false), isNull);
    expect(state.retract(1, retrying: true, next: 2), isFalse);
    expect(third.invalidated, isFalse);
    state.retract(3, retrying: false);
    expect(state.accept(4, 10, end: false), isNull);
  });
  test(
    'missed retry notification retracts all earlier attempts including ended messages',
    () {
      final state = LlmGenerationState(
        const LlmGenerationId('w', 'l', '1', 'r'),
      );
      final old = state.accept(1, 10, end: true)!;
      state.accept(1, 11, end: true);
      var notices = 0;
      old.addListener(() => notices++);
      state.accept(4, 10, end: true);
      expect(notices, 1);
      expect(old.animateRetraction, isTrue);
      expect(state.accept(1, 12, end: false), isNull);
    },
  );
  test(
    'wire control is independent of err_no and stream fields survive encoding',
    () {
      final event =
          chatroomEventFromV2Message(
                ChatroomV2Message.fromJson({
                  'type': 'llm_generation_state',
                  'stream_type': '',
                  'world_id': 'w',
                  'location_id': 'l',
                  'conversation_round_id': 1,
                  'gateway_request_id': 'r',
                  'err_no': 0,
                  'payload': {
                    'state': 'failed',
                    'retract_attempt_no': 2,
                    'reason_code': 'stream_failed',
                  },
                }),
              )
              as ChatroomLlmGenerationState;
      expect(event.state, 'failed');
      final frame = ChatroomV2Message.fromJson({
        'type': 'character',
        'stream_type': 'llm_chunk',
        'world_id': 'w',
        'location_id': 'l',
        'conversation_round_id': 1,
        'global_message_id': 10,
        'gateway_request_id': 'r',
        'attempt_no': 3,
        'sender_name': 'New name',
        'payload': {'seq': 8, 'content': 'tail'},
      });
      final chunk =
          chatroomEventFromV2Message(ChatroomV2Message.decode(frame.encode()))
              as ChatroomAiStreamChunk;
      expect(chunk.attemptNo, 3);
      expect(chunk.senderName, 'New name');
      expect(chunk.seq, 8);
    },
  );
}
