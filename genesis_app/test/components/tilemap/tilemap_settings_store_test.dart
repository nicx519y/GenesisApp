import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns tilemap defaults when no cached settings exist', () async {
    final settings = await const TilemapSettingsStore().load();

    expect(settings.visualMode, tilemapDefaultVisualMode);
    expect(settings.fogControlPoints, tilemapDefaultFogControlPoints);
    expect(
      settings.blendFogWithShadowTiles,
      tilemapDefaultBlendFogWithShadowTiles,
    );
    expect(settings.showShadowZeroBorders, tilemapDefaultShowShadowZeroBorders);
    expect(settings.initialScaleFactor, tilemapDefaultInitialScaleFactor);
  });

  test('round trips every tilemap rendering setting', () async {
    const settings = TilemapRenderSettings(
      visualMode: TilemapVisualMode.light,
      fogControlPoints: [
        TilemapFogControlPoint(position: 0, opacity: 0.1),
        TilemapFogControlPoint(position: 0.2, opacity: 0.3),
        TilemapFogControlPoint(position: 0.45, opacity: 0.6),
        TilemapFogControlPoint(position: 0.7, opacity: 0.8),
        TilemapFogControlPoint(position: 1, opacity: 0.95),
      ],
      blendFogWithShadowTiles: true,
      showShadowZeroBorders: false,
      initialScaleFactor: 1.25,
    );
    const store = TilemapSettingsStore();

    await store.save(settings);
    final restored = await store.load();

    expect(restored.visualMode, TilemapVisualMode.light);
    expect(restored.fogControlPoints, settings.fogControlPoints);
    expect(restored.blendFogWithShadowTiles, true);
    expect(restored.showShadowZeroBorders, false);
    expect(restored.initialScaleFactor, 1.25);

    final serialized = jsonDecode(settings.toSerializedJson());
    expect(serialized['schema_version'], 1);
    expect(serialized['visual_mode'], 'light');
    expect(serialized['fog_control_points'], hasLength(5));
    expect(serialized['blend_fog_with_shadow_tiles'], true);
    expect(serialized['show_shadow_zero_borders'], false);
    expect(serialized['initial_scale_factor'], 1.25);
  });

  test('falls back only invalid cached fields', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TilemapSettingsStore.storageKey: jsonEncode({
        'visual_mode': 'light',
        'fog_control_points': [
          {'position': 0.5, 'opacity': 2},
        ],
        'blend_fog_with_shadow_tiles': true,
        'show_shadow_zero_borders': false,
        'initial_scale_factor': 4,
      }),
    });

    final settings = await const TilemapSettingsStore().load();

    expect(settings.visualMode, TilemapVisualMode.light);
    expect(settings.fogControlPoints, tilemapDefaultFogControlPoints);
    expect(settings.blendFogWithShadowTiles, true);
    expect(settings.showShadowZeroBorders, false);
    expect(settings.initialScaleFactor, tilemapDefaultInitialScaleFactor);
  });

  test('clear removes cached settings and restores defaults', () async {
    const store = TilemapSettingsStore();
    const settings = TilemapRenderSettings(
      visualMode: TilemapVisualMode.light,
      fogControlPoints: tilemapDefaultFogControlPoints,
      blendFogWithShadowTiles: false,
      showShadowZeroBorders: true,
      initialScaleFactor: 1.25,
    );
    await store.save(settings);

    await store.clear();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(TilemapSettingsStore.storageKey), false);
    final restored = await store.load();
    expect(restored.toJson(), TilemapRenderSettings.defaults().toJson());
  });
}
