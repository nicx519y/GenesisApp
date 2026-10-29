import '../../../network/models/world.dart';
import '../../../network/genesis_api.dart' show resolveAssetUrl;
import '../../../utils/genesis_image_resource.dart';

/// A local composition choice, never a request to move the player or a character.
class MiniPhoneCameraScene {
  const MiniPhoneCameraScene({
    required this.id,
    required this.name,
    this.image = '',
  });
  final String id, name, image;

  static List<MiniPhoneCameraScene> fromWorld(WorldDetail? world) {
    if (world == null) return const [];
    return [
      for (final node in world.processedLocationTree.flattened)
        if (node.children.isEmpty && node.value['synthetic_root'] != true)
          MiniPhoneCameraScene(
            id: node.id,
            name: '${node.value['location_name'] ?? node.value['name'] ?? ''}',
            image: _image(node.value['image']),
          ),
    ];
  }

  static String _image(Object? value) {
    final url = resolveAssetUrl(
      GenesisImageResource.fromJson(value).displayUrl,
    );
    if (url.startsWith('assets/images/map_default/') ||
        localDefaultMapImageAssetForBackendImageUrl(url) != null) {
      return '';
    }
    return url;
  }
}
