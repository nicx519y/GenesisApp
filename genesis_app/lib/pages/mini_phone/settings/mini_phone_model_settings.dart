import '../../../l10n/genesis_l10n.dart';
import '../../../network/models/gem_model.dart';
import '../../../network/models/user_memory_settings.dart';

// This setting remains local to the World-owned phone session.
const miniPhoneModelPreviewWorldId = 'local-mini-phone-preview';

class MiniPhoneModelSettings {
  GemModelCatalog? sourceCatalog;
  String _referenceWorldId = '';
  int _phoneReferenceGeneration = 0;
  Future<GemModelCatalog> Function()? _phoneReferenceLoader;
  Future<void>? _phoneReferencePending;
  bool _phoneSourceInitialized = false;
  String selectedModelCode = '';
  int memoryTokens = 8000;

  void configure({
    required String worldId,
    required Future<GemModelCatalog> Function() loader,
    GemModelCatalog? cached,
  }) {
    _phoneReferenceLoader = loader;
    _phoneReferenceGeneration++;
    if (_referenceWorldId != worldId) {
      sourceCatalog = null;
      _phoneSourceInitialized = false;
      _referenceWorldId = worldId;
    }
    sourceCatalog = cached ?? sourceCatalog;
    _phoneReferencePending = null;
  }

  void dispose() {
    _phoneReferenceGeneration++;
    _phoneReferenceLoader = null;
    sourceCatalog = null;
  }

  Future<void> ensureLoaded() =>
      _phoneReferencePending ??= Future<void>(_readPhoneModels);
  Future<void> _readPhoneModels() async {
    final generation = _phoneReferenceGeneration;
    final loader = _phoneReferenceLoader;
    final cached = sourceCatalog;
    try {
      final source = cached ?? await loader!();
      if (generation != _phoneReferenceGeneration) {
        throw StateError('Model reference changed.');
      }
      final models = source.groups.expand((group) => group.models).toList();
      if (models.isEmpty) throw StateError('No models available.');
      sourceCatalog = source;
      if (!_phoneSourceInitialized) {
        selectedModelCode = source.selectedModelCode;
        if (!models.any((model) => model.modelCode == selectedModelCode)) {
          selectedModelCode = models.first.modelCode;
        }
        memoryTokens = models.first.minMemoryTokens;
        _phoneSourceInitialized = true;
      }
    } catch (_) {
      if (generation == _phoneReferenceGeneration) {
        _phoneReferencePending = null;
      }
      rethrow;
    }
  }

  String get label =>
      sourceCatalog?.titlesByCode()[selectedModelCode] ??
      GenesisL10n.current.miniPhoneModel;
  int get _phoneTokenMax {
    final limits = sourceCatalog!.groups
        .expand((group) => group.models)
        .map((model) => model.maxMemoryTokens);
    return limits.reduce((a, b) => a < b ? a : b);
  }

  Future<UserMemorySettings> memory() async {
    await ensureLoaded();
    return UserMemorySettings(
      memoryTokens: memoryTokens,
      minMemoryTokens: 1000,
      maxMemoryTokens: _phoneTokenMax,
      memoryUsedTokens: 0,
      worldId: miniPhoneModelPreviewWorldId,
    );
  }

  Future<GemModelCatalog> catalog() async {
    await ensureLoaded();
    final source = sourceCatalog!;
    int price(int cents) => (cents * .4).round();
    return GemModelCatalog(
      selectedModelCode: selectedModelCode,
      groups: [
        for (final group in source.groups)
          GemModelGroup(
            groupCode: group.groupCode,
            groupTitle: group.groupTitle,
            models: [
              for (final model in group.models)
                GemModel(
                  modelCode: model.modelCode,
                  title: model.title,
                  tags: model.tags,
                  estimatedNextMessageGemsCent: price(
                    (model.estimatedNextMessageGemsCent *
                            memoryTokens /
                            model.minMemoryTokens)
                        .round(),
                  ),
                  estimatedNextTickGemsCent: price(
                    (model.estimatedNextTickGemsCent *
                            memoryTokens /
                            model.minMemoryTokens)
                        .round(),
                  ),
                  description: model.description,
                  minGemsCent: price(
                    (model.minGemsCent * memoryTokens / model.minMemoryTokens)
                        .round(),
                  ),
                  maxGemsCent: price(model.maxGemsCent),
                  minMemoryTokens: memoryTokens,
                  maxMemoryTokens: model.maxMemoryTokens,
                ),
            ],
          ),
      ],
    );
  }
}
