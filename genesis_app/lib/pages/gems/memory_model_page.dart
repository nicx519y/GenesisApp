import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/page_header.dart';
import '../../network/api_exception.dart';
import '../../network/models/gem_model.dart';
import '../../network/models/user_memory_settings.dart';
import '../../ui/components/genesis_info_card.dart';
import '../../ui/components/genesis_primary_button.dart';
import '../../ui/components/genesis_refresh_indicator.dart';
import '../../ui/theme/genesis_dark_theme.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_typography.dart';
import '../../utils/gem_amount.dart';
import 'memory_model_page_cache.dart';

typedef GemModelCatalogLoader =
    Future<GemModelCatalog> Function(String worldId);
typedef GemModelSelectionHandler =
    Future<GemModelSelection> Function(String worldId, String modelCode);
typedef SelectedModelCodeCacheWriter = Future<void> Function(String modelCode);
typedef UserMemorySettingsLoader =
    Future<UserMemorySettings> Function(String? worldId);
typedef UserMemorySettingsUpdater =
    Future<UserMemorySettings> Function(int memoryTokens);

class MemoryModelPage extends StatefulWidget {
  const MemoryModelPage({
    super.key,
    required this.worldId,
    this.catalogLoader,
    this.selectionHandler,
    this.selectedModelCodeCacheWriter,
    this.memorySettingsLoader,
    this.memorySettingsUpdater,
    this.pageCache,
  });

  final String worldId;
  final GemModelCatalogLoader? catalogLoader;
  final GemModelSelectionHandler? selectionHandler;
  final SelectedModelCodeCacheWriter? selectedModelCodeCacheWriter;
  final UserMemorySettingsLoader? memorySettingsLoader;
  final UserMemorySettingsUpdater? memorySettingsUpdater;
  final MemoryModelPageCache? pageCache;

  @override
  State<MemoryModelPage> createState() => _MemoryModelPageState();
}

class _MemoryModelPageState extends State<MemoryModelPage> {
  static const int _minMemoryLimitTokens = 4000;
  static const Duration _memoryAutosaveDelay = Duration(milliseconds: 500);

  GemModelCatalog? _catalog;
  Object? _error;
  bool _loading = false;
  String _pendingModelCode = '';
  String _confirmedModelCode = '';
  int _loadGeneration = 0;
  String _trackedPageWorldId = '';

  int _memoryLoadGeneration = 0;
  UserMemorySettings? _memorySettings;
  UserMemorySettings? _rangeMemorySettings;
  int? _confirmedMemoryTokens;
  int? _lastSavedMemoryTokens;
  Object? _memoryError;
  bool _memoryLoading = false;
  int _pendingMemoryTokens = 0;
  int _modelRevision = 0;
  int _memoryRevision = 0;
  int? _modelInFlightRevision;
  int? _memoryInFlightRevision;
  int? _memoryUncertainRevision;
  final Set<int> _queuedModelRevisions = <int>{};
  final Set<int> _queuedMemoryRevisions = <int>{};
  _ModelSaveRequest? _latestModelRequest;
  _MemorySaveRequest? _latestMemoryRequest;
  Timer? _memorySaveTimer;
  Future<void> _modelSaveTail = Future<void>.value();
  Future<void> _memorySaveTail = Future<void>.value();
  bool _exitFlushStarted = false;

  @override
  void initState() {
    super.initState();
    _trackSwitchModelPage();
    unawaited(_refresh(useCache: true));
    unawaited(_loadMemorySettings(useCache: true));
  }

