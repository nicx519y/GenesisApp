import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/bootstrap/app_services_scope.dart';
import '../../app/telemetry/genesis_telemetry.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/gems/gem_colors.dart';
import '../../network/models/gem_model.dart';
import '../../ui/components/genesis_state_view.dart';
import '../../ui/system/genesis_system_ui.dart';
import '../../ui/theme/genesis_semantic_colors.dart';
import '../../ui/tokens/genesis_typography.dart';

typedef GemModelCatalogLoader =
    Future<GemModelCatalog> Function(String worldId);
typedef GemModelSelectionHandler =
    Future<GemModelSelection> Function(String worldId, String modelCode);
typedef SelectedModelCodeCacheWriter = Future<void> Function(String modelCode);

class MemoryModelPage extends StatefulWidget {
  const MemoryModelPage({
    super.key,
    required this.worldId,
    this.catalogLoader,
    this.selectionHandler,
    this.selectedModelCodeCacheWriter,
  });

  final String worldId;
  final GemModelCatalogLoader? catalogLoader;
  final GemModelSelectionHandler? selectionHandler;
  final SelectedModelCodeCacheWriter? selectedModelCodeCacheWriter;

  @override
  State<MemoryModelPage> createState() => _MemoryModelPageState();
}

class _MemoryModelPageState extends State<MemoryModelPage> {
  GemModelCatalog? _catalog;
  Object? _error;
  bool _loading = false;
  bool _saving = false;
  String _pendingModelCode = '';
  int _loadGeneration = 0;
  String _trackedPageWorldId = '';

  @override
  void initState() {
    super.initState();
    _trackSwitchModelPage();
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant MemoryModelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldId != widget.worldId) {
      _trackSwitchModelPage();
      unawaited(_refresh());
    }
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

  Future<GemModelCatalog> _loadCatalog() {
    final loader = widget.catalogLoader;
    if (loader != null) return loader(widget.worldId);
    return AppServicesScope.read(
      context,
    ).api.v1.gem.models(worldId: widget.worldId);
  }

  Future<GemModelSelection> _saveSelection(String modelCode) {
    final handler = widget.selectionHandler;
    if (handler != null) return handler(widget.worldId, modelCode);
    return AppServicesScope.read(
      context,
    ).api.v1.gem.selectModel(worldId: widget.worldId, modelCode: modelCode);
  }

  SelectedModelCodeCacheWriter? _resolveSelectedModelCodeCacheWriter() {
    final writer = widget.selectedModelCodeCacheWriter;
    if (writer != null) return writer;
    if (widget.selectionHandler != null) return null;
    final sessionStore = AppServicesScope.read(context).sessionStore;
    return (modelCode) async {
      final current = await sessionStore.readUserInfo();
      await sessionStore.saveUserInfo({
        if (current != null) ...current,
        'selected_model_code': modelCode,
      });
    };
  }

