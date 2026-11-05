import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_photo.dart';

/// One unacknowledged write per location, with a separate durable active-job index.
class ChatPhotoRequestStore {
  ChatPhotoRequestStore(
    String environment,
    String uid,
    String world,
    String location, {
    int? roundId,
    int? cardId,
  }) : key = cardId == null
           ? 'chat-photo-request-v1:${jsonEncode([environment, uid, world, location])}'
           : 'chat-photo-request-v2:${jsonEncode([environment, uid, world, location, roundId, cardId])}';
  final String key;
  Future<ChatPhotoRequest?> read() async {
    final value = (await SharedPreferences.getInstance()).getString(key);
    return value == null
        ? null
        : ChatPhotoRequest.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          );
  }

  Future<void> save(ChatPhotoRequest request) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(request.toJson()),
    )) {
      throw StateError('Photo request could not be saved');
    }
  }

  Future<void> clear(String requestId) async {
    final current = await read();
    if (current?.requestId == requestId) {
      if (!await (await SharedPreferences.getInstance()).remove(key)) {
        throw StateError('Photo request could not be cleared');
      }
    }
  }

  static String newId() {
    final random = Random.secure();
    return 'chat-photo-${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }
}

/// Active jobs survive bounded message-cache eviction. Each task has its own
/// key so simultaneous jobs cannot overwrite one another's recovery metadata.
class ChatPhotoJobStore {
  ChatPhotoJobStore(
    String environment,
    String uid,
    String world,
    String location,
  ) : prefix =
          'chat-photo-job-v1:${jsonEncode([environment, uid, world, location])}:';
  final String prefix;
  Future<List<Map<String, dynamic>>> read() async {
    final preferences = await SharedPreferences.getInstance();
    return [
      for (final key in preferences.getKeys().where(
        (key) => key.startsWith(prefix),
      ))
        Map<String, dynamic>.from(
          jsonDecode(preferences.getString(key)!) as Map,
        ),
    ];
  }

  Future<void> remove(String taskId) async {
    await (await SharedPreferences.getInstance()).remove('$prefix$taskId');
  }

  Future<void> update(
    Map<String, dynamic> message, {
    ChatPhotoRequest? request,
  }) async {
    final payload = message['raw_payload'] ?? message['payload'];
    final photo = ChatPhoto.fromJson((payload as Map)['photo']);
    final preferences = await SharedPreferences.getInstance();
    final key = '$prefix${photo.taskId}';
    if (photo.terminal) {
      await preferences.remove(key);
      return;
    }
    final previous = preferences.getString(key);
    final old = previous == null
        ? const <String, dynamic>{}
        : jsonDecode(previous) as Map;
    final value = {
      ...message,
      if (request != null || old['photo_request'] != null)
        'photo_request': request?.toJson() ?? old['photo_request'],
    };
    if (!await preferences.setString(key, jsonEncode(value))) {
      throw StateError('Photo task could not be saved');
    }
  }
}