  @override
  void didUpdateWidget(covariant MemoryModelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldId != widget.worldId) {
      _memorySaveTimer?.cancel();
      _modelRevision += 1;
      _memoryRevision += 1;
      _latestModelRequest = null;
      _latestMemoryRequest = null;
      _memoryUncertainRevision = null;
      _rangeMemorySettings = null;
      _confirmedMemoryTokens = null;
      _lastSavedMemoryTokens = null;
      _trackSwitchModelPage();
      unawaited(_refresh());
      unawaited(_loadMemorySettings());
    }
  }

  @override
  void dispose() {
    _flushPendingOnExit();
    _loadGeneration += 1;
    _memoryLoadGeneration += 1;
    _memorySaveTimer?.cancel();
    super.dispose();
  }

  void _trackSwitchModelPage() {
    final worldId = widget.worldId.trim();
    if (worldId.isEmpty || worldId == _trackedPageWorldId) return;
    _trackedPageWorldId = worldId;
    GenesisTelemetry.collectLog(
      actionType: 'pay_event',
      action: 'switch_model_page',
      object1: worldId,
    );
  }

  Future<GemModelCatalog> _loadCatalog({bool useCache = false}) {
    final cache = widget.pageCache;
    final cached =
        useCache && cache?.memorySettings?.worldId == widget.worldId.trim()
        ? cache?.modelCatalog
        : null;
    if (cached != null) return Future<GemModelCatalog>.value(cached);
    final loader = widget.catalogLoader;
    if (loader != null) return loader(widget.worldId);
    return AppServicesScope.read(
      context,
    ).api.v1.gem.models(worldId: widget.worldId);
  }

  Future<UserMemorySettings> _loadMemory(String? worldId) {
    final loader = widget.memorySettingsLoader;
    if (loader != null) return loader(worldId);
    return AppServicesScope.read(
      context,
    ).api.v1.user.memorySettings(worldId: worldId);
  }

  Future<void> _loadMemorySettings({
    bool preservePending = false,
    bool useCache = false,
  }) async {
    final pageCache = widget.pageCache;
    final worldId = widget.worldId.trim();
    final generation = ++_memoryLoadGeneration;
    setState(() {
      _memoryLoading = true;
      _memoryError = null;
      if (!preservePending) {
        _memorySettings = null;
        _rangeMemorySettings = null;
        _pendingMemoryTokens = 0;
        _latestMemoryRequest = null;
        _memoryUncertainRevision = null;
      }
    });
    try {
      final loaded = _validatedMemorySettings(
        await (useCache && pageCache?.memorySettings?.worldId == worldId
            ? Future<UserMemorySettings>.value(pageCache!.memorySettings!)
            : _loadMemory(worldId)),
        requireWorldUsage: true,
        expectedWorldId: worldId,
      );
      if (generation != _memoryLoadGeneration) return;
      pageCache?.storeMemorySettings(loaded);
      if (!mounted) return;
      setState(() {
        _memorySettings = loaded;
        _rangeMemorySettings = loaded;
        _confirmedMemoryTokens = loaded.memoryTokens;
        _lastSavedMemoryTokens = loaded.memoryTokens;
        if (!preservePending || _latestMemoryRequest == null) {
          _pendingMemoryTokens = loaded.memoryTokens;
        } else {
          _pendingMemoryTokens = _pendingMemoryTokens.clamp(
            _minMemoryLimitTokens,
            loaded.maxMemoryTokens,
          );
        }
        _memoryLoading = false;
      });
      if (_hasBudgetMismatch) pageCache?.clearModelCatalog();
    } catch (error) {
      debugPrint('[GemModel] load memory settings failed: $error');
      if (!mounted || generation != _memoryLoadGeneration) return;
      setState(() {
        _memoryError = error;
        _memoryLoading = false;
      });
    }
  }

  UserMemorySettings _validatedMemorySettings(
    UserMemorySettings settings, {
    bool requireWorldUsage = false,
    String? expectedWorldId,
  }) {
    final memoryUsedTokens = settings.memoryUsedTokens;
    final responseWorldId = settings.worldId?.trim() ?? '';
    if (settings.minMemoryTokens <= 0 ||
        settings.maxMemoryTokens < settings.minMemoryTokens ||
        settings.maxMemoryTokens < _minMemoryLimitTokens ||
        settings.memoryTokens < _minMemoryLimitTokens ||
        settings.memoryTokens > settings.maxMemoryTokens ||
        (requireWorldUsage && responseWorldId.isEmpty) ||
        (expectedWorldId != null && responseWorldId != expectedWorldId) ||
        (requireWorldUsage && memoryUsedTokens == null) ||
        (memoryUsedTokens != null &&
            (memoryUsedTokens < 0 ||
                memoryUsedTokens > settings.memoryTokens))) {
      throw const FormatException('Invalid memory settings range');
    }
    return settings;
  }

  Future<void> _refreshAll() => _refreshSnapshot();

  bool get _hasBudgetMismatch {
    final budget = _confirmedMemoryTokens;
    return budget != null &&
        (_catalog?.groups
                .expand((group) => group.models)
                .any((model) => model.minMemoryTokens != budget) ??
            false);
  }

  /// Fetch both saved ranges before publishing either. Initial loading remains
  /// independent so unavailable memory data does not hide the model catalog.
  Future<void> _refreshSnapshot({UserMemorySettings? saved}) async {
    final worldId = widget.worldId.trim();
    final pageCache = widget.pageCache;
    final modelRevision = _modelRevision;
    final modelSavePending = _latestModelRequest != null;
    final generation = ++_loadGeneration;
    final memoryGeneration = ++_memoryLoadGeneration;
    setState(() {
      _loading = true;
      _memoryLoading = saved == null || _memorySettings == null;
    });
    GemModelCatalog? catalog;
    UserMemorySettings? memory;
    Object? catalogError;
    Object? memoryError;
    await Future.wait<void>([
      () async {
        try {
          catalog = await _loadCatalog();
        } catch (error) {
          catalogError = error;
        }
      }(),
      () async {
        try {
          memory = _validatedMemorySettings(
            await _loadMemory(worldId),
            requireWorldUsage: true,
            expectedWorldId: worldId,
          );
          if (saved != null && memory!.memoryTokens != saved.memoryTokens) {
            throw const FormatException('Saved memory budget mismatch');
          }
        } catch (error) {
          memory = null;
          memoryError = error;
        }
      }(),
    ]);
    if (!mounted ||
        widget.worldId.trim() != worldId ||
        generation != _loadGeneration ||
        memoryGeneration != _memoryLoadGeneration) {
      return;
    }

    final budget =
        saved?.memoryTokens ?? memory?.memoryTokens ?? _confirmedMemoryTokens;
    if (catalog != null &&
        budget != null &&
        catalog!.groups
            .expand((group) => group.models)
            .any((model) => model.minMemoryTokens != budget)) {
      catalogError = const FormatException('Model quotation budget mismatch');
      catalog = null;
    }
    if (catalog != null) {
      // A concurrent model save owns selection; this read owns quotations only.
      if (modelSavePending ||
          modelRevision != _modelRevision ||
          _latestModelRequest != null) {
        catalog = catalog!.copyWith(selectedModelCode: _confirmedModelCode);
      } else {
        _confirmedModelCode = catalog!.selectedModelCode.trim();
        _pendingModelCode = _confirmedModelCode;
      }
      pageCache?.storeModelCatalog(catalog!);
    } else {
      pageCache?.clearModelCatalog();
    }
    if (memory != null) {
      pageCache?.storeMemorySettings(memory!);
    } else {
      pageCache?.clearMemorySettings();
    }
    setState(() {
      _catalog = catalog ?? _catalog;
      _error = catalogError;
      _loading = false;
      _rangeMemorySettings = memory;
      _confirmedMemoryTokens = budget;
      _memoryError = memoryError;
      _memoryLoading = false;
      if (memory != null) {
        _memorySettings = memory;
        _lastSavedMemoryTokens = memory!.memoryTokens;
      } else if (saved != null) {
        // Preserve the existing top-summary fallback, but never present it as
        // an authoritative memory range or cache it for a later page entry.
        _memorySettings = UserMemorySettings(
          memoryTokens: saved.memoryTokens,
          minMemoryTokens: saved.minMemoryTokens,
          maxMemoryTokens: saved.maxMemoryTokens,
          worldId: worldId,
          memoryUsedTokens: _memorySettings?.memoryUsedTokens?.clamp(
            0,
            saved.memoryTokens,
          ),
        );
      }
      if (_latestMemoryRequest == null && budget != null) {
        _pendingMemoryTokens = budget;
      }
    });
  }

  Future<void> _refresh({
    bool preserveContent = false,
    bool useCache = false,
  }) async {
    final pageCache = widget.pageCache;
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
      if (!preserveContent) _catalog = null;
    });
    try {
      final catalog = await _loadCatalog(useCache: useCache);
      if (generation != _loadGeneration) return;
      pageCache?.storeModelCatalog(catalog);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _confirmedModelCode = catalog.selectedModelCode.trim();
        if (_latestModelRequest == null) {
          _pendingModelCode = _confirmedModelCode;
        }
        _loading = false;
      });
      if (_hasBudgetMismatch) pageCache?.clearModelCatalog();
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _selectModel(GemModel model) {
    final modelCode = model.modelCode.trim();
    if (modelCode.isEmpty || modelCode == _pendingModelCode) return;
    setState(() => _pendingModelCode = modelCode);
    _modelRevision += 1;

    if (modelCode == _confirmedModelCode &&
        _modelInFlightRevision == null &&
        _queuedModelRevisions.isEmpty) {
      _latestModelRequest = null;
      return;
    }

    final request = _captureModelSaveRequest(_modelRevision, modelCode);
    _latestModelRequest = request;
    _enqueueModelSave(request, showFailure: true);
  }

  void _changeMemory(int memoryTokens) {
    if (memoryTokens == _pendingMemoryTokens) return;
    setState(() => _pendingMemoryTokens = memoryTokens);
    _memoryRevision += 1;
    _memoryUncertainRevision = null;
    _memorySaveTimer?.cancel();

    final settings = _memorySettings;
    if (settings == null) return;
    if (memoryTokens == settings.memoryTokens &&
        _memoryInFlightRevision == null &&
        _queuedMemoryRevisions.isEmpty) {
      _latestMemoryRequest = null;
      return;
    }

    final request = _captureMemorySaveRequest(_memoryRevision, memoryTokens);
    _latestMemoryRequest = request;
    _memorySaveTimer = Timer(
      _memoryAutosaveDelay,
      () => _enqueueMemorySave(request, showFailure: true),
    );
  }

  _ModelSaveRequest _captureModelSaveRequest(int revision, String modelCode) {
    final worldId = widget.worldId.trim();
    final injectedHandler = widget.selectionHandler;
    final api = injectedHandler == null
        ? AppServicesScope.read(context).api
        : null;
    Future<GemModelSelection> save() => injectedHandler != null
        ? injectedHandler(worldId, modelCode)
        : api!.v1.gem.selectModel(worldId: worldId, modelCode: modelCode);

    final injectedWriter = widget.selectedModelCodeCacheWriter;
    SelectedModelCodeCacheWriter? cacheWriter = injectedWriter;
    if (cacheWriter == null && injectedHandler == null) {
      final sessionStore = AppServicesScope.read(context).sessionStore;
      final title = _catalog?.titlesByCode()[modelCode] ?? '';
      cacheWriter = (selectedModelCode) async {
        final current = await sessionStore.readUserInfo();
        await sessionStore.saveUserInfo(
          userInfoWithSelectedGemModel(
            current,
            selectedModelCode: selectedModelCode,
            titlesByCode: title.isEmpty
                ? const <String, String>{}
                : <String, String>{selectedModelCode: title},
          ),
        );
      };
    }
    return _ModelSaveRequest(
      revision: revision,
      modelCode: modelCode,
      worldId: worldId,
      save: save,
      cacheWriter: cacheWriter,
    );
  }

  _MemorySaveRequest _captureMemorySaveRequest(int revision, int memoryTokens) {
    final worldId = widget.worldId.trim();
    final injectedUpdater = widget.memorySettingsUpdater;
    final injectedLoader = widget.memorySettingsLoader;
    final services = injectedUpdater == null || injectedLoader == null
        ? AppServicesScope.read(context)
        : null;
    return _MemorySaveRequest(
      revision: revision,
      memoryTokens: memoryTokens,
      worldId: worldId,
      pageCache: widget.pageCache,
      save: () => injectedUpdater != null
          ? injectedUpdater(memoryTokens)
          : services!.api.v1.user.updateMemorySettings(
              memoryTokens: memoryTokens,
            ),
      loadGlobal: () => injectedLoader != null
          ? injectedLoader(null)
          : services!.api.v1.user.memorySettings(),
    );
  }

  void _enqueueModelSave(
    _ModelSaveRequest request, {
    required bool showFailure,
  }) {
    if (_queuedModelRevisions.contains(request.revision) ||
        _modelInFlightRevision == request.revision) {
      return;
    }
    _queuedModelRevisions.add(request.revision);
    _modelSaveTail = _modelSaveTail
        .catchError((Object _) {})
        .then((_) => _performModelSave(request, showFailure: showFailure));
    unawaited(_modelSaveTail);
  }

  Future<void> _performModelSave(
    _ModelSaveRequest request, {
    required bool showFailure,
  }) async {
    _queuedModelRevisions.remove(request.revision);
    if (request.revision != _modelRevision ||
        _latestModelRequest?.revision != request.revision) {
      return;
    }
    _modelInFlightRevision = request.revision;
    try {
      if (request.worldId.isNotEmpty) {
        GenesisTelemetry.collectLog(
          actionType: 'pay_event',
          action: 'switch_model_save',
          object1: request.worldId,
          object2: request.modelCode,
        );
      }
      final result = await request.save();
      final responseCode = result.selectedModelCode.trim();
      final selectedModelCode = responseCode.isEmpty
          ? request.modelCode
          : responseCode;
      try {
        await request.cacheWriter?.call(selectedModelCode);
      } catch (error) {
        debugPrint('[GemModel] cache selected model failed: $error');
      }
      if (request.worldId != widget.worldId.trim()) return;
      _confirmedModelCode = selectedModelCode;
      final updatedCatalog = _catalog?.copyWith(
        selectedModelCode: selectedModelCode,
      );
      // Patch only an existing valid cache. A memory save may have invalidated
      // quotations while model selection was in flight, including after exit.
      final pageCache = widget.pageCache;
      final cached = pageCache?.modelCatalog;
      if (cached != null &&
          pageCache?.memorySettings?.worldId == request.worldId) {
        pageCache?.storeModelCatalog(
          cached.copyWith(selectedModelCode: selectedModelCode),
        );
      }
      if (!mounted) return;
      setState(() {
        _catalog = updatedCatalog;
        if (request.revision == _modelRevision) {
          _pendingModelCode = selectedModelCode;
          _latestModelRequest = null;
        }
      });
    } catch (error, stackTrace) {
      if (request.worldId != widget.worldId.trim()) return;
      debugPrint('[GemModel] autosave model failed: $error');
      GenesisTelemetry.captureException(error, stackTrace);
      if (request.revision == _modelRevision) {
        _latestModelRequest = null;
        if (mounted) {
          setState(() => _pendingModelCode = _confirmedModelCode);
        } else {
          _pendingModelCode = _confirmedModelCode;
        }
      }
      if (mounted && showFailure && request.revision == _modelRevision) {
        showGenesisToast(context, 'Save failed', brightness: Brightness.dark);
      }
    } finally {
      if (_modelInFlightRevision == request.revision) {
        _modelInFlightRevision = null;
      }
    }
  }

  void _enqueueMemorySave(
    _MemorySaveRequest request, {
    required bool showFailure,
  }) {
    if (_queuedMemoryRevisions.contains(request.revision) ||
        _memoryInFlightRevision == request.revision ||
        _memoryUncertainRevision == request.revision) {
      return;
    }
    _queuedMemoryRevisions.add(request.revision);
    _memorySaveTail = _memorySaveTail
        .catchError((Object _) {})
        .then((_) => _performMemorySave(request, showFailure: showFailure));
    unawaited(_memorySaveTail);
  }

  Future<void> _performMemorySave(
    _MemorySaveRequest request, {
    required bool showFailure,
  }) async {
    _queuedMemoryRevisions.remove(request.revision);
    if (request.revision != _memoryRevision ||
        _latestMemoryRequest?.revision != request.revision) {
      return;
    }
    _memoryInFlightRevision = request.revision;
    try {
      final saved = _validatedMemorySettings(await request.save());
      request.pageCache?.clearMemorySettings();
      request.pageCache?.clearModelCatalog();
      if (!mounted || request.worldId != widget.worldId.trim()) return;
      // The POST confirms persistence before quotation/usage refresh finishes.
      _lastSavedMemoryTokens = saved.memoryTokens;
      if (request.revision == _memoryRevision) {
        _latestMemoryRequest = null;
        _memoryUncertainRevision = null;
      }
      await _refreshSnapshot(saved: saved);
    } catch (error, stackTrace) {
      if (request.worldId != widget.worldId.trim()) return;
      debugPrint('[GemModel] autosave memory failed: $error');
      GenesisTelemetry.captureException(error, stackTrace);
      final uncertain = _isUncertainMemorySave(error);
      if (request.revision == _memoryRevision) {
        _memorySaveTimer?.cancel();
        _latestMemoryRequest = null;
        _memoryUncertainRevision = uncertain ? request.revision : null;
        final previous =
            _lastSavedMemoryTokens ?? _memorySettings!.memoryTokens;
        if (mounted) {
          setState(() => _pendingMemoryTokens = previous);
        } else {
          _pendingMemoryTokens = previous;
        }
      }
      if (uncertain) {
        try {
          await request.loadGlobal();
        } catch (reconcileError) {
          debugPrint(
            '[GemModel] reconcile uncertain memory save failed: '
            '$reconcileError',
          );
        }
        if (mounted && showFailure && request.revision == _memoryRevision) {
          showGenesisToast(
            context,
            'Save result not confirmed',
            brightness: Brightness.dark,
          );
        }
      } else if (mounted &&
          showFailure &&
          request.revision == _memoryRevision) {
        showGenesisToast(context, 'Save failed', brightness: Brightness.dark);
      }
    } finally {
      if (_memoryInFlightRevision == request.revision) {
        _memoryInFlightRevision = null;
      }
    }
  }

  void _flushPendingOnExit() {
    if (_exitFlushStarted) return;
    _exitFlushStarted = true;
    _memorySaveTimer?.cancel();
    final modelRequest = _latestModelRequest;
    if (modelRequest != null) {
      _enqueueModelSave(modelRequest, showFailure: false);
    }
    final memoryRequest = _latestMemoryRequest;
    if (memoryRequest != null &&
        _memoryUncertainRevision != memoryRequest.revision) {
      _enqueueMemorySave(memoryRequest, showFailure: false);
    }
  }

  void _closePage() {
    _flushPendingOnExit();
    Navigator.of(context).pop(_confirmedModelCode);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _flushPendingOnExit();
      },
      child: GenesisDarkTheme(
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: GenesisColors.darkBackground,
            appBar: GenesisBackAppBar(
              pageName: 'Memory & Model',
              onBack: _closePage,
            ),
            body: SafeArea(top: false, child: _buildBody()),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return GenesisRefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildMemoryArea(),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'Choose model'),
          const SizedBox(height: 12),
          _buildModelArea(),
        ],
      ),
    );
  }

  Widget _buildMemoryArea() {
    final settings = _memorySettings;
    if (settings == null && _memoryLoading) {
      return const KeyedSubtree(
        key: ValueKey('memory-settings-loading'),
        child: _MemorySettingsLoadingSkeleton(
          key: ValueKey('memory-settings-loading-skeleton'),
        ),
      );
    }
    if ((settings == null || settings.memoryUsedTokens == null) &&
        _memoryError != null) {
      return _MemoryLoadError(onRetry: () => unawaited(_refreshAll()));
    }
    if (settings == null) return const SizedBox.shrink();

    return Column(
      children: [
        _CurrentMemorySummary(memoryUsedTokens: settings.memoryUsedTokens!),
        const SizedBox(height: 30),
        const Align(
          alignment: Alignment.centerLeft,
          child: _SectionTitle(title: 'Max memory token limit'),
        ),
        const SizedBox(height: 10),
        _MaxMemoryLimitCard(
          memoryTokens: _pendingMemoryTokens,
          minMemoryTokens: _minMemoryLimitTokens,
          maxMemoryTokens: settings.maxMemoryTokens,
          enabled: !_memoryLoading,
          onChanged: _changeMemory,
        ),
      ],
    );
  }

  Widget _buildModelArea() {
    final catalog = _catalog;
    if (catalog == null && _loading) {
      return const KeyedSubtree(
        key: ValueKey('gem-model-page-loading'),
        child: _ModelCatalogLoadingSkeleton(
          key: ValueKey('gem-model-page-loading-skeleton'),
        ),
      );
    }
    if (catalog == null && _error != null) {
      return _ModelLoadError(onRetry: () => unawaited(_refreshAll()));
    }
    final models =
        catalog?.groups
            .expand((group) => group.models)
            .toList(growable: false) ??
        const <GemModel>[];
    if (models.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'No models available',
            style: TextStyle(
              fontSize: 14,
              color: GenesisColors.darkTextTertiary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < models.length; index += 1) ...[
          _GemModelTile(
            model: models[index],
            memorySettings: _rangeMemorySettings,
            quoteAvailable: _error == null && !_hasBudgetMismatch,
            selected: models[index].modelCode == _pendingModelCode,
            enabled: true,
            onTap: () => _selectModel(models[index]),
          ),
          if (index != models.length - 1) const SizedBox(height: 12),
        ],
        if ((_error != null || _memoryError != null || _hasBudgetMismatch) &&
            !_loading &&
            !_memoryLoading)
          TextButton(
            key: const ValueKey('gem-model-ranges-retry'),
            onPressed: () => unawaited(_refreshAll()),
            child: const Text('Retry ranges'),
          ),
      ],
    );
  }
}

