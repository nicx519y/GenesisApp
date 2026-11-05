import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_tasks.dart';
import 'package:genesis_flutter_android/pages/mini_phone/session/mini_phone_session.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';
import '../../support/mini_phone_chat_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PhoneBackend backend;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = PhoneBackend();
  });
  tearDown(() => backend.revision.dispose());

  MiniPhoneCameraTasks tasks({
    String namespace = 'test',
    String uid = 'u',
    String worldId = 'w',
    MiniPhoneRequests? requests,
  }) {
    final value = MiniPhoneCameraTasks(
      api: backend.api,
      namespace: namespace,
      worldId: worldId,
      requests: requests ?? (MiniPhoneRequests(() {})..uid = uid),
      pending: {},
      saveJournal: () async => true,
      onChanged: () {},
      onSuccess: () {},
    );
    addTearDown(value.dispose);
    return value;
  }

  test('first options persist the default style and ratio', () async {
    final first = tasks();
    await first.loadOptions();
    await first.selections.saved;
    // A later server order must not replace the first selected style.
    backend.respond = (request) => ok({
      'world_id': 'w',
      'price_cent': 4000,
      'free_status': 'used',
      'styles': [
        {'name': 'Mirror', 'label': 'mirror_selfie', 'demo_image_url': ''},
        {'name': 'Selfie renamed', 'label': 'selfie', 'demo_image_url': ''},
      ],
    });
    final reopened = tasks();
    await reopened.loadOptions();
    expect(reopened.selectedStyle, 'selfie');
    expect(reopened.style!.name, 'Selfie renamed');
    expect(reopened.selections.photoRatio, CameraPhotoRatio.portrait);
    await reopened.selections.saved;
  });

  test(
    'World session restores manual selections into the camera draft',
    () async {
      final first = MiniPhoneSession(worldId: 'w', data: backend.store());
      await first.data!.ready;
      await first.data!.cameraTasks.loadOptions();
      first.data!.cameraTasks.selectStyle('mirror_selfie');
      first.camera!.setPhotoRatio(CameraPhotoRatio.wide);
      await first.data!.cameraTasks.selections.saved;
      first.dispose();

      final reopened = MiniPhoneSession(worldId: 'w', data: backend.store());
      addTearDown(reopened.dispose);
      await reopened.data!.ready;
      // Construct the controller before restoration, as when entering a cold camera.
      final camera = reopened.camera!;
      var updates = 0;
      camera.addListener(() => updates++);
      await reopened.data!.cameraTasks.loadOptions();
      expect(reopened.data!.cameraTasks.selectedStyle, 'mirror_selfie');
      expect(camera.photoRatio, CameraPhotoRatio.wide);
      expect(updates, greaterThan(0));
      camera.setPeople(const [PhonePerson('c', 'Character', '')]);
      camera.togglePerson(const PhonePerson('c', 'Character', ''));
      await camera.generate((request, _) async {
        expect(request.photoRatio.label, '16:9');
        return MiniPhoneCameraResult(imageUrl: 'https://example.com/photo.png');
      });
      await reopened.data!.cameraTasks.selections.saved;
    },
  );

  test(
    'rapid selections persist the latest values without another options read',
    () async {
      final first = tasks();
      await first.loadOptions();
      for (final ratio in CameraPhotoRatio.values) {
        first.selections.selectRatio(ratio);
        first.selectStyle('mirror_selfie');
        first.selectStyle('selfie');
      }
      final reopened = tasks();
      await reopened.selections.restore();
      expect(reopened.selectedStyle, 'selfie');
      expect(reopened.selections.photoRatio, CameraPhotoRatio.wide);
      expect(backend.calls('photo/options'), hasLength(1));
      await first.selections.saved;
    },
  );

  test(
    'options refresh preserves edits made while the request is pending',
    () async {
      final first = tasks();
      await first.loadOptions();
      first.selections.selectRatio(CameraPhotoRatio.tall);
      await first.selections.saved;
      final response = Completer<Object?>();
      backend.respond = (_) => response.future;
      final refresh = first.loadOptions();
      first.selectStyle('mirror_selfie');
      first.selections.selectRatio(CameraPhotoRatio.square);
      response.complete(null);
      await refresh;
      expect(first.selectedStyle, 'mirror_selfie');
      expect(first.selections.photoRatio, CameraPhotoRatio.square);
      await first.selections.saved;
    },
  );

  test(
    'an edit during local restoration wins without losing the saved style',
    () async {
      final first = tasks();
      await first.loadOptions();
      first.selectStyle('mirror_selfie');
      first.selections.selectRatio(CameraPhotoRatio.tall);
      await first.selections.saved;
      final reopened = tasks();
      final loading = reopened.loadOptions();
      reopened.selections.selectRatio(CameraPhotoRatio.square);
      await loading;
      expect(reopened.selectedStyle, 'mirror_selfie');
      expect(reopened.selections.photoRatio, CameraPhotoRatio.square);
      await reopened.selections.saved;
    },
  );

  test(
    'removed styles fall back and persist while retaining the ratio',
    () async {
      final first = tasks();
      await first.loadOptions();
      first.selectStyle('mirror_selfie');
      first.selections.selectRatio(CameraPhotoRatio.landscape);
      await first.selections.saved;
      backend.respond = (_) => ok({
        'world_id': 'w',
        'price_cent': 3000,
        'free_status': 'available',
        'styles': [
          {'name': 'New style', 'label': 'new_style', 'demo_image_url': ''},
        ],
      });
      final reopened = tasks();
      await reopened.loadOptions();
      expect(reopened.selectedStyle, 'new_style');
      expect(reopened.selections.photoRatio, CameraPhotoRatio.landscape);
      await reopened.selections.saved;
      final again = tasks();
      await again.selections.restore();
      expect(again.selectedStyle, 'new_style');
      expect(again.selections.photoRatio, CameraPhotoRatio.landscape);
    },
  );

  test('choices are global across environments, accounts and Worlds', () async {
    final first = tasks();
    await first.loadOptions();
    first.selectStyle('mirror_selfie');
    first.selections.selectRatio(CameraPhotoRatio.tall);
    await first.selections.saved;
    for (final other in [
      tasks(namespace: 'other'),
      tasks(uid: 'other'),
      tasks(worldId: 'other'),
    ]) {
      await other.loadOptions();
      expect(other.selectedStyle, 'mirror_selfie');
      expect(other.selections.photoRatio, CameraPhotoRatio.tall);
      await other.selections.saved;
    }
    final restored = tasks();
    await restored.loadOptions();
    expect(restored.selectedStyle, 'mirror_selfie');
    expect(restored.selections.photoRatio, CameraPhotoRatio.tall);
    await restored.selections.saved;
  });

  test(
    'returning to an existing World restores the latest global choices',
    () async {
      final first = tasks();
      final other = tasks(worldId: 'other');
      await first.loadOptions();
      await other.loadOptions();
      other.selectStyle('mirror_selfie');
      other.selections.selectRatio(CameraPhotoRatio.square);

      await first.restoreSelections();
      expect(first.selectedStyle, 'mirror_selfie');
      expect(first.selections.photoRatio, CameraPhotoRatio.square);
      expect(backend.calls('photo/options'), hasLength(2));
      await first.selections.saved;
      await other.selections.saved;
    },
  );

  test('late options preserve global edits from another World', () async {
    final first = tasks();
    final other = tasks(worldId: 'other');
    await first.loadOptions();
    await other.loadOptions();
    final response = Completer<Object?>();
    backend.respond = (_) => response.future;
    final refresh = first.loadOptions();
    await first.selections.restore();
    other.selectStyle('mirror_selfie');
    other.selections.selectRatio(CameraPhotoRatio.wide);
    await other.selections.saved;
    response.complete(null);
    await refresh;
    expect(first.selectedStyle, 'mirror_selfie');
    expect(first.selections.photoRatio, CameraPhotoRatio.wide);
    await first.selections.saved;
  });

  test(
    'late options and preference restores cannot cross an account reset',
    () async {
      final gate = MiniPhoneRequests(() {})..uid = 'u';
      final first = tasks(requests: gate);
      await first.loadOptions();
      first.selectStyle('mirror_selfie');
      first.selections.selectRatio(CameraPhotoRatio.wide);
      await first.selections.saved;
      final response = Completer<Object?>();
      backend.respond = (_) => response.future;
      final oldRefresh = first.loadOptions();
      gate.reset();
      gate.uid = 'other';
      first.reset();
      backend.respond = null;
      await first.loadOptions();
      first.selectStyle('selfie');
      first.selections.selectRatio(CameraPhotoRatio.square);
      response.complete(null);
      await oldRefresh;
      expect(first.selectedStyle, 'selfie');
      expect(first.selections.photoRatio, CameraPhotoRatio.square);
      await first.selections.saved;
      final original = tasks();
      await original.loadOptions();
      expect(original.selectedStyle, 'selfie');
      expect(original.selections.photoRatio, CameraPhotoRatio.square);
      await original.selections.saved;
    },
  );
}
