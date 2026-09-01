import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import 'tilemap_renderer.dart';

enum TilemapLoadingStyle {
  disabled,
  tileAssembly,
  worldPortal,
  progressiveReveal,
  coordinatePulse,
  minimalProgress,
}

const TilemapLoadingStyle tilemapDefaultLoadingStyle =
    TilemapLoadingStyle.disabled;

class TilemapVisualModeController extends ValueNotifier<TilemapVisualMode> {
  TilemapVisualModeController() : super(tilemapDefaultVisualMode);

  bool _isHydrated = false;

  bool get isHydrated => _isHydrated;

  void setVisualMode(TilemapVisualMode mode) {
    _isHydrated = true;
    if (value == mode) return;
    value = mode;
  }

  @visibleForTesting
  void resetForTesting() {
    _isHydrated = false;
    value = tilemapDefaultVisualMode;
  }
}

final TilemapVisualModeController tilemapVisualModeController =
    TilemapVisualModeController();

class TilemapRenderSettings {
  const TilemapRenderSettings({
    required this.visualMode,
    required this.loadingStyle,
    required this.fogControlPoints,
    required this.blendFogWithShadowTiles,
    required this.cacheFogTileBitmaps,
    required this.showShadowZeroBorders,
    required this.showLocationImageFlow,
    required this.locationImageFlowAngleDegrees,
    required this.locationImageFlowGradientPoints,
    required this.locationImageFlowOpacity,
    required this.locationImageFlowDurationSeconds,
    required this.locationImageFlowBlendMode,
    this.nearbyLocationDistanceTiles =
        tilemapDefaultNearbyLocationDistanceTiles,
    this.distantLocationDistanceTiles =
        tilemapDefaultDistantLocationDistanceTiles,
    this.nearbyLocationInitialScale = tilemapDefaultNearbyLocationInitialScale,
    this.distantLocationInitialScale =
        tilemapDefaultDistantLocationInitialScale,
    required this.dragBoundaryPaddingTiles,
  });

  factory TilemapRenderSettings.defaults() {
    return const TilemapRenderSettings(
      visualMode: tilemapDefaultVisualMode,
      loadingStyle: tilemapDefaultLoadingStyle,
      fogControlPoints: tilemapDefaultFogControlPoints,
      blendFogWithShadowTiles: tilemapDefaultBlendFogWithShadowTiles,
      cacheFogTileBitmaps: tilemapDefaultCacheFogTileBitmaps,
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
      nearbyLocationDistanceTiles: tilemapDefaultNearbyLocationDistanceTiles,
      distantLocationDistanceTiles: tilemapDefaultDistantLocationDistanceTiles,
      nearbyLocationInitialScale: tilemapDefaultNearbyLocationInitialScale,
      distantLocationInitialScale: tilemapDefaultDistantLocationInitialScale,
      dragBoundaryPaddingTiles: tilemapDefaultDragBoundaryPaddingTiles,
    );
  }