class _ModelSaveRequest {
  const _ModelSaveRequest({
    required this.revision,
    required this.modelCode,
    required this.worldId,
    required this.save,
    required this.cacheWriter,
  });

  final int revision;
  final String modelCode;
  final String worldId;
  final Future<GemModelSelection> Function() save;
  final SelectedModelCodeCacheWriter? cacheWriter;
}

class _MemorySaveRequest {
  const _MemorySaveRequest({
    required this.revision,
    required this.memoryTokens,
    required this.worldId,
    required this.save,
    required this.loadGlobal,
    required this.pageCache,
  });

  final int revision;
  final int memoryTokens;
  final String worldId;
  final Future<UserMemorySettings> Function() save;
  final Future<UserMemorySettings> Function() loadGlobal;
  final MemoryModelPageCache? pageCache;
}

class _MemorySettingsLoadingSkeleton extends StatelessWidget {
  const _MemorySettingsLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MemoryModelLoadingBone(width: 72, height: 38),
        SizedBox(height: 8),
        _MemoryModelLoadingBone(width: 168, height: 14),
        SizedBox(height: 30),
        Align(
          alignment: Alignment.centerLeft,
          child: _MemoryModelLoadingBone(width: 144, height: 22),
        ),
        SizedBox(height: 10),
        _MemoryModelLoadingBone(
          height: 93,
          borderRadius: GenesisInfoCard.radius,
        ),
      ],
    );
  }
}

