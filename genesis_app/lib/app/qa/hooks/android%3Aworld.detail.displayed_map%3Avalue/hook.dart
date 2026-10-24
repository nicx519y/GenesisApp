import '../android%253Aworld.retry.preparation%253Avalue/lease.dart';
import '../android%253Aworld.retry.preparation%253Avalue/view.dart';
import 'package:flutter/material.dart';
import '../../../../components/world_map.dart';
import '../../../../ui/components/genesis_static_network_image.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validateRead(p, started);
  final lease = requireWorldLease();
  await lease.sameOwner();
  final world = worldElement();
  final maps = world == null
      ? <Element>[]
      : elements(
          world,
        ).where((e) => e.widget is WorldMap && visible(e)).toList();
  final matching = maps
      .where((e) => (e.widget as WorldMap).legacy.mapImageUrl == lease.mapUrl)
      .toList();
  bool loaded = false;
  for (final map in matching) {
    for (final e in elements(map)) {
      final w = e.widget;
      // Require the actual requested image provider, not a marker or fallback.
      if (w is GenesisStaticNetworkImage &&
          sameMapImageUrl(w.imageUrl, lease.mapUrl)) {
        loaded =
            loaded ||
            elements(e).any(
              (r) =>
                  r.widget is RawImage &&
                  (r.widget as RawImage).image != null &&
                  visible(r),
            );
      }
    }
  }
  return {
    'visible': maps.isNotEmpty,
    'loaded': loaded,
    'worldIdMatchesPreparedWorld': world != null,
    'mapMatchesPreparedWorld': matching.isNotEmpty,
  };
}

/// Image resizing adds a query; compare both URI values in the same form.
/// Retain all non-resize query parameters so another resource cannot match.
bool sameMapImageUrl(String actual, String expected) {
  Uri canonical(String value) {
    final uri = Uri.parse(value);
    final parameters = Map<String, dynamic>.from(uri.queryParametersAll)
      ..remove('x-oss-process');
    return uri.replace(queryParameters: parameters);
  }

  return actual.isNotEmpty &&
      expected.isNotEmpty &&
      canonical(actual) == canonical(expected);
}
