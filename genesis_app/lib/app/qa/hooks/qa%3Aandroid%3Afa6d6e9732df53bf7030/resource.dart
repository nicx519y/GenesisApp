import 'dart:async';
import 'package:flutter/material.dart';
import '../../../genesis_navigator.dart';
import '../../../bootstrap/app_services_scope.dart';
import '../../../bootstrap/service_registry.dart';
import '../../../../pages/world/world_page.dart';
import '../../../../network/models/location_tree.dart';
import '../../../../network/models/world.dart';
import '../../../../pages/world/world_bottom_sheet.dart';
import '../../../../components/world_location_list.dart';
import '../../../../ui/navigation/genesis_dark_page_route.dart';
import '../../qa_bridge.dart';
import '../android%253Aworld.test_identity%253Avalue/identity.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import '../android%253Aworld.selected.map_renderable%253Avalid/observation.dart';
import '../qa%253Aandroid%253Abf448f29b28c4fce0618/resource.dart'
    show WorldMembership;
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart'
    show elements, visible;
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart'
    show observedRoute;
import 'peer.dart';
import 'chat_identity.dart';

/// Select an actual non-leaf location, never the model's unnamed map wrapper.
/// Keep incomplete real data visible as an error instead of inventing a name.
LocationTreeNode<Map<String, dynamic>> selectParentLocation(
  ProcessedLocationTree<Map<String, dynamic>> tree,
) {
  final parents = tree.flattened.where(
    (node) =>
        node.id != 'root' &&
        node.id != worldSyntheticRootLocationId &&
        node.value['synthetic_root'] != true &&
        node.children.isNotEmpty,
  );
  if (parents.isEmpty) throw StateError('Mock dataset has no non-leaf parent');
  return parents.first;
}

/// Owns the mock identity, original world responses and loopback transport.
/// Does not acquire a leaf-chat fixture or alter the location hierarchy.
class ParentResource {
  ParentResource(this.bridge);
  final QaBridge bridge;
  WorldDataset? dataset;
  WorldMembership? membership;
  ParentPeer? peer;
  AppServices? isolated;
  Route<void>? route;
  Route<dynamic>? previousRoute;
  bool identityAcquired = false,
      mounted = false,
      released = false,
      restored = false;
  String parentId = '', parentName = '';
  List<String> childIds = [];
  Map<String, Object?>? receipt;
  final restorers = <Future<void> Function()>[];
  String get snapshotId => 'parent:${bridge.resource}';
  String get worldId => dataset!.selectedId!;
  AppServices get services =>
      AppServicesScope.read(genesisNavigatorKey.currentContext!);
  Future<void> requireOwner() async {
    if (restored ||
        !identical(QaBridge.current, bridge) ||
        dataset?.active != true)
      throw StateError('Parent preparation required');
    await dataset!.requireOwner();
  }

  Future<Map<String, Object?>> prepare() async {
    if (identityAcquired)
      throw StateError('Parent preparation already acquired');
    identityAcquired = true;
    await worldIdentityResource().prepare();
    await prepareParentChatIdentity(worldIdentityResource());
    dataset = await worldDatasetResource(acquire: true);
    await dataset!.prepare();
    membership = WorldMembership(dataset!);
    await membership!.prepare();
    final world = await services.api.getWorld(worldId);
    final parent = selectParentLocation(world.processedLocationTree);
    parentId = parent.id;
    parentName =
        '${parent.value['name'] ?? parent.value['location_name'] ?? ''}';
    void collect(dynamic n) {
      for (final child in n.children) {
        childIds.add(child.id as String);
        collect(child);
      }
    }

    collect(parent);
    if (parentName.isEmpty || childIds.isEmpty)
      throw StateError('Parent identity incomplete');
    peer = ParentPeer(worldId, worldIdentityResource().uid, requireOwner);
    await peer!.open();
    isolated = ServiceRegistry.build(
      config: services.config.copyWith(chatroomWsBaseUrl: peer!.url),
      deviceIdOverride: services.deviceId,
      sessionStoreOverride: bridge.store,
    );
    final nav = genesisNavigatorKey.currentState!;
    final previous = elements()
        .map(observedRoute)
        .whereType<Route<dynamic>>()
        .where((r) => r.isCurrent && r.navigator == nav)
        .toSet();
    if (previous.length != 1) throw StateError('Ambiguous original route');
    previousRoute = previous.single;
    route = GenesisDarkPageRoute<void>(
      builder: (_) {
        mounted = true;
        return AppServicesScope(
          services: isolated!,
          child: WorldPage(wid: worldId),
        );
      },
    );
    unawaited(nav.push(route!));
    await WidgetsBinding.instance.endOfFrame;
    return read();
  }