class _ModelCatalogLoadingSkeleton extends StatelessWidget {
  const _ModelCatalogLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MemoryModelLoadingBone(
          height: 126,
          borderRadius: GenesisInfoCard.radius,
        ),
        SizedBox(height: 12),
        _MemoryModelLoadingBone(
          height: 126,
          borderRadius: GenesisInfoCard.radius,
        ),
        SizedBox(height: 12),
        _MemoryModelLoadingBone(
          height: 126,
          borderRadius: GenesisInfoCard.radius,
        ),
      ],
    );
  }
}

class _MemoryModelLoadingBone extends StatelessWidget {
  const _MemoryModelLoadingBone({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 4,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GenesisColors.darkFaintFill,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SizedBox(width: width ?? double.infinity, height: height),
    );
  }
}

class _CurrentMemorySummary extends StatelessWidget {
  const _CurrentMemorySummary({required this.memoryUsedTokens});

  final int memoryUsedTokens;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          formatMemoryTokens(memoryUsedTokens),
          key: const ValueKey('memory-model-current-usage'),
          style: const TextStyle(
            fontSize: 32,
            height: 38 / 32,
            fontWeight: FontWeight.w700,
            color: GenesisColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your current memory usage',
          style: GenesisTypography.supporting.copyWith(
            color: GenesisColors.darkTextTertiary,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        color: GenesisColors.darkTextPrimary,
      ),
    );
  }
}

