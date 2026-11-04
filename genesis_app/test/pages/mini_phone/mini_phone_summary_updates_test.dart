import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/session/mini_phone_session.dart';

import '../../support/mini_phone_chat_backend.dart';

ChatroomWorldSummaryUpdated _summary({
  String worldId = 'w',
  String userId = 'u',
  int generation = 1,
}) => ChatroomWorldSummaryUpdated(
  worldId: worldId,
  userId: userId,
  generation: generation,
  tickNo: generation,
  ts: null,
);

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<
    (
      PhoneBackend,
      MiniPhoneSession,
      StreamController<ChatroomWorldSummaryUpdated>,
    )
  >
  createSession() async {
    final backend = PhoneBackend();
    final data = backend.store();
    await data.ready;
    final events = StreamController<ChatroomWorldSummaryUpdated>.broadcast();
    final session = MiniPhoneSession(worldId: 'w', data: data);
    session.bindSummaryUpdates(events.stream);
    addTearDown(() async {
      session.dispose();
      await events.close();
      backend.revision.dispose();
    });
    return (backend, session, events);
  }

  test(
    'only current world/account summary hints notify without HTTP work',
    () async {
      final (backend, session, events) = await createSession();
      var notifications = 0;
      session.summaryUpdates.addListener(() => notifications++);
      final requestCount = backend.requests.length;

      events.add(_summary(worldId: 'another-world'));
      events.add(_summary(userId: 'another-user'));
      events.add(_summary());
      events.add(_summary());
      events.add(_summary(generation: 2));
      await _flushEvents();

      expect(notifications, 2);
      expect(backend.requests.length, requestCount);
    },
  );

  test(
    'account changes reject old user hints and reset generation deduplication',
    () async {
      final (backend, session, events) = await createSession();
      var notifications = 0;
      session.summaryUpdates.addListener(() => notifications++);
      events.add(_summary());
      await _flushEvents();
      expect(notifications, 1);

      backend.uid = 'replacement-user';
      // This event was queued before switching and must not reach the new owner.
      events.add(_summary(generation: 2));
      backend.revision.value++;
      await session.data!.ready;
      events.add(_summary(userId: 'replacement-user'));
      events.add(_summary(userId: 'replacement-user'));
      events.add(_summary(generation: 3));
      await _flushEvents();
      expect(notifications, 2);

      backend.uid = null;
      backend.revision.value++;
      await session.data!.ready;
      events.add(_summary(userId: 'replacement-user', generation: 2));
      await _flushEvents();
      expect(notifications, 2);

      backend.uid = 'replacement-user';
      backend.revision.value++;
      await session.data!.ready;
      events.add(_summary(userId: 'replacement-user'));
      await _flushEvents();
      expect(notifications, 3);
    },
  );

  test(
    'disposing a session cancels its listener and discards queued hints',
    () async {
      final (_, session, events) = await createSession();
      var notifications = 0;
      session.summaryUpdates.addListener(() => notifications++);
      expect(events.hasListener, isTrue);
      events.add(_summary());
      session.dispose();
      await _flushEvents();
      expect(events.hasListener, isFalse);
      events.add(_summary(generation: 2));
      await _flushEvents();
      expect(notifications, 0);
    },
  );
}
