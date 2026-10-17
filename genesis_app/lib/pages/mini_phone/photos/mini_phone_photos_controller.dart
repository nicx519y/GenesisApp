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
  List<PhoneAlbumAsset> album = [];
  void reset() => album = [];
  Future<bool> refresh({bool next = false}) {
    final pn = next ? (requests.pages['album'] ?? 1) + 1 : 1;
    return requests.load('album', () => api.album(worldId, pn: pn), (page) {
      album = <int, PhoneAlbumAsset>{
        if (next)
          for (final a in album) a.id: a,
        for (final a in page.list) a.id: a,
      }.values.toList();
      requests.pages['album'] = pn;
      requests.hasMore['album'] = page.hasMore;
    }, requestKey: '$pn');
  }
}