class _MaxMemoryLimitCard extends StatelessWidget {
  const _MaxMemoryLimitCard({
    required this.memoryTokens,
    required this.minMemoryTokens,
    required this.maxMemoryTokens,
    required this.enabled,
    required this.onChanged,
  });

  final int memoryTokens;
  final int minMemoryTokens;
  final int maxMemoryTokens;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final sliderValue = memorySliderValueForTokens(
      memoryTokens,
      minMemoryTokens: minMemoryTokens,
      maxMemoryTokens: maxMemoryTokens,
    );
    return GenesisInfoCard(
      key: const ValueKey('memory-model-max-memory-card'),
      // Preserve the previous Container's padding plus its 1px border inset.
      padding: const EdgeInsets.fromLTRB(15, 11, 15, 12),
      child: Column(
        children: [
          SizedBox(
            height: 58,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const bubbleWidth = 44.0;
                // Slider's explicit padding and the bubble share one track
                // inset. The 24px press overlay must not change this geometry.
                const trackInset = 24.0;
                const sliderOverflow = 20.0;
                final sliderWidth = constraints.maxWidth + sliderOverflow * 2;
                final visualValue =
                    Directionality.of(context) == TextDirection.rtl
                    ? 1 - sliderValue
                    : sliderValue;
                final thumbCenter =
                    -sliderOverflow +
                    trackInset +
                    visualValue * (sliderWidth - trackInset * 2);
                final bubbleLeft = thumbCenter - bubbleWidth / 2;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: bubbleLeft,
                      top: 0,
                      child: _MemoryValueBubble(
                        value: formatMemoryTokens(memoryTokens),
                        pointerCenterX: thumbCenter - bubbleLeft,
                      ),
                    ),
                    Positioned(
                      left: -sliderOverflow,
                      right: -sliderOverflow,
                      top: 10,
                      height: 48,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          trackShape: const RoundedRectSliderTrackShape(),
                          activeTrackColor: GenesisColors.redPrimary,
                          inactiveTrackColor: GenesisColors.darkFaintFill,
                          disabledActiveTrackColor: GenesisColors.redPrimary,
                          disabledInactiveTrackColor:
                              GenesisColors.darkFaintFill,
                          thumbColor: GenesisColors.darkTextPrimary,
                          disabledThumbColor: GenesisColors.darkTextTertiary,
                          overlayColor: GenesisColors.redPrimary.withValues(
                            alpha: 0.16,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: trackInset,
                          ),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10,
                            disabledThumbRadius: 10,
                            elevation: 2,
                            pressedElevation: 2,
                          ),
                        ),
                        child: Slider(
                          key: const ValueKey('memory-model-max-memory-slider'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: trackInset,
                          ),
                          value: sliderValue,
                          onChanged:
                              enabled && minMemoryTokens < maxMemoryTokens
                              ? (value) => onChanged(
                                  memoryTokensForSliderValue(
                                    value,
                                    minMemoryTokens: minMemoryTokens,
                                    maxMemoryTokens: maxMemoryTokens,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatMemoryTokens(minMemoryTokens),
                key: const ValueKey('memory-model-min-memory'),
                style: GenesisTypography.supporting.copyWith(
                  color: GenesisColors.darkTextSecondary,
                ),
              ),
              Text(
                formatMemoryTokens(maxMemoryTokens),
                key: const ValueKey('memory-model-max-memory'),
                style: GenesisTypography.supporting.copyWith(
                  color: GenesisColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoryValueBubble extends StatelessWidget {
  const _MemoryValueBubble({required this.value, required this.pointerCenterX});

  final String value;
  final double pointerCenterX;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      value: value,
      child: SizedBox(
        width: 44,
        height: 22,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              key: const ValueKey('memory-model-max-memory-value'),
              width: 44,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GenesisColors.darkTextPrimary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 10,
                  height: 12 / 10,
                  fontWeight: FontWeight.w600,
                  color: GenesisColors.textPrimary,
                ),
              ),
            ),
            Positioned(
              left: pointerCenterX - 4,
              top: 18,
              child: const CustomPaint(
                key: ValueKey('memory-model-max-memory-pointer'),
                size: Size(8, 4),
                painter: _MemoryBubblePointerPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryBubblePointerPainter extends CustomPainter {
  const _MemoryBubblePointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = GenesisColors.darkTextPrimary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GemModelTile extends StatelessWidget {
  const _GemModelTile({
    required this.model,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.memorySettings,
    required this.quoteAvailable,
  });

  final UserMemorySettings? memorySettings;
  final bool quoteAvailable;
  final GemModel model;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: GenesisInfoCard(
        key: ValueKey<String>('gem-model-${model.modelCode}'),
        selected: selected,
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _GemModelTileContent(
                model: model,
                memorySettings: memorySettings,
                quoteAvailable: quoteAvailable,
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _GemModelSelectionIndicator(selected: selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _GemModelTileContent extends StatelessWidget {
  const _GemModelTileContent({
    required this.model,
    required this.memorySettings,
    required this.quoteAvailable,
  });

  final UserMemorySettings? memorySettings;
  final bool quoteAvailable;

  final GemModel model;

  @override
  Widget build(BuildContext context) {
    final min = formatGemCent(model.minGemsCent);
    final max = formatGemCent(model.maxGemsCent);
    final priceRange = min == max ? '$min gems' : '$min–$max gems';
    final memory = memorySettings;
    final memoryStart = memory == null
        ? null
        : formatMemoryTokens(memory.memoryUsedTokens!);
    final memoryEnd = memory == null
        ? null
        : formatMemoryTokens(memory.memoryTokens);
    final memoryRange = memory == null
        ? null
        : memoryStart == memoryEnd
        ? 'memory $memoryStart'
        : 'memory $memoryStart → $memoryEnd';
    final rangeStyle = GenesisTypography.supporting.copyWith(
      color: GenesisColors.darkTextTertiary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                model.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 20 / 16,
                  fontWeight: FontWeight.w600,
                  color: GenesisColors.darkTextPrimary,
                ),
              ),
            ),
            for (final tag in model.tags) ...[
              const SizedBox(width: 7),
              _GemModelTag(label: tag),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (!quoteAvailable)
          _MemoryModelLoadingBone(
            key: ValueKey('gem-model-estimate-loading-${model.modelCode}'),
            width: 200,
            height: 16,
          )
        else
          Text.rich(
            TextSpan(
              text: 'Estimated next message ',
              children: [
                TextSpan(
                  text:
                      '${formatGemCent(model.estimatedNextMessageGemsCent)} gems',
                  style: const TextStyle(color: GenesisColors.redSecondary),
                ),
              ],
            ),
            key: ValueKey<String>('gem-model-estimate-${model.modelCode}'),
            style: GenesisTypography.supporting.copyWith(
              color: GenesisColors.darkTextTertiary,
            ),
          ),
        const SizedBox(height: 7),
        Text(
          model.description,
          style: GenesisTypography.body.copyWith(
            color: GenesisColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 8),
        if (quoteAvailable && memoryRange != null)
          Text(
            '$priceRange ($memoryRange)',
            key: ValueKey<String>('gem-model-range-${model.modelCode}'),
            style: rangeStyle,
          )
        else ...[
          if (quoteAvailable)
            Text(priceRange, style: rangeStyle)
          else
            _MemoryModelLoadingBone(
              key: ValueKey('gem-model-price-loading-${model.modelCode}'),
              width: 120,
              height: 14,
            ),
          const SizedBox(height: 4),
          if (memoryRange != null)
            Text(
              memoryRange,
              key: ValueKey('gem-model-memory-range-${model.modelCode}'),
              style: rangeStyle,
            )
          else
            _MemoryModelLoadingBone(
              key: ValueKey('gem-model-memory-loading-${model.modelCode}'),
              width: 180,
              height: 14,
            ),
        ],
      ],
    );
  }
}

class _GemModelTag extends StatelessWidget {
  const _GemModelTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalizedLabel = label.trim().toLowerCase();
    final displayLabel = normalizedLabel.isEmpty
        ? ''
        : '${normalizedLabel[0].toUpperCase()}${normalizedLabel.substring(1)}';
    final outlined = normalizedLabel == 'hot';
    return Container(
      key: ValueKey<String>('gem-model-tag-$normalizedLabel'),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : GenesisColors.redPrimary,
        border: outlined
            ? Border.all(color: GenesisColors.redSecondary, width: 1)
            : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          fontSize: 10,
          height: 13 / 10,
          fontWeight: FontWeight.w600,
          color: outlined
              ? GenesisColors.redSecondary
              : GenesisColors.darkTextPrimary,
        ),
      ),
    );
  }
}

class _GemModelSelectionIndicator extends StatelessWidget {
  const _GemModelSelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? GenesisColors.redPrimary
              : GenesisColors.darkTextTertiary,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? const SizedBox.square(
              dimension: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GenesisColors.redPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _ModelLoadError extends StatelessWidget {
  const _ModelLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Load failed',
              style: TextStyle(
                fontSize: 14,
                color: GenesisColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: 14),
            GenesisPrimaryButton(
              onPressed: onRetry,
              label: 'Retry',
              fullWidth: false,
              width: 96,
            ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
double memorySliderValueForTokens(
  int memoryTokens, {
  required int minMemoryTokens,
  required int maxMemoryTokens,
}) {
  if (minMemoryTokens <= 0 || maxMemoryTokens <= minMemoryTokens) return 0;
  final normalized = memoryTokens.clamp(minMemoryTokens, maxMemoryTokens);
  return math.log(normalized / minMemoryTokens) /
      math.log(maxMemoryTokens / minMemoryTokens);
}

@visibleForTesting
int memoryTokensForSliderValue(
  double value, {
  required int minMemoryTokens,
  required int maxMemoryTokens,
}) {
  if (minMemoryTokens <= 0 || maxMemoryTokens <= minMemoryTokens) {
    return minMemoryTokens;
  }
  final normalized = value.clamp(0.0, 1.0);
  if (normalized <= 0) return minMemoryTokens;
  if (normalized >= 1) return maxMemoryTokens;
  final memoryTokens =
      minMemoryTokens * math.pow(maxMemoryTokens / minMemoryTokens, normalized);
  final roundedToOneK = (memoryTokens / 1000).round() * 1000;
  return roundedToOneK.clamp(minMemoryTokens, maxMemoryTokens);
}

@visibleForTesting
String formatMemoryTokens(int memoryTokens) {
  if (memoryTokens == 0) return '0';
  // Round usage up to a whole K, including nonzero usage below 1K.
  final wholeK = (memoryTokens / 1000).ceil();
  return wholeK == 1000 ? '1M' : '${wholeK}K';
}

bool _isUncertainMemorySave(Object error) {
  if (error is TimeoutException) return true;
  return error is ApiException &&
      (error.code == 5000 ||
          error.kind == ApiExceptionKind.timeout ||
          error.kind == ApiExceptionKind.transport ||
          error.retryable);
}

class _MemoryLoadError extends StatelessWidget {
  const _MemoryLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('memory-settings-load-error'),
      height: 190,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Memory settings unavailable',
              style: TextStyle(
                fontSize: 14,
                color: GenesisColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: 14),
            GenesisPrimaryButton(
              key: const ValueKey('memory-settings-retry'),
              onPressed: onRetry,
              label: 'Retry',
              fullWidth: false,
              width: 96,
            ),
          ],
        ),
      ),
    );
  }
}
