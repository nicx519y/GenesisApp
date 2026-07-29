part of 'tilemap_renderer_library.dart';

class _ProjectedTile extends StatelessWidget {
  const _ProjectedTile({
    super.key,
    required this.tile,
    required this.asset,
    required this.topLeft,
    required this.extent,
    this.locationImageFlowAnimation,
    this.locationImageFlowPhase = 0,
    this.locationImageFlowAngleDegrees =
        tilemapDefaultLocationImageFlowAngleDegrees,
    this.locationImageFlowGradientPoints =
        tilemapDefaultLocationImageFlowGradientPoints,
    this.locationImageFlowOpacity = tilemapDefaultLocationImageFlowOpacity,
    this.locationImageFlowBlendMode = tilemapDefaultLocationImageFlowBlendMode,
    this.fogField,
    this.onImageError,
  });

  final TilemapCell tile;
  final String asset;
  final Offset topLeft;
  final double extent;
  final Animation<double>? locationImageFlowAnimation;
  final double locationImageFlowPhase;
  final double locationImageFlowAngleDegrees;
  final List<TilemapLocationImageFlowGradientPoint>
  locationImageFlowGradientPoints;
  final double locationImageFlowOpacity;
  final TilemapLocationImageFlowBlendMode locationImageFlowBlendMode;
  final TilemapFogField? fogField;
  final ValueChanged<Object>? onImageError;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      asset,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
      semanticLabel: '${tile.type} ${tile.x},${tile.y}',
      errorBuilder: (context, error, stackTrace) {
        onImageError?.call(error);
        return const SizedBox.shrink();
      },
    );
    final field = fogField;
    final fogVertices = field?.shadowTileVertices[tile.cellKey];
    final animation = locationImageFlowAnimation;
    final imageWithFlow = animation == null
        ? image
        : _TilemapImageFlow(
            key: ValueKey<String>(
              'tile-location-image-flow-${tile.x}-${tile.y}',
            ),
            animation: animation,
            phase: locationImageFlowPhase,
            isolateRepaint: fogVertices == null,
            angleDegrees: locationImageFlowAngleDegrees,
            gradientPoints: locationImageFlowGradientPoints,
            opacity: locationImageFlowOpacity,
            blendMode: locationImageFlowBlendMode,
            child: image,
          );
    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      width: extent,
      height: extent,
      child: field == null || fogVertices == null
          ? imageWithFlow
          : _TilemapFogBlend(
              key: ValueKey<String>('tile-fog-blend-${tile.x}-${tile.y}'),
              vertices: fogVertices,
              sceneTopLeft: topLeft,
              child: imageWithFlow,
            ),
    );
  }
}
