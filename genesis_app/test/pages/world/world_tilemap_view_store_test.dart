import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_view_state.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/world/world_page.dart';
import 'package:genesis_flutter_android/pages/world/world_tilemap_view_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  WorldTilemapViewStore store({
    String namespace = 'dev',
    String uid = 'u1',
    String wid = 'w1',
  }) => WorldTilemapViewStore(namespace: namespace, uid: uid, worldId: wid);

  TilemapViewState state({
    String current = 'branch',
    List<String> trail = const ['root'],
  }) => TilemapViewState(
    initialLocationId: 'root',
    currentLocationId: current,
    locationTrail: trail,
    viewportTransforms: {
      'world:w1:branch': Matrix4.identity()
        ..translateByDouble(25, 40, 0, 1)
        ..scaleByDouble(2, 2, 1, 1),
    },
  );

  test(
    'new store reads the final pending write including hierarchy and viewport',
    () async {
      final expected = state();
      final pending = store().save(expected);
      final restored = await store().load();
      await pending;
      expect(restored!.toJson(), expected.toJson());
    },
  );

  test('records are isolated by environment, account and world', () async {
    await store().save(state());
    expect(await store(namespace: 'production').load(), isNull);
    expect(await store(uid: 'u2').load(), isNull);
    expect(await store(wid: 'w2').load(), isNull);
    expect(await store(uid: '').load(), isNull);
  });

  test('invalid JSON and singular transforms fall back safely', () async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'world_tilemap_view_v1:${jsonEncode(['dev', 'u1', 'w1'])}';
    await prefs.setString(key, '{broken');
    expect(await store().load(), isNull);
    final json = state().toJson();
    json['viewport_transforms'] = {'bad': List.filled(16, 0)};
    await prefs.setString(key, jsonEncode(json));
    expect((await store().load())!.viewportTransforms, isEmpty);
  });

  test('deleted locations, cycles and unrelated back paths are rejected', () {
    final tree = WorldDetail.fromJson({
      'world_id': 'w1',
      'locations': [
        {
          'location_id': 'branch',
          'children': [
            {'location_id': 'child'},
          ],
        },
        {'location_id': 'sibling'},
      ],
    }).processedLocationTree;
    expect(worldTilemapViewIsValid(state(), tree), isTrue);
    expect(worldTilemapViewIsValid(state(current: 'deleted'), tree), isFalse);
    expect(
      worldTilemapViewIsValid(state(trail: ['root', 'branch']), tree),
      isFalse,
    );
    expect(
      worldTilemapViewIsValid(state(trail: ['root', 'sibling']), tree),
      isFalse,
    );
  });
}
