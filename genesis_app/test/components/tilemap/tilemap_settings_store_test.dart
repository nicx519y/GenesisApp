import 'dart:convert';

import 'package:flutter/material.dart';
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
    expect(settings.showLocationImageFlow, tilemapDefaultShowLocationImageFlow);
    expect(
      settings.locationImageFlowAngleDegrees,
      tilemapDefaultLocationImageFlowAngleDegrees,
    );
    expect(
      settings.locationImageFlowGradientPoints,
      tilemapDefaultLocationImageFlowGradientPoints,
    );
    expect(
      settings.locationImageFlowOpacity,
      tilemapDefaultLocationImageFlowOpacity,
    );
    expect(
      settings.locationImageFlowDurationSeconds,
      tilemapDefaultLocationImageFlowDurationSeconds,
    );
    expect(
      settings.locationImageFlowBlendMode,
      tilemapDefaultLocationImageFlowBlendMode,
    );
    expect(settings.initialScaleFactor, tilemapDefaultInitialScaleFactor);
  });

  test('round trips every tilemap rendering setting', () async {
    const gradientPoints = [
      TilemapLocationImageFlowGradientPoint(
        position: 0,
        color: Color(0x0000FFFF),
      ),
      TilemapLocationImageFlowGradientPoint(
        position: 0.2,
        color: Color(0x5500FFFF),
      ),
      TilemapLocationImageFlowGradientPoint(
        position: 0.48,
        color: Color(0xD9FFFFFF),
      ),
      TilemapLocationImageFlowGradientPoint(
        position: 0.8,
        color: Color(0x5500FFFF),
      ),
      TilemapLocationImageFlowGradientPoint(
        position: 1,
        color: Color(0x0000FFFF),
      ),
    ];
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
      showLocationImageFlow: false,
      locationImageFlowAngleDegrees: 120,
      locationImageFlowGradientPoints: gradientPoints,
      locationImageFlowOpacity: 0.65,
      locationImageFlowDurationSeconds: 4.5,
      locationImageFlowBlendMode: TilemapLocationImageFlowBlendMode.screen,
      initialScaleFactor: 1.25,
    );
    const store = TilemapSettingsStore();

    await store.save(settings);
    final restored = await store.load();

    expect(restored.visualMode, TilemapVisualMode.light);
    expect(restored.fogControlPoints, settings.fogControlPoints);
    expect(restored.blendFogWithShadowTiles, true);
    expect(restored.showShadowZeroBorders, false);
    expect(restored.showLocationImageFlow, false);
    expect(restored.locationImageFlowAngleDegrees, 120);
    expect(restored.locationImageFlowGradientPoints, gradientPoints);
    expect(restored.locationImageFlowOpacity, 0.65);
    expect(restored.locationImageFlowDurationSeconds, 4.5);
    expect(
      restored.locationImageFlowBlendMode,
      TilemapLocationImageFlowBlendMode.screen,
    );
    expect(restored.initialScaleFactor, 1.25);

    final serialized = jsonDecode(settings.toSerializedJson());
    expect(serialized['schema_version'], 1);
    expect(serialized['visual_mode'], 'light');
    expect(serialized['fog_control_points'], hasLength(5));
    expect(serialized['blend_fog_with_shadow_tiles'], true);
    expect(serialized['show_shadow_zero_borders'], false);
    expect(serialized['show_location_image_flow'], false);
    expect(serialized['location_image_flow_angle_degrees'], 120);
    expect(serialized['location_image_flow_gradient_points'], hasLength(5));
    expect(serialized['location_image_flow_gradient_points'][2], {
      'position': 0.48,
      'color': '#D9FFFFFF',
    });
    expect(serialized['location_image_flow_opacity'], 0.65);
    expect(serialized['location_image_flow_duration_seconds'], 4.5);
    expect(serialized['location_image_flow_blend_mode'], 'screen');
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
        'show_location_image_flow': 'invalid',
        'location_image_flow_angle_degrees': 720,
        'location_image_flow_gradient_points': [
          {'position': 0.5, 'color': '#NOTACOLOR'},
        ],
        'location_image_flow_opacity': 2,
        'location_image_flow_duration_seconds': 20,
        'location_image_flow_blend_mode': 'invalid',
        'initial_scale_factor': 4,
      }),
    });

    final settings = await const TilemapSettingsStore().load();

    expect(settings.visualMode, TilemapVisualMode.light);
    expect(settings.fogControlPoints, tilemapDefaultFogControlPoints);
    expect(settings.blendFogWithShadowTiles, true);
    expect(settings.showShadowZeroBorders, false);
    expect(settings.showLocationImageFlow, true);
    expect(
      settings.locationImageFlowAngleDegrees,
      tilemapDefaultLocationImageFlowAngleDegrees,
    );
    expect(
      settings.locationImageFlowGradientPoints,
      tilemapDefaultLocationImageFlowGradientPoints,
    );
    expect(
      settings.locationImageFlowOpacity,
      tilemapDefaultLocationImageFlowOpacity,
    );
    expect(
      settings.locationImageFlowDurationSeconds,
      tilemapDefaultLocationImageFlowDurationSeconds,
    );
    expect(
      settings.locationImageFlowBlendMode,
      tilemapDefaultLocationImageFlowBlendMode,
    );
    expect(settings.initialScaleFactor, tilemapDefaultInitialScaleFactor);
  });

  test('old cached settings default the location shimmer to enabled', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TilemapSettingsStore.storageKey: jsonEncode({
        'schema_version': 1,
        'visual_mode': 'light',
        'fog_control_points': [
          for (final point in tilemapDefaultFogControlPoints)
            {'position': point.position, 'opacity': point.opacity},
        ],
        'blend_fog_with_shadow_tiles': false,
        'show_shadow_zero_borders': true,
        'initial_scale_factor': 1,
      }),
    });

    final settings = await const TilemapSettingsStore().load();

    expect(settings.showLocationImageFlow, true);
    expect(
      settings.locationImageFlowAngleDegrees,
      tilemapDefaultLocationImageFlowAngleDegrees,
    );
    expect(
      settings.locationImageFlowGradientPoints,
      tilemapDefaultLocationImageFlowGradientPoints,
    );
    expect(
      settings.locationImageFlowOpacity,
      tilemapDefaultLocationImageFlowOpacity,
    );
    expect(
      settings.locationImageFlowDurationSeconds,
      tilemapDefaultLocationImageFlowDurationSeconds,
    );
    expect(
      settings.locationImageFlowBlendMode,
      tilemapDefaultLocationImageFlowBlendMode,
    );
  });

  test('clear removes cached settings and restores defaults', () async {
    const store = TilemapSettingsStore();
    const settings = TilemapRenderSettings(
      visualMode: TilemapVisualMode.light,
      fogControlPoints: tilemapDefaultFogControlPoints,
      blendFogWithShadowTiles: false,
      showShadowZeroBorders: true,
      showLocationImageFlow: false,
      locationImageFlowAngleDegrees: 180,
      locationImageFlowGradientPoints:
          tilemapDefaultLocationImageFlowGradientPoints,
      locationImageFlowOpacity: 0.5,
      locationImageFlowDurationSeconds: 6,
      locationImageFlowBlendMode: TilemapLocationImageFlowBlendMode.overlay,
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