  Future<Map<String, Object?>> read() async {
    await requireOwner();
    final world = await services.api.getWorld(worldId),
        identity = await worldIdentityResource().read();
    final parent = world.processedLocationTree.nodeById(parentId);
    return {
      'snapshotId': snapshotId,
      'runId': bridge.resource,
      'resource': bridge.resource,
      'identityId': identity['uid'],
      'worldId': world.worldId,
      'worldName': world.name,
      'currentTime': world.currentTime,
      'parentLocationId': parentId,
      'parentLocationName': parentName,
      'childLocationIds': childIds,
      'isolated': identity['isolated'],
      'loggedIn': identity['loggedIn'],
      'joinedWorld': ['joined', 'owner'].contains(world.relationStatus),
      'mapRenderable': extractObservation(await dataset!.selected('map')),
      'parentIsLeaf': parent?.children.isEmpty,
      'parentHasChildren': parent?.children.isNotEmpty,
    };
  }

  Future<Map<String, Object?>> restore() async {
    if (!identityAcquired || !identical(QaBridge.current, bridge))
      throw StateError('No owned parent snapshot');
    if (restored) return receipt!;
    final errors = <Object>[];
    for (final release in restorers.reversed) {
      try {
        await release();
      } catch (e) {
        errors.add(e);
      }
    }
    // Unknown overlays must be left intact for diagnosis.
    try {
      if (route?.isActive == true) {
        if (!route!.isCurrent) {
          final sheets = elements()
              .where(
                (e) =>
                    e.widget is WorldSingleSectionBottomSheet &&
                    identical(
                      (e.widget as WorldSingleSectionBottomSheet).services,
                      isolated,
                    ) &&
                    (e.widget as WorldSingleSectionBottomSheet)
                            .initialWorld
                            .worldId ==
                        worldId &&
                    ModalRoute.of(e)?.isCurrent == true &&
                    ModalRoute.of(e)?.navigator == route!.navigator &&
                    elements(
                      e,
                    ).any((c) => c.widget is WorldLocationList && visible(c)),
              )
              .toList();
          if (sheets.length != 1)
            throw StateError('Foreign overlay above owned parent world');
          route!.navigator!.removeRoute(ModalRoute.of(sheets.single)!);
          await WidgetsBinding.instance.endOfFrame;
          if (!route!.isCurrent)
            throw StateError('Owned Locations did not close');
        }
        route!.navigator!.removeRoute(route!);
        await WidgetsBinding.instance.endOfFrame;
        released = true;
      }
      if (!mounted && isolated != null && !released) {
        isolated!.dispose();
        released = true;
      }
    } catch (e) {
      errors.add(e);
    }
    try {
      if (peer?.acquired == true) await peer!.close();
    } catch (e) {
      errors.add(e);
    }
    Map<String, dynamic>? world, member;
    Map<String, Object?>? identity;
    if (errors.isEmpty) {
      try {
        if (dataset?.active == true) world = await dataset!.restore();
      } catch (e) {
        errors.add(e);
      }
      try {
        if (membership != null) member = await membership!.restore();
      } catch (e) {
        errors.add(e);
      }
      if (errors.isEmpty) {
        try {
          identity = await worldIdentityResource().restore();
        } catch (e) {
          errors.add(e);
        }
      }
    }
    if (errors.isNotEmpty) throw ParentCleanupFailure(errors);
    final configMatches =
        (peer == null || peer!.closed) &&
        (isolated == null || released) &&
        (route == null || !route!.isActive);
    receipt = {
      'snapshotId': snapshotId,
      'runId': bridge.resource,
      'resource': bridge.resource,
      'restoredResources': [
        if (identity != null) 'identity',
        if (world != null) 'world',
        if (member != null) 'membership',
        if (configMatches) 'chatConfiguration',
      ],
      'identityMatchesSnapshot': identity?['matchesSnapshot'],
      'worldMatchesSnapshot': world?['matchesSnapshot'],
      'membershipMatchesSnapshot': member?['matchesSnapshot'],
      'chatConfigurationMatchesSnapshot': configMatches,
    };
    if (identity?['matchesSnapshot'] != true ||
        (dataset != null && world?['matchesSnapshot'] != true) ||
        (membership != null && member?['matchesSnapshot'] != true) ||
        !configMatches)
      throw StateError('Parent restoration mismatch');
    restored = true;
    return receipt!;
  }
}

class ParentCleanupFailure implements Exception {
  ParentCleanupFailure(this.errors);
  final List<Object> errors;
  @override
  String toString() => 'Parent cleanup failed: ${errors.join(' | ')}';
}

final _resources = Expando<ParentResource>();
ParentResource resource({bool acquire = false}) {
  final b = QaBridge.current;
  if (b == null || const String.fromEnvironment('GENESIS_API_ENV') != 'mock')
    throw StateError('Authenticated mock session required');
  final old = _resources[b];
  if (old != null) return old;
  if (!acquire) throw StateError('Parent preparation required');
  return _resources[b] = ParentResource(b);
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1)
    throw ArgumentError('Ready parameterless operation required');
  if (p['operation'] == 'read') return resource().read();
  if (prepared)
    throw StateError('Case preparation cannot use contract session');
  return switch (p['operation']) {
    'prepare' => resource(acquire: true).prepare(),
    'restore' || 'cleanup' => resource().restore(),
    _ => throw ArgumentError('Unsupported operation'),
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
    'prepare' => resource(acquire: true).prepare(),
    'restore' => resource().restore(),
    _ => throw ArgumentError('Unsupported fixture operation'),
  };
}