  Future<void> _refresh({bool preserveContent = false}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
      if (!preserveContent) _catalog = null;
    });
    try {
      final catalog = await _loadCatalog();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _catalog = catalog;
        _pendingModelCode = catalog.selectedModelCode;
        _loading = false;
      });
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
    if (modelCode.isEmpty || _saving || modelCode == _pendingModelCode) return;
    setState(() => _pendingModelCode = modelCode);
  }

  Future<void> _submitSelection() async {
    final modelCode = _pendingModelCode.trim();
    if (modelCode.isEmpty || _saving) return;
    final worldId = widget.worldId.trim();
    if (worldId.isNotEmpty) {
      GenesisTelemetry.collectLog(
        actionType: 'pay_event',
        action: 'switch_model_save',
        object1: worldId,
        object2: modelCode,
      );
    }
    final cacheWriter = _resolveSelectedModelCodeCacheWriter();
    setState(() => _saving = true);
    try {
      final result = await _saveSelection(modelCode);
      final responseModelCode = result.selectedModelCode.trim();
      final selectedModelCode = responseModelCode.isEmpty
          ? modelCode
          : responseModelCode;
      try {
        await cacheWriter?.call(selectedModelCode);
      } catch (error) {
        debugPrint('[GemModel] cache selected model failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _catalog = _catalog?.copyWith(selectedModelCode: selectedModelCode);
        _pendingModelCode = selectedModelCode;
      });
      showGenesisToast(context, 'Switched successfully');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pendingModelCode = _catalog?.selectedModelCode ?? '';
      });
      showGenesisToast(context, 'Switched failed');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _closePage() {
    Navigator.of(context).pop(_catalog?.selectedModelCode ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: GenesisSystemUi.forThemeBrightness(Theme.of(context).brightness),
      child: Scaffold(
        backgroundColor: context.genesisColors.pageBackground,
        body: Column(
          children: [
            _MemoryModelHeader(
              onBack: _closePage,
              saving: _saving,
              saveEnabled:
                  !_loading &&
                  _pendingModelCode.trim().isNotEmpty &&
                  _pendingModelCode.trim() !=
                      (_catalog?.selectedModelCode.trim() ?? ''),
              onSave: _submitSelection,
            ),
            Expanded(child: SafeArea(top: false, child: _buildBody())),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final catalog = _catalog;
    if (catalog == null && _loading) {
      return Center(
        child: GenesisLoadingIndicator(
          indicatorKey: const ValueKey('gem-model-page-loading'),
          color: context.genesisGemColors.accent,
        ),
      );
    }
    if (catalog == null && _error != null) {
      return GenesisStateView.error(
        message: 'Load failed',
        actionSpacing: 14,
        textStyle: TextStyle(
          fontSize: 14,
          color: context.genesisColors.textSubtle,
        ),
        onAction: () => unawaited(_refresh()),
      );
    }
    if (catalog == null || catalog.groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refresh(preserveContent: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            Center(
              child: Text(
                'No models available',
                style: TextStyle(
                  fontSize: 14,
                  color: context.genesisColors.textPlaceholder,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(preserveContent: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: catalog.groups.length,
        itemBuilder: (context, index) {
          final group = catalog.groups[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == catalog.groups.length - 1 ? 0 : 24,
            ),
            child: _GemModelGroupSection(
              group: group,
              selectedModelCode: _pendingModelCode,
              currentModelCode: catalog.selectedModelCode,
              enabled: !_saving,
              onModelTap: _selectModel,
            ),
          );
        },
      ),
    );
  }
}

class _MemoryModelHeader extends StatelessWidget {
  const _MemoryModelHeader({
    required this.onBack,
    required this.saving,
    required this.saveEnabled,
    required this.onSave,
  });

  final VoidCallback onBack;
  final bool saving;
  final bool saveEnabled;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.genesisColors;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: SizedBox(
          height: 34,
          child: Row(
            children: [
              Material(
                key: const ValueKey('gem-model-back'),
                color: colors.textPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onBack,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStatePropertyAll<Color>(
                    colors.textPrimary.withValues(alpha: 0.08),
                  ),
                  child: SizedBox.square(
                    dimension: 34,
                    child: Center(
                      child: CustomPaint(
                        key: const ValueKey('gem-model-back-chevron'),
                        size: const Size(8, 14),
                        painter: _ModelBackChevronPainter(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Model',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GenesisTypography.navigationTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              _ModelSaveAction(
                saving: saving,
                enabled: saveEnabled,
                onPressed: onSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelBackChevronPainter extends CustomPainter {
  const _ModelBackChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width - 0.8, 0.8)
      ..lineTo(0.8, size.height / 2)
      ..lineTo(size.width - 0.8, size.height - 0.8);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ModelBackChevronPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ModelSaveAction extends StatelessWidget {
  const _ModelSaveAction({
    required this.saving,
    required this.enabled,
    required this.onPressed,
  });

  final bool saving;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('gem-model-save'),
      onPressed: enabled && !saving ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 28),
        maximumSize: const Size(double.infinity, 28),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: context.genesisGemColors.accent,
        disabledBackgroundColor: context.genesisGemColors.accent,
        overlayColor: context.genesisColors.textPrimary.withValues(alpha: 0.08),
        foregroundColor: context.genesisColors.onPrimary,
        disabledForegroundColor: context.genesisColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: saving
          ? SizedBox.square(
              key: ValueKey('gem-model-save-loading'),
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.genesisColors.onPrimary,
              ),
            )
          : const Text('Save'),
    );
  }
}

class _GemModelGroupSection extends StatelessWidget {
  const _GemModelGroupSection({
    required this.group,
    required this.selectedModelCode,
    required this.currentModelCode,
    required this.enabled,
    required this.onModelTap,
  });

  final GemModelGroup group;
  final String selectedModelCode;
  final String currentModelCode;
  final bool enabled;
  final ValueChanged<GemModel> onModelTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.groupTitle,
          style: TextStyle(
            fontSize: 9.5,
            height: 12 / 9.5,
            fontWeight: FontWeight.w500,
            color: context.genesisColors.textTertiary,
          ),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < group.models.length; index += 1) ...[
          _GemModelTile(
            model: group.models[index],
            selected: group.models[index].modelCode == selectedModelCode,
            isCurrentModel:
                group.models[index].modelCode == currentModelCode.trim(),
            enabled: enabled,
            onTap: () => onModelTap(group.models[index]),
          ),
          if (index != group.models.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GemModelTile extends StatelessWidget {
  const _GemModelTile({
    required this.model,
    required this.selected,
    required this.isCurrentModel,
    required this.enabled,
    required this.onTap,
  });

  final GemModel model;
  final bool selected;
  final bool isCurrentModel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? context.genesisGemColors.accent
        : context.genesisColors.textPrimary.withValues(alpha: 0.14);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        key: ValueKey<String>('gem-model-${model.modelCode}'),
        color: selected
            ? context.genesisGemColors.accent.withValues(alpha: 0.10)
            : context.genesisColors.surfaceSubtle,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStatePropertyAll<Color>(
            context.genesisColors.textPrimary.withValues(alpha: 0),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _GemModelTileContent(
                    model: model,
                    isCurrentModel: isCurrentModel,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: _GemModelSelectionIndicator(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GemModelTileContent extends StatelessWidget {
  const _GemModelTileContent({
    required this.model,
    required this.isCurrentModel,
  });

  final GemModel model;
  final bool isCurrentModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isCurrentModel) ...[
              Container(
                key: ValueKey<String>('gem-model-current-${model.modelCode}'),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: context.genesisGemColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                model.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GenesisTypography.itemTitle.copyWith(
                  color: context.genesisColors.textPrimary,
                ),
              ),
            ),
            for (final tag in model.tags) ...[
              const SizedBox(width: 8),
              _GemModelTag(label: tag),
            ],
          ],
        ),
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: 'Estimated next message: ',
              children: [
                TextSpan(
                  text: '${model.estimatedNextMessageGems} gems',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: context.genesisGemColors.reward,
                  ),
                ),
              ],
            ),
            key: ValueKey<String>('gem-model-estimate-${model.modelCode}'),
            style: TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w400,
              color: context.genesisColors.textSubtle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          model.description,
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: context.genesisColors.textPrimary.withValues(alpha: 0.62),
          ),
        ),
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
    final hot = normalizedLabel == 'hot';
    return Container(
      key: ValueKey<String>('gem-model-tag-$normalizedLabel'),
      height: 19,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hot
            ? context.genesisColors.textPrimary.withValues(alpha: 0)
            : context.genesisGemColors.accent,
        border: hot ? Border.all(color: context.genesisGemColors.reward) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          color: hot
              ? context.genesisGemColors.reward
              : context.genesisColors.onPrimary,
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
              ? context.genesisGemColors.accent
              : context.genesisGemColors.selectionDisabled,
          width: selected ? 2 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: context.genesisGemColors.accent,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 9),
            )
          : null,
    );
  }
}
