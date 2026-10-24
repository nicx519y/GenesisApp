import 'outgoing_capture.dart';
import 'package:flutter/widgets.dart';
import '../../../../pages/chat/location_chat_page.dart';
import '../qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart' show activePanel;

class ParentObservation {
  ParentObservation(this.owner);
  final ParentResource owner;
  int? startSequence;
  ParentOutgoingCapture? outgoing;
  bool active = false;
  String? lastLocation;
  final entries = <String>[];
  Object? failure;
  int get childEntries => entries.where(owner.childIds.contains).length;
  void sample() {
    if (!active) return;
    try {
      final panel = activePanel()?.widget as LocationChatPanel?;
      final location = panel?.worldId == owner.worldId
          ? panel?.locationId
          : null;
      if (location != null && location != lastLocation) entries.add(location);
      lastLocation = location;
    } catch (e) {
      failure = e;
    }
  }

  void schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (active) {
        sample();
        schedule();
      }
    });
  }

  Future<Map<String, Object?>> subscribe() async {
    await owner.requireOwner();
    if (active || startSequence != null)
      throw StateError('Observation already acquired');
    final peer = owner.peer;
    if (peer == null || !peer.connected || peer.errors.isNotEmpty)
      throw StateError('Chat capture unavailable');
    outgoing = ParentOutgoingCapture(
      endpoint: Uri.parse(peer.url),
      worldId: owner.worldId,
      parentId: owner.parentId,
      heartbeatInterval: owner.isolated!.config.chatroomHeartbeatInterval,
    );
    owner.restorers.add(() async {
      active = false;
      await outgoing!.restore();
    });
    await outgoing!.start();
    startSequence = outgoing!.startSequence;
    active = true;
    sample();
    schedule();
    return {
      'observationId': 'parent-calls:${owner.bridge.resource}:$startSequence',
      'runId': owner.bridge.resource,
      'worldId': owner.worldId,
      'parentLocationId': owner.parentId,
      'startSequence': startSequence,
      'active': active,
      'capturesSend': !peer.closed,
      'capturesJoin': !peer.closed,
      'capturesLeave': !peer.closed,
    };
  }

  Future<void> requireActive() async {
    await owner.requireOwner();
    if (!active || startSequence == null)
      throw StateError('Active call observation required');
    if (failure != null) throw StateError('Page observation failed: $failure');
    if (owner.peer!.errors.isNotEmpty)
      throw StateError('Socket observation failed: ${owner.peer!.errors}');
    sample();
  }

  Future<int> count(String type) async {
    await requireActive();
    return outgoing!.count(type);
  }
}

final _observations = Expando<ParentObservation>();
ParentObservation observation({bool acquire = false}) {
  final r = resource();
  final old = _observations[r];
  if (old != null) return old;
  if (!acquire) throw StateError('Active call observation required');
  return _observations[r] = ParentObservation(r);
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1 || p['operation'] != 'subscribe')
    throw ArgumentError('Expected subscribe');
  return observation(acquire: true).subscribe();
}
