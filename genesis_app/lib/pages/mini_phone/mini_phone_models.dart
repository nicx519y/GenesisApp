part of 'mini_phone_page.dart';

// Read the room's catalogue; writes/settings and discounted quotes stay local.
const _phonePreviewWorldId = 'local-mini-phone-preview';

extension _MiniPhoneSessionModels on MiniPhoneSession {
  Future<void> _ensurePhoneModels() =>
      _phoneReferencePending ??= Future<void>(_readPhoneModels);
  Future<void> _readPhoneModels() async {
    final generation = _phoneReferenceGeneration;
    final loader = _phoneReferenceLoader;
    final cached = _phoneSourceCatalog;
    try {
      final source = cached ?? await loader!();
      if (generation != _phoneReferenceGeneration) {
        throw StateError('Model reference changed.');
      }
      final models = source.groups.expand((group) => group.models).toList();
      if (models.isEmpty) throw StateError('No models available.');
      _phoneSourceCatalog = source;
      if (!_phoneSourceInitialized) {
        _miniPhoneModelCode = source.selectedModelCode;
        if (!models.any((model) => model.modelCode == _miniPhoneModelCode)) {
          _miniPhoneModelCode = models.first.modelCode;
        }
        _miniPhoneTokens = models.first.minMemoryTokens;
        _phoneSourceInitialized = true;
      }
    } catch (_) {
      if (generation == _phoneReferenceGeneration) {
        _phoneReferencePending = null;
      }
      rethrow;
    }
  }

  String get _miniPhoneModelLabel =>
      _phoneSourceCatalog?.titlesByCode()[_miniPhoneModelCode] ?? 'Model';
  int get _phoneTokenMax {
    final limits = _phoneSourceCatalog!.groups
        .expand((group) => group.models)
        .map((model) => model.maxMemoryTokens);
    return limits.reduce((a, b) => a < b ? a : b);
  }

  Future<UserMemorySettings> _phoneMemory() async {
    await _ensurePhoneModels();
    return UserMemorySettings(
      memoryTokens: _miniPhoneTokens,
      minMemoryTokens: 1000,
      maxMemoryTokens: _phoneTokenMax,
      memoryUsedTokens: 0,
      worldId: _phonePreviewWorldId,
    );
  }

  Future<GemModelCatalog> _phoneCatalog() async {
    await _ensurePhoneModels();
    final source = _phoneSourceCatalog!;
    int price(int cents) => (cents * .4).round();
    return GemModelCatalog(
      selectedModelCode: _miniPhoneModelCode,
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
                            _miniPhoneTokens /
                            model.minMemoryTokens)
                        .round(),
                  ),
                  estimatedNextTickGemsCent: price(
                    (model.estimatedNextTickGemsCent *
                            _miniPhoneTokens /
                            model.minMemoryTokens)
                        .round(),
                  ),
                  description: model.description,
                  minGemsCent: price(
                    (model.minGemsCent *
                            _miniPhoneTokens /
                            model.minMemoryTokens)
                        .round(),
                  ),
                  maxGemsCent: price(model.maxGemsCent),
                  minMemoryTokens: _miniPhoneTokens,
                  maxMemoryTokens: model.maxMemoryTokens,
                ),
            ],
          ),
      ],
    );
  }
}

extension _MiniPhoneModels on _MiniPhonePageState {
  Widget _models() => MemoryModelPage(
    worldId: _phonePreviewWorldId,
    onBack: _back,
    catalogLoader: (_) => _session._phoneCatalog(),
    selectionHandler: (_, code) async {
      _session._miniPhoneModelCode = code;
      return GemModelSelection(selectedModelCode: code);
    },
    selectedModelCodeCacheWriter: (_) async {},
    memorySettingsLoader: (_) => _session._phoneMemory(),
    memorySettingsUpdater: (tokens) async {
      _session._miniPhoneTokens = tokens;
      return _session._phoneMemory();
    },
  );
}
