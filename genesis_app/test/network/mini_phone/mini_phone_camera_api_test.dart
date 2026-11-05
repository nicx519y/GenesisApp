import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_api.dart';
import 'package:genesis_flutter_android/network/chatroom/chatroom_models.dart';
import '../../support/mini_phone_chat_backend.dart';

void main() {
  test(
    'options uses cent, dynamic labels and World; no ratio or last draft required',
    () async {
      final b = PhoneBackend();
      b.respond = (_) => ok({
        'world_id': 'w',
        'price_cent': 3001,
        'free_status': 'available',
        'styles': [
          {'name': 'Mirror', 'label': 'mirror_selfie', 'demo_image_url': ''},
        ],
      });
      final options = await b.api.cameraOptions('w');
      expect(options.priceCent, 3001);
      expect(options.freeAvailable, true);
      expect(options.styles.single.label, 'mirror_selfie');
      expect(b.requests.single.uri.queryParameters, {'world_id': 'w'});
      expect(
        b.requests.single.uri.path,
        '/aitown-chat/api/v1/phone/photo/options',
      );
    },
  );

  test(
    'create has only camera fields; blank prompt omitted and int64 preserved',
    () async {
      final b = PhoneBackend();
      final result = {
        'task_id': 'task',
        'client_request_id': 'r',
        'status': 'succeeded',
        'failure': null,
        'image': {
          'asset_id': '9007199254740993',
          'image_url': 'https://cdn.example/photo.png',
          'description': 'Scene',
        },
      };
      b.respond = (_) =>
          ok({'source': 'camera', 'world_id': 'w', 'photo': result});
      final receipt = await b.api.createCameraPhoto(
        PhoneCameraRequest(
          requestId: 'r',
          worldId: 'w',
          characterIds: ['c'],
          aspectRatio: '2:3',
          style: 'mirror_selfie',
        ),
      );
      expect(b.body(b.requests.single), {
        'client_request_id': 'r',
        'world_id': 'w',
        'character_ids': ['c'],
        'aspect_ratio': '2:3',
        'style': 'mirror_selfie',
      });
      expect(receipt.photo.assetId, 9007199254740993);
      expect(receipt.photo.globalMessageId, isNull);
      expect(() => PhotoTask.fromJson(result), throwsFormatException);
      final envelope = ChatroomV2Message.fromJson({
        'type': 'phone.photo.result',
        'world_id': 'w',
        'err_no': 0,
        'payload': {
          'source': 'camera',
          'event_id': 'event',
          'title': 'Done',
          'summary': 'Photo ready',
          'photo': result,
        },
      });
      final event = chatroomEventFromV2Message(envelope) as ChatroomPhotoResult;
      expect(event.photo!.assetId, 9007199254740993);
      expect(event.source, 'camera');
      expect(
        PhotoTask.fromJson(receipt.photo.toJson(), requireChatMessageId: false),
        receipt.photo,
      );
    },
  );

  test(
    'validation rejects floats, duplicate roles and more than four roles',
    () {
      for (final ids in [
        <String>[],
        ['a', 'a'],
        ['a', 'b', 'c', 'd', 'e'],
      ]) {
        expect(
          () => PhoneCameraRequest(
            requestId: 'r',
            worldId: 'w',
            characterIds: ids,
            aspectRatio: '2:3',
            style: 'selfie',
          ),
          throwsArgumentError,
        );
      }
      for (final ratio in ['0:3', '2.0:3', '2:-3', '2/3', '1:0']) {
        expect(
          () => PhoneCameraRequest(
            requestId: 'r',
            worldId: 'w',
            characterIds: ['a'],
            aspectRatio: ratio,
            style: 'selfie',
          ),
          throwsArgumentError,
        );
      }
      expect(() => photoTaskId(9007199254740992.0), throwsFormatException);
      expect(
        PhoneCameraTarget.tryParse(
          {'source': 'camera', 'asset_id': '9007199254740993'},
          worldId: 'w',
          taskId: 'task',
        )!.assetId,
        9007199254740993,
      );
      expect(
        PhoneCameraTarget.tryParse(
          {'source': 'camera'},
          worldId: 'w',
          taskId: 'task',
        ),
        isNull,
      );
    },
  );
}
