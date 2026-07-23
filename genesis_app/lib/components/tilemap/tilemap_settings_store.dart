import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'tilemap_renderer.dart';

class TilemapRenderSettings {
  const TilemapRenderSettings({
    required this.visualMode,
    required this.fogControlPoints,
    required this.blendFogWithShadowTiles,
    required this.showShadowZeroBorders,
    required this.initialScaleFactor,
  });

  factory TilemapRenderSettings.defaults() {
    return const TilemapRenderSettings(
      visualMode: tilemapDefaultVisualMode,
      fogControlPoints: tilemapDefaultFogControlPoints,
      blendFogWithShadowTiles: tilemapDefaultBlendFogWithShadowTiles,
      showShadowZeroBorders: tilemapDefaultShowShadowZeroBorders,
      initialScaleFactor: tilemapDefaultInitialScaleFactor,
    );
  }

  factory TilemapRenderSettings.fromJson(Map<String, dynamic> json) {
    final defaults = TilemapRenderSettings.defaults();
    final visualMode = switch (json['visual_mode']) {
      'light' => TilemapVisualMode.light,
      'dark' => TilemapVisualMode.dark,
      _ => defaults.visualMode,
    };
    return TilemapRenderSettings(
      visualMode: visualMode,
      fogControlPoints:
          _readFogControlPoints(json['fog_control_points']) ??
          defaults.fogControlPoints,
      blendFogWithShadowTiles: json['blend_fog_with_shadow_tiles'] is bool
          ? json['blend_fog_with_shadow_tiles'] as bool
          : defaults.blendFogWithShadowTiles,
      showShadowZeroBorders: json['show_shadow_zero_borders'] is bool
          ? json['show_shadow_zero_borders'] as bool
          : defaults.showShadowZeroBorders,
      initialScaleFactor:
          _readInitialScaleFactor(json['initial_scale_factor']) ??
          defaults.initialScaleFactor,
    );
  }

  final TilemapVisualMode visualMode;
  final List<TilemapFogControlPoint> fogControlPoints;
  final bool blendFogWithShadowTiles;
  final bool showShadowZeroBorders;
  final double initialScaleFactor;

  String toSerializedJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': 1,
      'visual_mode': visualMode.name,
      'fog_control_points': [
        for (final point in fogControlPoints)
          {'position': point.position, 'opacity': point.opacity},
      ],
      'blend_fog_with_shadow_tiles': blendFogWithShadowTiles,
      'show_shadow_zero_borders': showShadowZeroBorders,
      'initial_scale_factor': initialScaleFactor,
    };
  }

  static double? _readInitialScaleFactor(Object? value) {
    if (value is! num) return null;
    final resolved = value.toDouble();
    if (!resolved.isFinite ||
        resolved < tilemapInitialScaleFactorMin ||
        resolved > tilemapInitialScaleFactorMax) {
      return null;
    }
    return resolved;
  }

  static List<TilemapFogControlPoint>? _readFogControlPoints(Object? value) {
    if (value is! List ||
        value.length != tilemapDefaultFogControlPoints.length) {
      return null;
    }
    final points = <TilemapFogControlPoint>[];
    for (final rawPoint in value) {
      if (rawPoint is! Map) return null;
      final position = rawPoint['position'];
      final opacity = rawPoint['opacity'];
      if (position is! num || opacity is! num) return null;
      final resolvedPosition = position.toDouble();
      final resolvedOpacity = opacity.toDouble();
      if (!resolvedPosition.isFinite ||
          !resolvedOpacity.isFinite ||
          resolvedPosition < 0 ||
          resolvedPosition > 1 ||
          resolvedOpacity < 0 ||
          resolvedOpacity > 1) {
        return null;
      }
      if (points.isNotEmpty && resolvedPosition - points.last.position < 0.01) {
        return null;
      }
      points.add(
        TilemapFogControlPoint(
          position: resolvedPosition,
          opacity: resolvedOpacity,
        ),
      );
    }
    return List<TilemapFogControlPoint>.unmodifiable(points);
  }
}

class TilemapSettingsStore {
  const TilemapSettingsStore();

  static const String storageKey = 'tilemap_render_settings_v1';

  Future<TilemapRenderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return TilemapRenderSettings.defaults();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return TilemapRenderSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return TilemapRenderSettings.fromJson(
          decoded.map((key, value) => MapEntry('$key', value)),
        );
      }
    } catch (_) {
      return TilemapRenderSettings.defaults();
    }
    return TilemapRenderSettings.defaults();
  }

  Future<void> save(TilemapRenderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
