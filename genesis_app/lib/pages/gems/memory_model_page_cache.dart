import '../../network/api_exception.dart';
import '../../network/models/gem_model.dart';
import '../../network/models/user_memory_settings.dart';

/// In-memory settings data owned by one WorldPage lifecycle.
class MemoryModelPageCache {
  static final Map<String, Future<GemModelCatalog>> _modelCatalogRequests =
      <String, Future<GemModelCatalog>>{};

  GemModelCatalog? _modelCatalog;
  UserMemorySettings? _memorySettings;
  final Set<String> _modelCatalogPermissionDenied = <String>{};
  bool _disposed = false;

  GemModelCatalog? get modelCatalog => _disposed ? null : _modelCatalog;

  UserMemorySettings? get memorySettings => _disposed ? null : _memorySettings;

  void storeModelCatalog(GemModelCatalog catalog) {
    if (_disposed) return;
    _modelCatalog = catalog;
  }

  void storeMemorySettings(UserMemorySettings settings) {
    if (_disposed) return;
    _memorySettings = settings;
  }

  /// Globally coalesces model-list requests for one authenticated user and
  /// World, including requests started by different page cache instances.
  ///
  /// A permission denial is remembered only for this cache's lifecycle, which
  /// is owned by one WorldPage. Other failures remain retryable.
  Future<GemModelCatalog?> loadModelCatalog({
    required String uid,
    required String worldId,
    required Future<GemModelCatalog> Function() loader,
  }) async {
    final key = _modelCatalogRequestKey(uid: uid, worldId: worldId);
    if (_disposed ||
        key == null ||
        _modelCatalogPermissionDenied.contains(key)) {
      return null;
    }
    final pending = _modelCatalogRequests[key];
    if (pending != null) return pending;

    final request = Future<GemModelCatalog>.sync(loader);
    _modelCatalogRequests[key] = request;
    try {
      return await request;
    } on ApiException catch (error) {
      if (error.code == 10011) {
        if (!_disposed) _modelCatalogPermissionDenied.add(key);
        return null;
      }
      rethrow;
    } finally {
      if (identical(_modelCatalogRequests[key], request)) {
        _modelCatalogRequests.remove(key);
      }
    }
  }

  void clearModelCatalog() {
    if (_disposed) return;
    _modelCatalog = null;
  }

  void clearMemorySettings() {
    if (_disposed) return;
    _memorySettings = null;
  }

  void dispose() {
    _disposed = true;
    _modelCatalog = null;
    _memorySettings = null;
    _modelCatalogPermissionDenied.clear();
  }
}

String? _modelCatalogRequestKey({
  required String uid,
  required String worldId,
}) {
  final normalizedUid = uid.trim();
  final normalizedWorldId = worldId.trim();
  if (normalizedUid.isEmpty || normalizedWorldId.isEmpty) return null;
  return '$normalizedUid\u001f$normalizedWorldId';
}
