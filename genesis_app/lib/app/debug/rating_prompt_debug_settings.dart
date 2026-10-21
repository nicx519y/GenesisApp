import 'package:shared_preferences/shared_preferences.dart';

/// Display/debug override only. Never mutates the server config or user counters.
class RatingPromptDebugSettings {
  static const storageKey = 'developer_rating_prompt_message_count_v1';

  static Future<int?> read() async {
    final value = (await SharedPreferences.getInstance()).getInt(storageKey);
    return value != null && value >= 0 ? value : null;
  }

  static Future<int> resolve(int serverValue) async =>
      await read() ?? serverValue;

  static Future<void> save(int? count) async {
    if (count != null && count < 0) throw ArgumentError.value(count, 'count');
    final prefs = await SharedPreferences.getInstance();
    final saved = count == null
        ? await prefs.remove(storageKey)
        : await prefs.setInt(storageKey, count);
    if (!saved) throw StateError('Unable to save rating debug threshold');
  }
}
