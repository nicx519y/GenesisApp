import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_renderer.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_settings_button_visibility.dart';
import 'package:genesis_flutter_android/components/tilemap/tilemap_settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tilemapVisualModeController.resetForTesting();
    tilemapSettingsButtonVisibility.resetForTesting();
  });

  test('settings button visibility defaults to false and persists', () async {
    expect(await tilemapSettingsButtonVisibility.load(), isFalse);
    expect(tilemapSettingsButtonVisibility.value, isFalse);

    await tilemapSettingsButtonVisibility.setVisible(true);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(TilemapSettingsButtonVisibilityController.storageKey),
      isTrue,
    );
    tilemapSettingsButtonVisibility.resetForTesting();
    expect(await tilemapSettingsButtonVisibility.load(), isTrue);
  });

  test('returns tilemap defaults when no cached settings exist', () async {
    final settings = await const TilemapSettingsStore().load();

    expect(settings.visualMode, tilemapDefaultVisualMode);
    expect(tilemapDefaultLoadingStyle, TilemapLoadingStyle.disabled);
    expect(settings.loadingStyle, TilemapLoadingStyle.disabled);
    expect(settings.fogControlPoints, tilemapDefaultFogControlPoints);
    expect(
      settings.blendFogWithShadowTiles,
      tilemapDefaultBlendFogWithShadowTiles,
    );
    expect(settings.cacheFogTileBitmaps, tilemapDefaultCacheFogTileBitmaps);
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
    expect(settings.initialScale, tilemapDefaultInitialScale);
    expect(
      settings.dragBoundaryPaddingTiles,
      tilemapDefaultDragBoundaryPaddingTiles,
    );
  });

  test('publishes the persisted visual mode for loading surfaces', () async {
    final cachedSettings = TilemapRenderSettings.defaults().toJson()
      ..['visual_mode'] = TilemapVisualMode.light.name;
    SharedPreferences.setMockInitialValues(<String, Object>{
      TilemapSettingsStore.storageKey: jsonEncode(cachedSettings),
    });

    final settings = await const TilemapSettingsStore().load();

    expect(settings.visualMode, TilemapVisualMode.light);
    expect(tilemapVisualModeController.value, TilemapVisualMode.light);

    await const TilemapSettingsStore().clear();

    expect(tilemapVisualModeController.value, tilemapDefaultVisualMode);
  });

  test('declares the tuned Tilemap rendering parameters as defaults', () {
    expect(TilemapRenderSettings.defaults().toJson(), {
      'schema_version': 2,
      'visual_mode': 'dark',
      'loading_style': 'disabled',
      'fog_control_points': [
        {'position': 0.0, 'opacity': 0.3011579949238584},
        {'position': 0.1972931338028169, 'opacity': 0.6031091370558366},
        {'position': 0.40459947183098594, 'opacity': 0.7530139593908627},
        {'position': 0.6516835387323944, 'opacity': 0.9032470577983234},
        {'position': 0.8515625, 'opacity': 1.0},
      ],
      'blend_fog_with_shadow_tiles': true,
      'cache_fog_tile_bitmaps': true,
      'show_shadow_zero_borders': false,
      'show_location_image_flow': true,
      'location_image_flow_angle_degrees': 267.88,
      'location_image_flow_gradient_points': [
        {'position': 0.0, 'color': '#00624700'},
        {'position': 0.24, 'color': '#556AFFA6'},
        {'position': 0.51, 'color': '#D9B9B088'},
        {'position': 0.76, 'color': '#55FFD86A'},
        {'position': 1.0, 'color': '#00926C00'},
      ],
      'location_image_flow_opacity': 0.49,
      'location_image_flow_duration_seconds': 7.5,
      'location_image_flow_blend_mode': 'plus',
      'initial_scale': 12.0,
      'drag_boundary_padding_tiles': 2.0,
    });
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
      loadingStyle: TilemapLoadingStyle.coordinatePulse,
      fogControlPoints: [
        TilemapFogControlPoint(position: 0, opacity: 0.1),
        TilemapFogControlPoint(position: 0.2, opacity: 0.3),
        TilemapFogControlPoint(position: 0.45, opacity: 0.6),
        TilemapFogControlPoint(position: 0.7, opacity: 0.8),
        TilemapFogControlPoint(position: 1, opacity: 0.95),
      ],
      blendFogWithShadowTiles: true,
      cacheFogTileBitmaps: false,
      showShadowZeroBorders: false,
      showLocationImageFlow: false,
      locationImageFlowAngleDegrees: 120,
      locationImageFlowGradientPoints: gradientPoints,
      locationImageFlowOpacity: 0.65,
      locationImageFlowDurationSeconds: 4.5,
      locationImageFlowBlendMode: TilemapLocationImageFlowBlendMode.screen,
      initialScale: 24,
      dragBoundaryPaddingTiles: 8,
    );
    const store = TilemapSettingsStore();

    await store.save(settings);
    final restored = await store.load();

    expect(restored.visualMode, TilemapVisualMode.light);
    expect(restored.loadingStyle, TilemapLoadingStyle.coordinatePulse);
    expect(restored.fogControlPoints, settings.fogControlPoints);
    expect(restored.blendFogWithShadowTiles, true);
    expect(restored.cacheFogTileBitmaps, false);
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
    expect(restored.initialScale, 24);
    expect(restored.dragBoundaryPaddingTiles, 8);

    final serialized = jsonDecode(settings.toSerializedJson());
    expect(serialized['schema_version'], 2);
    expect(serialized['visual_mode'], 'light');
    expect(serialized['loading_style'], 'coordinatePulse');
    expect(serialized['fog_control_points'], hasLength(5));
    expect(serialized['blend_fog_with_shadow_tiles'], true);
    expect(serialized['cache_fog_tile_bitmaps'], false);
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
    expect(serialized['initial_scale'], 24);
    expect(serialized['drag_boundary_padding_tiles'], 8);
  });

  test(
    'release runtime fixes loading screen to Off and initial zoom to 12x',
    () {
      const cachedSettings = TilemapRenderSettings(
        visualMode: TilemapVisualMode.light,
        loadingStyle: TilemapLoadingStyle.worldPortal,
        fogControlPoints: tilemapDefaultFogControlPoints,
        blendFogWithShadowTiles: false,
        cacheFogTileBitmaps: false,
        showShadowZeroBorders: true,
        showLocationImageFlow: false,
        locationImageFlowAngleDegrees: 120,
        locationImageFlowGradientPoints:
            tilemapDefaultLocationImageFlowGradientPoints,
        locationImageFlowOpacity: 0.65,
        locationImageFlowDurationSeconds: 4.5,
        locationImageFlowBlendMode: TilemapLocationImageFlowBlendMode.screen,
        initialScale: 24,
        dragBoundaryPaddingTiles: 8,
      );

      final releaseSettings = cachedSettings.resolveForRuntime(
        releaseMode: true,
      );
      final debugSettings = cachedSettings.resolveForRuntime(
        releaseMode: false,
      );

      expect(releaseSettings.loadingStyle, TilemapLoadingStyle.disabled);
      expect(releaseSettings.initialScale, 12);
      expect(releaseSettings.visualMode, cachedSettings.visualMode);
      expect(releaseSettings.cacheFogTileBitmaps, false);
      expect(releaseSettings.dragBoundaryPaddingTiles, 8);
      expect(debugSettings, same(cachedSettings));
    },
  );

  test('falls back only invalid cached fields', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      TilemapSettingsStore.storageKey: jsonEncode({
        'visual_mode': 'light',
        'loading_style': 'invalid',
        'fog_control_points': [
          {'position': 0.5, 'opacity': 2},
        ],
        'blend_fog_with_shadow_tiles': true,
        'cache_fog_tile_bitmaps': 'invalid',
        'show_shadow_zero_borders': false,
        'show_location_image_flow': 'invalid',
        'location_image_flow_angle_degrees': 720,
        'location_image_flow_gradient_points': [
          {'position': 0.5, 'color': '#NOTACOLOR'},
        ],
        'location_image_flow_opacity': 2,
        'location_image_flow_duration_seconds': 20,
        'location_image_flow_blend_mode': 'invalid',
        'initial_scale': 40,
        'drag_boundary_padding_tiles': 40,
      }),
    });

    final settings = await const TilemapSettingsStore().load();

    expect(settings.visualMode, TilemapVisualMode.light);
    expect(settings.loadingStyle, tilemapDefaultLoadingStyle);
    expect(settings.fogControlPoints, tilemapDefaultFogControlPoints);
    expect(settings.blendFogWithShadowTiles, true);
    expect(settings.cacheFogTileBitmaps, tilemapDefaultCacheFogTileBitmaps);
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
    expect(settings.initialScale, tilemapDefaultInitialScale);
    expect(
      settings.dragBoundaryPaddingTiles,
      tilemapDefaultDragBoundaryPaddingTiles,
    );
  });

  test(
    'old cached settings use new defaults for added render fields',
    () async {
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

      expect(settings.loadingStyle, tilemapDefaultLoadingStyle);
      expect(settings.cacheFogTileBitmaps, tilemapDefaultCacheFogTileBitmaps);
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
      expect(settings.initialScale, tilemapDefaultInitialScale);
      expect(
        settings.dragBoundaryPaddingTiles,
        tilemapDefaultDragBoundaryPaddingTiles,
      );
    },
  );

  test('clear removes cached settings and restores defaults', () async {
    const store = TilemapSettingsStore();
    const settings = TilemapRenderSettings(
      visualMode: TilemapVisualMode.light,
      loadingStyle: TilemapLoadingStyle.disabled,
      fogControlPoints: tilemapDefaultFogControlPoints,
      blendFogWithShadowTiles: false,
      cacheFogTileBitmaps: false,
      showShadowZeroBorders: true,
      showLocationImageFlow: false,
      locationImageFlowAngleDegrees: 180,
      locationImageFlowGradientPoints:
          tilemapDefaultLocationImageFlowGradientPoints,
      locationImageFlowOpacity: 0.5,
      locationImageFlowDurationSeconds: 6,
      locationImageFlowBlendMode: TilemapLocationImageFlowBlendMode.overlay,
      initialScale: 24,
      dragBoundaryPaddingTiles: 9,
    );
    await store.save(settings);

    await store.clear();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(TilemapSettingsStore.storageKey), false);
    final restored = await store.load();
    expect(restored.cacheFogTileBitmaps, tilemapDefaultCacheFogTileBitmaps);
    expect(restored.toJson(), TilemapRenderSettings.defaults().toJson());
  });
}
