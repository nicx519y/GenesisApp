import '../../../l10n/genesis_l10n.dart';
import '../../../network/models/gem_model.dart';
import '../../gems/memory_model_page_cache.dart';

class MiniPhoneModelSettings {
  GemModelCatalog? sourceCatalog;
  MemoryModelPageCache pageCache = MemoryModelPageCache();
  String _referenceWorldId = '';
  int _phoneReferenceGeneration = 0;
  Future<GemModelCatalog> Function()? _phoneReferenceLoader;
  Future<GemModelCatalog>? _phoneReferencePending;

  String get worldId => _referenceWorldId;
  String get selectedModelCode =>
      (pageCache.modelCatalog ?? sourceCatalog)?.selectedModelCode ?? '';

  void configure({
    required String worldId,
    required Future<GemModelCatalog> Function() loader,
    GemModelCatalog? cached,
  }) {
    _phoneReferenceLoader = loader;
    _phoneReferenceGeneration++;
    if (_referenceWorldId != worldId) {
      clear();
      _referenceWorldId = worldId;
    }
    sourceCatalog = cached ?? sourceCatalog;
    _phoneReferencePending = null;
  }

  void dispose() {
    _phoneReferenceGeneration++;
    _phoneReferenceLoader = null;
    sourceCatalog = null;
    pageCache.dispose();
  }

  void clear() {
    _phoneReferenceGeneration++;
    _phoneReferencePending = null;
    sourceCatalog = null;
    pageCache.dispose();
    pageCache = MemoryModelPageCache();
  }

  Future<void> ensureLoaded() async {
    if (sourceCatalog == null) await catalog();
  }

  Future<GemModelCatalog> catalog() =>
      _phoneReferencePending ??= _readPhoneModels();

  Future<GemModelCatalog> _readPhoneModels() async {
    final generation = _phoneReferenceGeneration;
    final loader = _phoneReferenceLoader;
    try {
      final source = await loader!();
      if (generation != _phoneReferenceGeneration) {
        throw StateError('Model reference changed.');
      }
      final models = source.groups.expand((group) => group.models).toList();
      if (models.isEmpty) throw StateError('No models available.');
      sourceCatalog = source;
      return source;
    } finally {
      if (generation == _phoneReferenceGeneration) {
        _phoneReferencePending = null;
      }
    }
  }

  String get label =>
      (pageCache.modelCatalog ?? sourceCatalog)
          ?.titlesByCode()[selectedModelCode] ??
      GenesisL10n.current.miniPhoneModel;
}
