import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MiniPhoneMusicProgress {
  const MiniPhoneMusicProgress({
    required this.file,
    required this.position,
    this.duration,
  });
  final String file;
  final Duration position;
  final Duration? duration;
}

abstract interface class MiniPhoneMusicProgressStore {
  Future<MiniPhoneMusicProgress?> read();
  Future<void> write(MiniPhoneMusicProgress progress);
}

/// A single current track per account/environment/World. Writes are ordered
/// across session instances, so immediately reopening a World sees its exit save.
class LocalMiniPhoneMusicProgressStore implements MiniPhoneMusicProgressStore {
  LocalMiniPhoneMusicProgressStore({
    required String namespace,
    required String worldId,
    required Future<String?> owner,
    Future<SharedPreferences> Function()? preferences,
  }) : _key = owner.then(
         (uid) =>
             'miniphone_music_v1:${Uri.encodeComponent(namespace)}:${Uri.encodeComponent(uid ?? "__guest__")}:${Uri.encodeComponent(worldId)}',
       ),
       _preferences = preferences ?? SharedPreferences.getInstance;
  final Future<String> _key;
  final Future<SharedPreferences> Function() _preferences;
  static final _writes = <String, Future<void>>{};

  @override
  Future<MiniPhoneMusicProgress?> read() async {
    final key = await _key;
    await _writes[key];
    final raw = (await _preferences()).getString(key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map ||
          data['file'] is! String ||
          (data['file'] as String).isEmpty ||
          data['position_ms'] is! int ||
          (data['position_ms'] as int) < 0) {
        return null;
      }
      final duration = data['duration_ms'];
      if (duration != null && (duration is! int || duration <= 0)) return null;
      return MiniPhoneMusicProgress(
        file: data['file'] as String,
        position: Duration(
          milliseconds: (data['position_ms'] as int).clamp(
            0,
            duration is int ? duration : 1 << 53,
          ),
        ),
        duration: duration is int ? Duration(milliseconds: duration) : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(MiniPhoneMusicProgress progress) async {
    final key = await _key;
    final write = (_writes[key] ?? Future.value())
        .catchError((Object _) {})
        .then((_) async {
          final prefs = await _preferences();
          await prefs.setString(
            key,
            jsonEncode({
              'file': progress.file,
              'position_ms': progress.position.inMilliseconds,
              'duration_ms': progress.duration?.inMilliseconds,
            }),
          );
        });
    _writes[key] = write;
    try {
      await write;
    } finally {
      if (identical(_writes[key], write)) _writes.remove(key);
    }
  }
}
