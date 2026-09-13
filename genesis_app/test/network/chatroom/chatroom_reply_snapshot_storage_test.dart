import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_message_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> message(int id, int round) => {
  'global_msg_id': id,
  'msg_id': id,
  'location_msg_id': id,
  'conversation_round_id': round,
  'location_id': 'l',
  'sender_type': 'character',
  'content': 'reply $id',
  'ts': id,
};
Future<void> seed(ChatroomMessageStorage storage, int id, int round) =>
    storage.upsertMessage(
      ownerUid: 'u',
      worldId: 'w',
      locationId: 'l',
      message: message(id, round),
    );
Future<void> save(ChatroomMessageStorage storage, int round) =>
    storage.saveReplySnapshot(
      ownerUid: 'u',
      worldId: 'w',
      locationId: 'l',
      roundId: round,
      value: {
        'round_id': round,
        'cards_cache': {
          'list': [
            {'content': 'candidate'},
          ],
        },
        'viewed_card_id': 42,
        'supported_actions': {'edit': true},
        'capability_version': 1,
      },
    );
Future<List<Map<String, dynamic>>> read(ChatroomMessageStorage storage) =>
    storage.loadReplySnapshots(ownerUid: 'u', worldId: 'w', locationId: 'l');

void main() {
  for (final sqlite in [false, true]) {
    group(sqlite ? 'SQLite companions' : 'memory companions', () {
      late ChatroomMessageStorage storage;
      Directory? directory;
      setUp(() async {
        if (sqlite) {
          sqfliteFfiInit();
          directory = await Directory.systemTemp.createTemp('reply-snapshots-');
          storage = SqfliteChatroomMessageStorage(
            databasePath: '${directory!.path}/messages.db',
            databaseFactoryOverride: databaseFactoryFfi,
          );
        } else {
          storage = MemoryChatroomMessageStorage();
        }
      });
      tearDown(() async {
        if (storage is SqfliteChatroomMessageStorage) {
          await (storage as SqfliteChatroomMessageStorage).close();
        }
        await directory?.delete(recursive: true);
      });
      test(
        '200-message retention removes only orphan rounds, candidates have no cursor',
        () async {
          await seed(storage, 1, 1);
          await seed(storage, 2, 1);
          await save(storage, 1);
          await storage.mergeMessages(
            ownerUid: 'u',
            worldId: 'w',
            locationId: 'l',
            messages: [for (var id = 3; id <= 201; id++) message(id, 2)],
          );
          expect(await read(storage), hasLength(1));
          expect(
            await storage.loadLatestMessages(
              ownerUid: 'u',
              worldId: 'w',
              locationId: 'l',
              limit: 300,
            ),
            hasLength(200),
          );
          await seed(storage, 202, 2);
          expect(await read(storage), isEmpty);
          await save(storage, 1); // Late write cannot resurrect an orphan.
          expect(await read(storage), isEmpty);
        },
      );
      test('range replacement and gap deletion reconcile companions', () async {
        await seed(storage, 1, 1);
        await seed(storage, 2, 2);
        await save(storage, 1);
        await save(storage, 2);
        await storage.replaceMessages(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          messages: [message(3, 1)],
          startConversationRoundId: 1,
          endConversationRoundId: 1,
        );
        expect(
          (await read(
            storage,
          )).firstWhere((v) => v['round_id'] == 1)['needs_refresh'],
          true,
        );
        await storage.replaceMessages(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          messages: [],
          startConversationRoundId: 1,
          endConversationRoundId: 1,
        );
        expect((await read(storage)).single['round_id'], 2);
        await storage.deleteMessagesAtOrBefore(
          ownerUid: 'u',
          worldId: 'w',
          locationId: 'l',
          maxLocationMessageId: 2,
        );
        expect(await read(storage), isEmpty);
      });
      test(
        'migration is idempotent and clear prevents legacy resurrection',
        () async {
          final legacy = [
            {
              'round_id': 1,
              'viewed_card_id': 7,
              'cards_cache': {'list': []},
            },
          ];
          Future<void> migrate() => storage.importLegacyReplySnapshots(
            ownerUid: 'u',
            worldId: 'w',
            locationId: 'l',
            values: legacy,
          );
          await seed(storage, 1, 1);
          await migrate();
          await save(storage, 1);
          await migrate();
          expect((await read(storage)).single['viewed_card_id'], 42);
          await storage.clearCache('u');
          if (sqlite) {
            await (storage as SqfliteChatroomMessageStorage).close();
            storage = SqfliteChatroomMessageStorage(
              databasePath: '${directory!.path}/messages.db',
              databaseFactoryOverride: databaseFactoryFfi,
            );
          }
          await seed(storage, 1, 1);
          await migrate();
          expect(await read(storage), isEmpty);
          await save(storage, 1);
          expect(
            await read(storage),
            hasLength(1),
            reason: 'New authoritative data remains writable',
          );
          expect(
            await storage.loadReplySnapshots(
              ownerUid: 'other',
              worldId: 'w',
              locationId: 'l',
            ),
            isEmpty,
          );
        },
      );
      test(
        'restart restores complete content, position and support information',
        () async {
          await seed(storage, 1, 1);
          await save(storage, 1);
          if (sqlite) {
            await (storage as SqfliteChatroomMessageStorage).close();
            storage = SqfliteChatroomMessageStorage(
              databasePath: '${directory!.path}/messages.db',
              databaseFactoryOverride: databaseFactoryFfi,
            );
          }
          final value = (await read(storage)).single;
          expect(value['viewed_card_id'], 42);
          expect(value['supported_actions'], {'edit': true});
          expect((value['cards_cache'] as Map)['list'], [
            {'content': 'candidate'},
          ]);
        },
      );
    });
  }
}
