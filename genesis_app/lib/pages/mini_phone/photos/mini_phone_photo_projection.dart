import 'package:flutter/foundation.dart';
import '../../../network/mini_phone/mini_phone_models.dart';
import '../../../utils/genesis_image_resource.dart';

/// Cached display projection. The server album remains untouched.
class MiniPhonePhotoProjection {
  List<PhoneAlbumAsset>? _album;
  Set<String> _coverKeys = {};
  List<PhoneAlbumAsset> _visible = const [];

  List<PhoneAlbumAsset> resolve(
    List<PhoneAlbumAsset> album,
    Set<String> coverKeys,
  ) {
    if (identical(album, _album) && setEquals(coverKeys, _coverKeys)) {
      return _visible;
    }
    _album = album;
    _coverKeys = Set.of(coverKeys);
    final seen = <String>{};
    final visible = List<PhoneAlbumAsset>.unmodifiable(
      album.where((asset) {
        final image = asset.image.trim();
        final resource = image.isEmpty ? asset.thumbnail.trim() : image;
        final parsed = GenesisImageResourceRegistry.resolve(resource);
        final resolved = parsed.displayUrl;
        if (parsed.keys.any(coverKeys.contains) ||
            resolved.isEmpty ||
            resolved.startsWith('assets/images/map_default/') ||
            localDefaultMapImageAssetForBackendImageUrl(resolved) != null) {
          return false;
        }
        return seen.add(resource);
      }),
    );
    if (!listEquals(_visible, visible)) _visible = visible;
    return _visible;
  }
}
