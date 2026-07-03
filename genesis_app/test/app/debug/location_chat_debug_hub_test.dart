import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/debug/location_chat_debug_hub.dart';

void main() {
  tearDown(LocationChatDebugHub.resetForTesting);

  test('record is disabled without compile-time flag', () {
    LocationChatDebugHub.record(
      source: 'panel',
      action: 'stateReceived',
      details: const {'count': 1},
    );

    final snapshot = LocationChatDebugHub.snapshot();
    expect(snapshot['enabled'], false);
    expect(snapshot['events'], isEmpty);
  });

  test('records test events, sanitizes secrets, and paginates by cursor', () {
    LocationChatDebugHub.recordForTesting(
      source: 'panel',
      action: 'stateReceived',
      worldId: 'w1',
      locationId: 'l1',
      details: const {'count': 1, 'authToken': 'abcdefghijklmnopqrstuvwxyz'},
      snapshotKey: 'w1|l1',
      snapshot: const {
        'messages': [
          {'localId': 'local-1', 'contentPreview': 'hello'},
        ],
      },
    );

    final snapshot = LocationChatDebugHub.snapshot();
    final events = snapshot['events'] as List<Object?>;
    expect(events, hasLength(1));
    final event = events.single as Map<String, Object?>;
    expect(event['source'], 'panel');
    expect(event['locationId'], 'l1');
    final details = event['details'] as Map<String, Object?>;
    expect(details['authToken'], 'abcd...wxyz');

    final page = LocationChatDebugHub.eventsAfter(0);
    expect(page['nextCursor'], 1);
    expect(page['latestCursor'], 1);
    expect(page['events'], hasLength(1));

    final emptyPage = LocationChatDebugHub.eventsAfter(1);
    expect(emptyPage['events'], isEmpty);
  });

  test('retains all debug events and paginates without skipping cursors', () {
    for (var index = 0; index < 1200; index += 1) {
      LocationChatDebugHub.recordForTesting(
        source: index.isEven ? 'http' : 'websocket',
        action: 'event-$index',
        details: {'index': index},
      );
    }

    final snapshot = LocationChatDebugHub.snapshot();
    expect(snapshot['events'], hasLength(1200));
    expect(snapshot['nextCursor'], 1201);

    final firstPage = LocationChatDebugHub.eventsAfter(0, limit: 100);
    expect(firstPage['events'], hasLength(100));
    expect(firstPage['nextCursor'], 100);
    expect(firstPage['latestCursor'], 1200);

    final secondPage = LocationChatDebugHub.eventsAfter(100, limit: 100);
    final secondEvents = secondPage['events'] as List<Object?>;
    expect(secondEvents, hasLength(100));
    expect((secondEvents.first as Map<String, Object?>)['cursor'], 101);
    expect(secondPage['nextCursor'], 200);
  });
}