  factory TilemapRenderSettings.fromJson(Map<String, dynamic> json) {
    final defaults = TilemapRenderSettings.defaults();
    final visualMode = switch (json['visual_mode']) {
      'light' => TilemapVisualMode.light,
      'dark' => TilemapVisualMode.dark,
      _ => defaults.visualMode,
    };
    var nearbyLocationDistanceTiles =
        _readDouble(
          json['nearby_location_distance_tiles'],
          min: tilemapLocationDistanceThresholdMin,
          max:
              tilemapLocationDistanceThresholdMax -
              tilemapLocationDistanceThresholdStep,
        ) ??
        defaults.nearbyLocationDistanceTiles;
    var distantLocationDistanceTiles =
        _readDouble(
          json['distant_location_distance_tiles'],
          min:
              tilemapLocationDistanceThresholdMin +
              tilemapLocationDistanceThresholdStep,
          max: tilemapLocationDistanceThresholdMax,
        ) ??
        defaults.distantLocationDistanceTiles;
    if (distantLocationDistanceTiles - nearbyLocationDistanceTiles <
        tilemapLocationDistanceThresholdStep) {
      nearbyLocationDistanceTiles = defaults.nearbyLocationDistanceTiles;
      distantLocationDistanceTiles = defaults.distantLocationDistanceTiles;
    }
    var nearbyLocationInitialScale =
        _readDouble(
          json['nearby_location_initial_scale'],
          min: tilemapNearbyLocationInitialScaleMin,
          max: tilemapNearbyLocationInitialScaleMax,
        ) ??
        defaults.nearbyLocationInitialScale;
    var distantLocationInitialScale =
        _readDouble(
          json['distant_location_initial_scale'],
          min: tilemapDistantLocationInitialScaleMin,
          max: tilemapDistantLocationInitialScaleMax,
        ) ??
        defaults.distantLocationInitialScale;
    if (nearbyLocationInitialScale < distantLocationInitialScale) {
      nearbyLocationInitialScale = defaults.nearbyLocationInitialScale;
      distantLocationInitialScale = defaults.distantLocationInitialScale;
    }
    return TilemapRenderSettings(
      visualMode: visualMode,
      loadingStyle:
          _readLoadingStyle(json['loading_style']) ?? defaults.loadingStyle,
      fogControlPoints:
          _readFogControlPoints(json['fog_control_points']) ??
          defaults.fogControlPoints,
      blendFogWithShadowTiles: json['blend_fog_with_shadow_tiles'] is bool
          ? json['blend_fog_with_shadow_tiles'] as bool
          : defaults.blendFogWithShadowTiles,
      cacheFogTileBitmaps: json['cache_fog_tile_bitmaps'] is bool
          ? json['cache_fog_tile_bitmaps'] as bool
          : defaults.cacheFogTileBitmaps,
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
      nearbyLocationDistanceTiles: nearbyLocationDistanceTiles,
      distantLocationDistanceTiles: distantLocationDistanceTiles,
      nearbyLocationInitialScale: nearbyLocationInitialScale,
      distantLocationInitialScale: distantLocationInitialScale,
      dragBoundaryPaddingTiles:
          _readDouble(
            json['drag_boundary_padding_tiles'],
            min: tilemapDragBoundaryPaddingTilesMin,
            max: tilemapDragBoundaryPaddingTilesMax,
          ) ??
          defaults.dragBoundaryPaddingTiles,
    );
  }

  final TilemapVisualMode visualMode;
  final TilemapLoadingStyle loadingStyle;
  final List<TilemapFogControlPoint> fogControlPoints;
  final bool blendFogWithShadowTiles;
  final bool cacheFogTileBitmaps;
  final bool showShadowZeroBorders;
  final bool showLocationImageFlow;
  final double locationImageFlowAngleDegrees;
  final List<TilemapLocationImageFlowGradientPoint>
  locationImageFlowGradientPoints;
  final double locationImageFlowOpacity;
  final double locationImageFlowDurationSeconds;
  final TilemapLocationImageFlowBlendMode locationImageFlowBlendMode;
  final double nearbyLocationDistanceTiles;
  final double distantLocationDistanceTiles;
  final double nearbyLocationInitialScale;
  final double distantLocationInitialScale;
  final double dragBoundaryPaddingTiles;

