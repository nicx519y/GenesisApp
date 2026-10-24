import 'package:flutter/widgets.dart';
import 'dart:ui' as ui;
import '../../../../components/tilemap/tilemap_renderer.dart';
import '../../../../components/world_map.dart';
import '../../../../ui/components/genesis_static_network_image.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';
import '../android%253Aworld.detail.displayed_map%253Avalue/hook.dart'
    show sameMapImageUrl;

bool canvasImagesReady(Iterable<dynamic> items) {
  var painted = false, complete = true;
  for (final dynamic item in items) {
    try {
      final Object? image = item.image;
      final ready = image is ui.Image && image.width > 0 && image.height > 0;
      painted = painted || ready;
      complete = complete && ready;
    } on NoSuchMethodError {
      // Effect tiles render their decoded image through a child RawImage,
      // rather than an atlas draw run. A fully loaded effect-only map counts.
      final ready = item.hasImage == true;
      painted = painted || ready;
      complete = complete && ready;
    }
  }
  return painted && complete;
}

bool observe(Element? world, String id) {
  if (world == null) return false;
  for (final map in elements(
    world,
  ).where((e) => e.widget is WorldMap && visible(e))) {
    final widget = map.widget as WorldMap;
    if (widget.definitionVersion == 2) {
      for (final renderer in elements(map).where(
        (e) =>
            e.widget is TilemapRenderer &&
            (e.widget as TilemapRenderer).isForeground &&
            visible(e),
      )) {
        for (final canvas in elements(renderer)) {
          if (canvas.widget.key ==
                  const ValueKey<String>('tilemap-canvas-tile-layer') &&
              visible(canvas)) {
            // The mounted canvas exposes public draw items; inspect decoded image
            // resources already submitted to the renderer, never preload them here.
            final dynamic composite = canvas.widget;
            final Iterable<dynamic> items =
                composite.items as Iterable<dynamic>;
            if (canvasImagesReady(items)) return true;
          }
        }
      }
      continue;
    }
    for (final image in elements(map)) {
      final w = image.widget;
      if (w is GenesisStaticNetworkImage &&
          sameMapImageUrl(w.imageUrl, widget.legacy.mapImageUrl) &&
          elements(image).any(
            (e) =>
                e.widget is RawImage &&
                (e.widget as RawImage).image != null &&
                visible(e),
          ))
        return true;
    }
  }
  return false;
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'wait');
  final d = await selection();
  return observe(selectedWorld(d.selectedId!), d.selectedId!);
}
