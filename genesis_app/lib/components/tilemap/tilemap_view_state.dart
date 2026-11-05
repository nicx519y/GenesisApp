import 'package:flutter/material.dart' show Matrix4;

/// The map hierarchy and viewports, independent of a mounted renderer.
class TilemapViewState {
  TilemapViewState({
    required this.initialLocationId,
    required this.currentLocationId,
    required List<String> locationTrail,
    required Map<String, Matrix4> viewportTransforms,
  }) : locationTrail = List.unmodifiable(locationTrail),
       viewportTransforms = Map.unmodifiable({
         for (final entry in viewportTransforms.entries)
           entry.key: entry.value.clone(),
       });

  final String initialLocationId;
  final String currentLocationId;
  final List<String> locationTrail;
  final Map<String, Matrix4> viewportTransforms;

  Map<String, Object> toJson() => {
    'version': 1,
    'initial_location_id': initialLocationId,
    'current_location_id': currentLocationId,
    'location_trail': locationTrail,
    'viewport_transforms': {
      for (final entry in viewportTransforms.entries)
        entry.key: entry.value.storage.toList(),
    },
  };

  static TilemapViewState? fromJson(Object? json) {
    if (json is! Map || json['version'] != 1) return null;
    final initial = json['initial_location_id'];
    final current = json['current_location_id'];
    final trail = json['location_trail'];
    if (initial is! String ||
        initial.trim().isEmpty ||
        current is! String ||
        current.trim().isEmpty ||
        trail is! List ||
        trail.any((id) => id is! String || id.trim().isEmpty)) {
      return null;
    }
    final transforms = <String, Matrix4>{};
    final rawTransforms = json['viewport_transforms'];
    if (rawTransforms is Map) {
      for (final entry in rawTransforms.entries) {
        final values = entry.value;
        if (entry.key is! String ||
            values is! List ||
            values.length != 16 ||
            values.any((value) => value is! num || !value.isFinite)) {
          continue;
        }
        final matrix = Matrix4.fromList(
          values.cast<num>().map((value) => value.toDouble()).toList(),
        );
        if (matrix.determinant() == 0 || matrix.getMaxScaleOnAxis() <= 0) {
          continue;
        }
        transforms[entry.key as String] = matrix;
      }
    }
    return TilemapViewState(
      initialLocationId: initial.trim(),
      currentLocationId: current.trim(),
      locationTrail: trail.cast<String>().map((id) => id.trim()).toList(),
      viewportTransforms: transforms,
    );
  }
}