  TilemapRenderSettings copyWith({
    TilemapVisualMode? visualMode,
    TilemapLoadingStyle? loadingStyle,
    List<TilemapFogControlPoint>? fogControlPoints,
    bool? blendFogWithShadowTiles,
    bool? cacheFogTileBitmaps,
    bool? showShadowZeroBorders,
    bool? showLocationImageFlow,
    double? locationImageFlowAngleDegrees,
    List<TilemapLocationImageFlowGradientPoint>?
    locationImageFlowGradientPoints,
    double? locationImageFlowOpacity,
    double? locationImageFlowDurationSeconds,
    TilemapLocationImageFlowBlendMode? locationImageFlowBlendMode,
    double? nearbyLocationDistanceTiles,
    double? distantLocationDistanceTiles,
    double? nearbyLocationInitialScale,
    double? distantLocationInitialScale,
    double? dragBoundaryPaddingTiles,
  }) {
    return TilemapRenderSettings(
      visualMode: visualMode ?? this.visualMode,
      loadingStyle: loadingStyle ?? this.loadingStyle,
      fogControlPoints: fogControlPoints ?? this.fogControlPoints,
      blendFogWithShadowTiles:
          blendFogWithShadowTiles ?? this.blendFogWithShadowTiles,
      cacheFogTileBitmaps: cacheFogTileBitmaps ?? this.cacheFogTileBitmaps,
      showShadowZeroBorders:
          showShadowZeroBorders ?? this.showShadowZeroBorders,
      showLocationImageFlow:
          showLocationImageFlow ?? this.showLocationImageFlow,
      locationImageFlowAngleDegrees:
          locationImageFlowAngleDegrees ?? this.locationImageFlowAngleDegrees,
      locationImageFlowGradientPoints:
          locationImageFlowGradientPoints ??
          this.locationImageFlowGradientPoints,
      locationImageFlowOpacity:
          locationImageFlowOpacity ?? this.locationImageFlowOpacity,
      locationImageFlowDurationSeconds:
          locationImageFlowDurationSeconds ??
          this.locationImageFlowDurationSeconds,
      locationImageFlowBlendMode:
          locationImageFlowBlendMode ?? this.locationImageFlowBlendMode,
      nearbyLocationDistanceTiles:
          nearbyLocationDistanceTiles ?? this.nearbyLocationDistanceTiles,
      distantLocationDistanceTiles:
          distantLocationDistanceTiles ?? this.distantLocationDistanceTiles,
      nearbyLocationInitialScale:
          nearbyLocationInitialScale ?? this.nearbyLocationInitialScale,
      distantLocationInitialScale:
          distantLocationInitialScale ?? this.distantLocationInitialScale,
      dragBoundaryPaddingTiles:
          dragBoundaryPaddingTiles ?? this.dragBoundaryPaddingTiles,
    );
  }

  TilemapRenderSettings resolveForRuntime({required bool releaseMode}) {
    if (!releaseMode) return this;
    return copyWith(loadingStyle: TilemapLoadingStyle.disabled);
  }

  String toSerializedJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  Map<String, dynamic> toJson() {
    return {
      'schema_version': 3,
      'visual_mode': visualMode.name,
      'loading_style': loadingStyle.name,
      'fog_control_points': [
        for (final point in fogControlPoints)
          {'position': point.position, 'opacity': point.opacity},
      ],
      'blend_fog_with_shadow_tiles': blendFogWithShadowTiles,
      'cache_fog_tile_bitmaps': cacheFogTileBitmaps,
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
      'nearby_location_distance_tiles': nearbyLocationDistanceTiles,
      'distant_location_distance_tiles': distantLocationDistanceTiles,
      'nearby_location_initial_scale': nearbyLocationInitialScale,
      'distant_location_initial_scale': distantLocationInitialScale,
      'drag_boundary_padding_tiles': dragBoundaryPaddingTiles,
    };
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

  static TilemapLoadingStyle? _readLoadingStyle(Object? value) {
    if (value is! String) return null;
    for (final style in TilemapLoadingStyle.values) {
      if (style.name == value) return style;
    }
    return null;
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
    var settings = TilemapRenderSettings.defaults();
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          settings = TilemapRenderSettings.fromJson(decoded);
        } else if (decoded is Map) {
          settings = TilemapRenderSettings.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        settings = TilemapRenderSettings.defaults();
      }
    }
    tilemapVisualModeController.setVisualMode(settings.visualMode);
    return settings;
  }

  Future<void> save(TilemapRenderSettings settings) async {
    tilemapVisualModeController.setVisualMode(settings.visualMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(settings.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    tilemapVisualModeController.setVisualMode(tilemapDefaultVisualMode);
  }
}
