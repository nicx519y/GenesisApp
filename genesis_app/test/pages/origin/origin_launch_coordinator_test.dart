import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/origin/origin_launch_coordinator.dart';
import 'package:genesis_flutter_android/pages/origin/origin_launch_pending_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OriginLaunchCoordinator.instance.resetForTesting();
  });

  tearDown(() async {
    OriginLaunchCoordinator.instance.resetForTesting();
    await OriginLaunchPendingStore.clear();
  });

  test('start saves pending launch until tick1 is ready', () async {
    var loadCount = 0;

    await OriginLaunchCoordinator.instance.start(
      originId: 'o_launching_1',
      worldId: 'w_launching_1',
      loadWorld: (worldId) async {
        loadCount += 1;
        return _worldDetail(worldId: worldId, tickCount: 0);
      },
    );
    await Future<void>.delayed(Duration.zero);

    final pending = await OriginLaunchPendingStore.load();
    expect(pending?.originId, 'o_launching_1');
    expect(pending?.worldId, 'w_launching_1');
    expect(
      OriginLaunchCoordinator.instance.state.value?.originId,
      'o_launching_1',
    );
    expect(loadCount, 1);
  });

  test('poll success clears pending launch and reports completion', () async {
    final outcomes = <OriginLaunchOutcome>[];
    final removeListener = OriginLaunchCoordinator.instance.addOutcomeListener(
      outcomes.add,
    );

    await OriginLaunchCoordinator.instance.start(
      originId: 'o_ready_1',
      worldId: 'w_ready_1',
      loadWorld: (worldId) async =>
          _worldDetail(worldId: worldId, tickCount: 1),
    );
    await Future<void>.delayed(Duration.zero);

    expect(await OriginLaunchPendingStore.load(), isNull);
    expect(OriginLaunchCoordinator.instance.state.value, isNull);
    expect(outcomes, hasLength(1));
    expect(outcomes.single.completed, isTrue);
    expect(outcomes.single.originId, 'o_ready_1');
    expect(outcomes.single.world?.tickCount, 1);

    removeListener();
  });

  test('expired pending launch clears without polling', () async {
    await OriginLaunchPendingStore.save(
      originId: 'o_timeout_1',
      worldId: 'w_timeout_1',
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'pending_origin_launch_started_at',
      DateTime.now()
          .toUtc()
          .subtract(OriginLaunchPendingStore.timeout)
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    );

    await OriginLaunchCoordinator.instance.ensurePolling(
      originId: 'o_timeout_1',
      loadWorld: (_) => fail('Expired launch should not poll world detail'),
    );

    expect(await OriginLaunchPendingStore.load(), isNull);
    expect(OriginLaunchCoordinator.instance.state.value, isNull);
  });
}

WorldDetail _worldDetail({required String worldId, required int tickCount}) {
  return WorldDetail(
    id: 1,
    worldId: worldId,
    originId: 1,
    ownerUid: 'u_owner',
    name: 'World $worldId',
    tickCount: tickCount,
    connectCount: 0,
    characterCount: 0,
    playerCount: 0,
    currentTime: '',
    latestTickAt: null,
    latestNarrator: '',
    isProgressing: false,
    relationStatus: 'owner',
    metric: const <String, dynamic>{},
    inviteToken: worldId,
    createdAt: null,
    updatedAt: null,
    origin: const OriginSummary(
      id: 1,
      oid: 'o_test',
      name: 'Origin',
      description: '',
      mapImage: '',
      worldMap: '',
      worldView: '',
      copyCount: 0,
      interactCount: 0,
      tags: <String>[],
      createdAt: null,
      updatedAt: null,
      characters: <OriginCharacter>[],
      locations: <OriginLocation>[],
    ),
    characters: const <Map<String, dynamic>>[],
    ticks: const <Map<String, dynamic>>[],
    locations: const <Map<String, dynamic>>[],
    characterPositions: const <Map<String, dynamic>>[],
    userPositions: const <Map<String, dynamic>>[],
  );
}
