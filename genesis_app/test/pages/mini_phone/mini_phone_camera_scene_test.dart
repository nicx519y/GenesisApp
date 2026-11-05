import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/models/world.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_scene.dart';

void main() {
  test(
    'camera projects only real leaf locations without covers or map placeholders',
    () {
      final world = WorldDetail.fromJson({
        'world_id': 'w',
        'cover': 'https://example.test/cover.jpg',
        'locations': [
          {'location_id': 'parent', 'location_name': 'City'},
          {
            'location_id': 'hall',
            'location_pid': 'parent',
            'location_name': 'Hall',
            'image': {'xl_url': 'https://example.test/hall.jpg'},
          },
          {
            'location_id': 'garden',
            'location_pid': 'parent',
            'location_name': 'Garden',
          },
          {
            'location_id': 'empty',
            'location_name': 'Empty',
            'image': 'assets/images/map_default/default.jpg',
          },
        ],
      });
      final scenes = MiniPhoneCameraScene.fromWorld(world);
      expect(scenes.map((s) => s.id), ['hall', 'garden', 'empty']);
      expect(scenes.map((s) => s.image), [
        'https://example.test/hall.jpg',
        '',
        '',
      ]);
      expect(world.locations.length, 4);
      expect(MiniPhoneCameraScene.fromWorld(null), isEmpty);
    },
  );
}
