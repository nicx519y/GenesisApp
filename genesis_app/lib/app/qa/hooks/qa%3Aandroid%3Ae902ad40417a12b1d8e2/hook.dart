import 'event_content.dart';
import '../../fixtures/http/mock_response_registry.dart' as mock_responses;
import 'completion.dart';
import 'dart:convert';
import '../../../../network/http_transport.dart';
import '../../qa_bridge.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';

class TickSuccess {
  TickSuccess(this.owner);
  final TickPreparation owner;
  Map<String, dynamic>? beforeEvents;
  bool active = false;
  mock_responses.QaMockResponderRegistration? responseRegistration;
  late final attempt = TickAttempt(finish: finish);
  bool get completed => attempt.completed;
  int get submissions => attempt.submissions;
  Object? get failure => attempt.failure;
  int newRound = 0;
  String newTime = '', content = '';

  Map<String, dynamic> get event => {
    'tick_id': 'qa-${owner.attempt}',
    'tick_no': newRound,
    'sub_tick_no': 0,
    'status': 50,
    'created_at': 1700000000,
    'tick_result': {
      'current_time': newTime,
      'narrator': content,
      'paragraphs': [],
    },
  };
  Future<Map<String, Object?>> prepare() async {
    await owner.requireOwner();
    if (active || beforeEvents != null)
      throw StateError('Success configuration already acquired');
    beforeEvents = copyWorldJson(
      await owner.services.api.v1.world.tickList(worldId: owner.worldId),
    );
    final world = await owner.services.api.getWorld(owner.worldId);
    newRound = world.tickCount + 1;
    newTime = 'Day $newRound, 09:17';
    content = tickEventContent(owner.attempt);
    active = true;
    owner.eventsRestored = false;
    owner.restorers.add(restore);
    responseRegistration = mock_responses.registerQaHook(
      'qa:android:e902ad40417a12b1d8e2:success',
      respondTick,
      methods: {'GET', 'POST'},
    );
    return read();
  }

  Future<Map<String, Object?>> read() async {
    await owner.requireOwner();
    final actual = await owner.services.api.v1.world.tickList(
      worldId: owner.worldId,
    );
    return {
      'resource': owner.bridge.resource,
      'source': 'mock',
      'outcome': active ? 'success' : 'unconfigured',
      'newRoundDefined': active && newRound > 0,
      'worldTimeDefined': active && newTime.isNotEmpty,
      'roundEventsDefined': active && content.isNotEmpty,
      'appDataPathConfigured':
          active &&
          const DeepCollectionEqualityForWorld().equal(actual, events()),
      'newRound': newRound,
      'worldTime': newTime,
    };
  }

  Map<String, dynamic> events() => completed
      ? {
          'list': [event],
          'total': 1,
          'pn': 1,
          'rn': 20,
          'has_more': false,
        }
      : copyWorldJson(beforeEvents!);
  Future<void> finish() async {
    await owner.requireOwner();
    if (!active) throw StateError('Success configuration released');
    for (final endpoint in ['detail', 'info']) {
      final raw = await owner.dataset!.selected(endpoint);
      final next = completedResponse(raw, newRound, newTime, event);
      for (final key in ['info', 'stats', 'tick_list', 'ticks']) {
        if (next.containsKey(key))
          await owner.dataset!.replace(endpoint, [key], next[key]);
      }
    }
  }

  Future<void> restore() async {
    if (beforeEvents == null) throw StateError('No success snapshot acquired');
    await attempt.close();
    active = false;
    responseRegistration?.close();
    responseRegistration = null;
    final actual = await owner.services.api.v1.world.tickList(
      worldId: owner.worldId,
    );
    owner.eventsRestored = const DeepCollectionEqualityForWorld().equal(
      actual,
      beforeEvents,
    );
    if (!owner.eventsRestored) throw StateError('Events restoration mismatch');
  }

  Future<TransportResponse?> respond(TransportRequest q) async {
    if (!active) return null;
    final path = q.uri.path, method = q.method.toUpperCase();
    if (method == 'POST' && path != '/api/v1/world/tick') return null;
    final body = method == 'POST' && q.bodyBytes != null
        ? jsonDecode(utf8.decode(q.bodyBytes!))
        : null;
    final id = method == 'POST' && body is Map
        ? body['world_id']
        : q.uri.queryParameters['world_id'];
    if (id != owner.worldId) return null;
    if (method == 'POST' && path == '/api/v1/world/tick') {
      await owner.requireOwner();
      q.cancellationToken?.throwIfCancelled();
      attempt.submit();
      return jsonResponse({'world_id': owner.worldId, 'tick_cnt': newRound});
    }
    if (method != 'GET') return null;
    if (![
      '/aitown-chat/internal/tick/is_locked',
      '/api/v1/world/tick/list',
      '/api/v1/world/detail',
      '/api/v1/world/info',
    ].contains(path))
      return null;
    await owner.requireOwner();
    q.cancellationToken?.throwIfCancelled();
    if (path.endsWith('/is_locked'))
      return jsonResponse({'is_locked': submissions > 0 && !completed});
    if (path.endsWith('/tick/list')) return jsonResponse(events());
    return null;
  }
}

final configurations = Expando<TickSuccess>();
TickSuccess success({bool acquire = false}) {
  final r = resource();
  final old = configurations[r];
  if (old != null) return old;
  if (!acquire) throw StateError('Tick success configuration required');
  return configurations[r] = TickSuccess(r);
}

Future<TransportResponse?> respondTick(TransportRequest q) async {
  final b = QaBridge.current, r = b == null ? null : resources[b];
  return r == null ? null : await configurations[r]?.respond(q);
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1)
    throw ArgumentError('Ready parameterless operation required');
  if (p['operation'] == 'read') return success().read();
  if (prepared)
    throw StateError('Case preparation cannot use contract session');
  return switch (p['operation']) {
    'prepare' => success(acquire: true).prepare(),
    'cleanup' => cleanup(),
    _ => throw ArgumentError('Unsupported operation'),
  };
}

Future<Map<String, Object?>> cleanup() async {
  final s = success();
  await s.restore();
  return {
    'restored': !s.active,
    'matchesSnapshot': s.owner.eventsRestored,
    'resource': s.owner.bridge.resource,
  };
}

Future<Object?> contract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  return switch (p['operation']) {
    'prepare' => success(acquire: true).prepare(),
    'read' => success().read(),
    'cleanup' => cleanup(),
    _ => throw ArgumentError('Unsupported contract operation'),
  };
}
