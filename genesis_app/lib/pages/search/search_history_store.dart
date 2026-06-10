import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  const SearchHistoryStore({String? ownerUid}) : _ownerUid = ownerUid;

  static const int maxItems = 50;
  static const String storageKey = 'search_recent_queries_v1';
  static const String anonymousOwnerUid = '__anonymous__';

  final String? _ownerUid;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKeyForOwner();
    return _normalize(
      prefs.getStringList(key) ??
          prefs.getStringList(storageKey) ??
          const <String>[],
    );
  }

  Future<List<String>> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return load();

    final prefs = await SharedPreferences.getInstance();
    final key = _storageKeyForOwner();
    final current =
        prefs.getStringList(key) ??
        prefs.getStringList(storageKey) ??
        const <String>[];
    final normalizedQuery = trimmed.toLowerCase();
    final next = <String>[
      trimmed,
      for (final item in current)
        if (item.trim().toLowerCase() != normalizedQuery) item,
    ];
    final normalized = _normalize(next);
    await prefs.setStringList(key, normalized);
    return normalized;
  }

  String _storageKeyForOwner() {
    final owner = (_ownerUid ?? '').trim();
    final resolvedOwner = owner.isEmpty ? anonymousOwnerUid : owner;
    return '$storageKey.$resolvedOwner';
  }

  List<String> _normalize(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (!seen.add(key)) continue;
      result.add(trimmed);
      if (result.length >= maxItems) break;
    }
    return result;
  }
}
