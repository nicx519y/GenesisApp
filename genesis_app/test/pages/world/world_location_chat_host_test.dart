import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/world/world_location_chat_host.dart';

void main() {
  test('markReady reports true only for the first ready notification', () {
    final cache = WorldLocationChatPageCache();
    cache.syncDescriptors(const {
      'loc_1': WorldLocationChatPanelDescriptor(
        locationId: 'loc_1',
        locationName: 'Location',
        backgroundImageUrl: '',
        backgroundPreviewImageUrl: '',
        isLeafLocation: true,
      ),
    });

    expect(cache.isReady('loc_1'), isFalse);
    expect(cache.markReady('loc_1'), isTrue);
    expect(cache.isReady('loc_1'), isTrue);
    expect(cache.markReady('loc_1'), isFalse);
  });
}
