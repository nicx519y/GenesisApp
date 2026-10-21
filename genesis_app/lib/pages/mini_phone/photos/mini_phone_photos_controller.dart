import 'package:flutter/foundation.dart';
import '../../../network/mini_phone/mini_phone_api.dart';
import '../state/mini_phone_requests.dart';

class MiniPhonePhotosController {
  MiniPhonePhotosController({
    required this.api,
    required this.worldId,
    required this.requests,
  });
  final MiniPhoneApi api;
  final String worldId;
  final MiniPhoneRequests requests;
  static const pageSize = 100;
  final _cachedPages = <int, List<PhoneAlbumAsset>>{};
  List<PhoneAlbumAsset> album = [];
  List<PhoneAlbumAsset>? _confirmedAlbum;

  /// Only this prefix has been checked since the most recent first-page read.
  /// Later cached pages stay visible while paging revalidates them on demand.
  List<PhoneAlbumAsset> get confirmedAlbum => _confirmedAlbum ?? album;

  void reset() {
    album = [];
    _confirmedAlbum = null;
    _cachedPages.clear();
  }

  Future<bool> refresh({bool next = false}) {
    final pn = next ? (requests.pages['album'] ?? 1) + 1 : 1;
    return requests.load(
      'album',
      () => api.album(worldId, pn: pn, rn: pageSize),
      (page) {
        final previous = {for (final asset in album) asset.id: asset};
        _cachedPages[pn] = [
          for (final asset in page.list)
            if (previous[asset.id] case final old? when _sameAsset(old, asset))
              old
            else
              asset,
        ];
        if (!page.hasMore) _cachedPages.removeWhere((key, _) => key > pn);
        final keys = _cachedPages.keys.toList()..sort();
        List<PhoneAlbumAsset> merge(Iterable<int> pages) {
          final byId = <int, PhoneAlbumAsset>{};
          for (final key in pages) {
            for (final asset in _cachedPages[key]!) {
              // The earlier, freshly checked page owns cross-page duplicates.
              byId.putIfAbsent(asset.id, () => asset);
            }
          }
          return byId.values.toList();
        }

        final updated = merge(keys);
        if (!listEquals(album, updated)) album = updated;
        final confirmed = merge(keys.where((key) => key <= pn));
        if (!listEquals(_confirmedAlbum, confirmed)) {
          _confirmedAlbum = confirmed;
        }
        requests.pages['album'] = pn;
        requests.hasMore['album'] = page.hasMore;
      },
      requestKey: '$pn',
    );
  }

  bool _sameAsset(PhoneAlbumAsset a, PhoneAlbumAsset b) =>
      a.id == b.id &&
      a.worldId == b.worldId &&
      a.image == b.image &&
      a.thumbnail == b.thumbnail &&
      a.description == b.description &&
      a.createdAt == b.createdAt;
}
