import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/tilemap/tilemap_view_state.dart';

class WorldTilemapViewStore {
  WorldTilemapViewStore({
    required String namespace,
    required String uid,
    required String worldId,
  }) : _key = 'world_tilemap_view_v1:${jsonEncode([namespace, uid, worldId])}';

  final String _key;
  // Reads on a newly opened page must see writes from the page just closed.
  static Future<void>? _writes;

  Future<TilemapViewState?> load() async {
    try {
      await _writes;
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key);
      return raw == null ? null : TilemapViewState.fromJson(jsonDecode(raw));
    } catch (error) {
      debugPrint('[WorldTilemapViewStore] load failed: $error');
      return null;
    }
  }

  Future<void> save(TilemapViewState state) {
    final encoded = jsonEncode(state.toJson());
    Future<void> write() async {
      try {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(_key, encoded);
      } catch (error) {
        debugPrint('[WorldTilemapViewStore] save failed: $error');
      }
    }

    final pending = _writes;
    late final Future<void> result;
    result = (pending == null ? write() : pending.then((_) => write()))
        .whenComplete(() {
          if (identical(_writes, result)) _writes = null;
        });
    _writes = result;
    return result;
  }
}
