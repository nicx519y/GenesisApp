import '../../network/models/gem_model.dart';
import '../../network/models/user_memory_settings.dart';

/// In-memory settings data owned by one WorldPage lifecycle.
class MemoryModelPageCache {
  GemModelCatalog? _modelCatalog;
  UserMemorySettings? _memorySettings;
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

  void clearModelCatalog() {
    if (_disposed) return;
    _modelCatalog = null;
  }

  void dispose() {
    _disposed = true;
    _modelCatalog = null;
    _memorySettings = null;
  }
}
