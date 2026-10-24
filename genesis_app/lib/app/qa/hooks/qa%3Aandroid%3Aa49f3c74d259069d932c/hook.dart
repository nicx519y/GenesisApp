import 'package:flutter/material.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart' show eventsPanel;
import '../qa%253Aandroid%253A896f8ec3a61f21c926bf/hook.dart' as close_events;
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart' as shared;
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/hook.dart' as world_entry;
import '../android%253Aworld.test_identity%253Avalue/identity.dart';

// The existing preparation owns identity, world, quota and connection snapshots.
// Read is observational. Preparation establishes the declared Given map page
// under the same owned route and restoration snapshot.
Future<Map<String, Object?>> read() async {
  final r = shared.resource();
  final actual = await r.read(), dataset = await r.dataset!.read();
  final world = await r.services.api.getWorld(r.worldId);
  return {
    'source': actual['source'],
    'loggedIn': actual['loggedIn'],
    'joined': actual['joinedTargetWorld'],
    'isolated': actual['isolated'],
    'recoverable': dataset['reversible'],
    'canTick':
        actual['canProgress'] == true && actual['quotaSufficient'] == true,
    'mapDisplayable': actual['mapDataAvailable'],
    'snapshotSaved': actual['snapshotCaptured'],
    'worldId': world.worldId,
    'worldName': world.name,
    'round': world.tickCount,
    'worldTime': world.currentTime,
    'mapData': await r.dataset!.selected('map'),
    'snapshotId': r.attempt,
    'resource': r.bridge.resource,
  };
}

Future<Map<String, Object?>> restore() async {
  final r = shared.resource();
  // Snapshot is read from the resource which acquired it, never manufactured here.
  // Always attempt the owner's cleanup, even if preparation failed before
  // acquiring its world snapshot. Receipt projection must not prevent release.
  // Retry completion may leave the owned Events panel open. Case and contract
  // restoration must release the same UI resource before the world snapshot.
  if (!r.restored && r.route?.isActive == true && !r.route!.isCurrent) {
    await r.requireOwner();
    final panel = eventsPanel();
    if (panel != null &&
        ModalRoute.of(panel)?.navigator == r.route!.navigator) {
      final closed =
          await close_events.invoke({'operation': 'interact'}, false, true)
              as Map<String, Object?>;
      if (closed['closed'] != true) {
        throw StateError('Owned Events panel did not close during restoration');
      }
    }
    // Unknown overlays remain protected by the owner's restore guard.
  }
  final receipt = await r.restore();
  final dataset = r.dataset;
  if (dataset == null) {
    return {
      ...receipt,
      'snapshotId': r.attempt,
      'resource': r.bridge.resource,
      'worldAcquired': false,
      'actualIdentity': await worldIdentityResource().read(),
    };
  }
  final snapshot = dataset.contractSnapshot();
  final actual = await r.services.api.v1.world.detail(worldId: r.worldId);
  final events = await r.services.api.v1.world.tickList(worldId: r.worldId);
  final quota = await r.services.api.v1.gem.wallet();
  final identity = await worldIdentityResource().read();
  const eq = DeepCollectionEqualityForWorld();
  final before = snapshot['detail'] as Map;
  if (before['relation_status'] is! String ||
      actual['relation_status'] is! String ||
      events['list'] is! List) {
    throw StateError('Restoration observation missing membership or events');
  }
  return {
    'snapshotId': r.attempt,
    'worldId': r.worldId,
    'resource': r.bridge.resource,
    'progressionMatchesSnapshot': receipt['progressStateMatchesSnapshot'],
    'eventsMatchSnapshot': receipt['eventsMatchSnapshot'],
    'quotaMatchesSnapshot': receipt['quotaMatchesSnapshot'],
    'identityMatchesSnapshot': receipt['isolatedIdentityMatchesSnapshot'],
    'membershipMatchesSnapshot': eq.equal(
      actual['relation_status'],
      before['relation_status'],
    ),
    'actualProgression': actual,
    'actualEvents': events['list'],
    'actualQuota': quota.balanceCent,
    'actualIdentity': identity,
    'actualMembership': actual['relation_status'],
  };
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1)
    throw ArgumentError('Ready parameterless operation required');
  if (p['operation'] == 'read') return read();
  if (prepared)
    throw StateError('Case preparation cannot use contract session');
  return switch (p['operation']) {
    'prepare' => prepare(prepared, started),
    'cleanup' => restore(),
    _ => throw ArgumentError('Unsupported operation'),
  };
}

Future<Object?> prepare(bool prepared, bool started) async {
  await shared.resource(acquire: true).prepare();
  final navigation =
      await world_entry.invoke({'operation': 'invoke'}, prepared, started)
          as Map<String, Object?>;
  if (navigation['targetWorldMatches'] != true ||
      navigation['mapPageVisible'] != true ||
      navigation['otherOverlayOpen'] != false) {
    throw StateError('Prepared target world map is not visible');
  }
  return {...await read(), 'onTargetWorldMap': true};
}

Future<Object?> contract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || !started || p.length != 1)
    throw StateError('Started isolated contract required');
  return switch (p['operation']) {
    'prepare' => prepare(prepared, started),
    'restore' => restore(),
    'read' => read(),
    _ => throw ArgumentError('Unsupported contract operation'),
  };
}
