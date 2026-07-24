import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import 'tilemap_renderer.dart';

class TilemapRenderSettings {
  const TilemapRenderSettings({
    required this.visualMode,
    required this.fogControlPoints,
    required this.blendFogWithShadowTiles,
    required this.showShadowZeroBorders,
    required this.showLocationImageFlow,
    required this.locationImageFlowAngleDegrees,
    required this.locationImageFlowGradientPoints,
    required this.locationImageFlowOpacity,
    required this.locationImageFlowDurationSeconds,
    required this.locationImageFlowBlendMode,
    required this.initialScaleFactor,
  });

  factory TilemapRenderSettings.defaults() {
    return const TilemapRenderSettings(
      visualMode: tilemapDefaultVisualMode,
      fogControlPoints: tilemapDefaultFogControlPoints,
      blendFogWithShadowTiles: tilemapDefaultBlendFogWithShadowTiles,
      showShadowZeroBorders: tilemapDefaultShowShadowZeroBorders,
      showLocationImageFlow: tilemapDefaultShowLocationImageFlow,
      locationImageFlowAngleDegrees:
          tilemapDefaultLocationImageFlowAngleDegrees,
      locationImageFlowGradientPoints:
          tilemapDefaultLocationImageFlowGradientPoints,
      locationImageFlowOpacity: tilemapDefaultLocationImageFlowOpacity,
      locationImageFlowDurationSeconds:
          tilemapDefaultLocationImageFlowDurationSeconds,
      locationImageFlowBlendMode: tilemapDefaultLocationImageFlowBlendMode,
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
      showLocationImageFlow: json['show_location_image_flow'] is bool
          ? json['show_location_image_flow'] as bool
          : defaults.showLocationImageFlow,
      locationImageFlowAngleDegrees:
          _readDouble(
            json['location_image_flow_angle_degrees'],
            min: 0,
            max: 360,
          ) ??
          defaults.locationImageFlowAngleDegrees,
      locationImageFlowGradientPoints:
          _readLocationImageFlowGradientPoints(
            json['location_image_flow_gradient_points'],
          ) ??
          defaults.locationImageFlowGradientPoints,
      locationImageFlowOpacity:
          _readDouble(json['location_image_flow_opacity'], min: 0, max: 1) ??
          defaults.locationImageFlowOpacity,
      locationImageFlowDurationSeconds:
          _readDouble(
            json['location_image_flow_duration_seconds'],
            min: tilemapLocationImageFlowDurationSecondsMin,
            max: tilemapLocationImageFlowDurationSecondsMax,
          ) ??
          defaults.locationImageFlowDurationSeconds,
      locationImageFlowBlendMode:
          _readLocationImageFlowBlendMode(
            json['location_image_flow_blend_mode'],
          ) ??
          defaults.locationImageFlowBlendMode,
      initialScaleFactor:
          _readInitialScaleFactor(json['initial_scale_factor']) ??
          defaults.initialScaleFactor,
    );
  }

  final TilemapVisualMode visualMode;
  final List<TilemapFogControlPoint> fogControlPoints;
  final bool blendFogWithShadowTiles;
  final bool showShadowZeroBorders;
  final bool showLocationImageFlow;
  final double locationImageFlowAngleDegrees;
  final List<TilemapLocationImageFlowGradientPoint>
  locationImageFlowGradientPoints;
  final double locationImageFlowOpacity;
  final double locationImageFlowDurationSeconds;
  final TilemapLocationImageFlowBlendMode locationImageFlowBlendMode;
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
      'show_location_image_flow': showLocationImageFlow,
      'location_image_flow_angle_degrees': locationImageFlowAngleDegrees,
      'location_image_flow_gradient_points': [
        for (final point in locationImageFlowGradientPoints)
          {'position': point.position, 'color': _colorToHex(point.color)},
      ],
      'location_image_flow_opacity': locationImageFlowOpacity,
      'location_image_flow_duration_seconds': locationImageFlowDurationSeconds,
      'location_image_flow_blend_mode': locationImageFlowBlendMode.name,
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

  static double? _readDouble(
    Object? value, {
    required double min,
    required double max,
  }) {
    if (value is! num) return null;
    final resolved = value.toDouble();
    if (!resolved.isFinite || resolved < min || resolved > max) return null;
    return resolved;
  }

  static TilemapLocationImageFlowBlendMode? _readLocationImageFlowBlendMode(
    Object? value,
  ) {
    if (value is! String) return null;
    for (final mode in TilemapLocationImageFlowBlendMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  static List<TilemapLocationImageFlowGradientPoint>?
  _readLocationImageFlowGradientPoints(Object? value) {
    if (value is! List ||
        value.length != tilemapDefaultLocationImageFlowGradientPoints.length) {
      return null;
    }
    final points = <TilemapLocationImageFlowGradientPoint>[];
    for (final rawPoint in value) {
      if (rawPoint is! Map) return null;
      final position = rawPoint['position'];
      final color = _colorFromHex(rawPoint['color']);
      if (position is! num || color == null) return null;
      final resolvedPosition = position.toDouble();
      if (!resolvedPosition.isFinite ||
          resolvedPosition < 0 ||
          resolvedPosition > 1 ||
          (points.isNotEmpty &&
              resolvedPosition - points.last.position < 0.01)) {
        return null;
      }
      points.add(
        TilemapLocationImageFlowGradientPoint(
          position: resolvedPosition,
          color: color,
        ),
      );
    }
    return List<TilemapLocationImageFlowGradientPoint>.unmodifiable(points);
  }

  static String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static Color? _colorFromHex(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(normalized)) return null;
    return Color(int.parse(normalized, radix: 16));
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
