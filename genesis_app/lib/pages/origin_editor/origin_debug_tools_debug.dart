import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../components/common/genesis_center_toast.dart';
import '../create/create_origin_draft_store.dart';
import 'origin_debug_draft_factory.dart';
import 'origin_draft_repository.dart';

typedef OriginDebugDraftGenerator =
    FutureOr<CreateOriginDraft> Function(CreateOriginDraft currentDraft);

OriginDebugDraftGenerator? createOriginDebugDraftGenerator() {
  return kDebugMode ? generateRandomCreateOriginDraft : null;
}

OriginDebugDraftGenerator? editOriginDebugDraftGenerator(
  TextEditingController updateNotesController,
) {
  if (!kDebugMode) return null;
  return (currentDraft) {
    updateNotesController.text = 'Generated random test content in debug mode.';
    return generateRandomEditOriginDraft(currentDraft);
  };
}

Widget? buildOriginDebugRandomContentButton({
  required OriginDraftRepository repository,
  required OriginDebugDraftGenerator? generator,
  required bool enabled,
  required Future<void> Function() onGenerated,
}) {
  if (!kDebugMode || generator == null) return null;
  return Padding(
    padding: const EdgeInsets.only(bottom: 64),
    child: _OriginDebugRandomContentButton(
      repository: repository,
      generator: generator,
      enabled: enabled,
      onGenerated: onGenerated,
    ),
  );
}

class _OriginDebugRandomContentButton extends StatefulWidget {
  const _OriginDebugRandomContentButton({
    required this.repository,
    required this.generator,
    required this.enabled,
    required this.onGenerated,
  });

  final OriginDraftRepository repository;
  final OriginDebugDraftGenerator generator;
  final bool enabled;
  final Future<void> Function() onGenerated;

  @override
  State<_OriginDebugRandomContentButton> createState() =>
      _OriginDebugRandomContentButtonState();
}

class _OriginDebugRandomContentButtonState
    extends State<_OriginDebugRandomContentButton> {
  bool _isGenerating = false;

  Future<void> _generate() async {
    if (_isGenerating || !widget.enabled) return;
    setState(() => _isGenerating = true);
    try {
      final current = await widget.repository.loadSummaryDraft();
      final generated = _markChangedDebugSectionsSaved(
        current,
        await widget.generator(current),
      );
      await widget.repository.saveFinalDraft(generated);
      if (!mounted) return;
      await widget.onGenerated();
      if (!mounted) return;
      setState(() => _isGenerating = false);
      showGenesisToast(context, 'Random test content generated.');
    } catch (error, stackTrace) {
      debugPrint('[OriginEditor] debug draft generation failed: $error');
      debugPrint('[OriginEditor] stacktrace:\n$stackTrace');
      if (!mounted) return;
      setState(() => _isGenerating = false);
      showGenesisToast(context, 'Unable to generate random test content.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      key: const ValueKey<String>('origin-debug-random-content-button'),
      heroTag: null,
      onPressed: _isGenerating || !widget.enabled
          ? null
          : () => unawaited(_generate()),
      icon: _isGenerating
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.casino_outlined),
      label: const Text('Random'),
      tooltip: 'Generate random test content',
    );
  }
}

CreateOriginDraft _markChangedDebugSectionsSaved(
  CreateOriginDraft current,
  CreateOriginDraft generated,
) {
  final currentDraft = current.normalized();
  final generatedDraft = generated.normalized();
  bool changed(Object currentValue, Object generatedValue) {
    return jsonEncode(currentValue) != jsonEncode(generatedValue);
  }

  return generatedDraft.copyWith(
    basicsSaved:
        generatedDraft.basicsSaved ||
        changed(currentDraft.basics.toJson(), generatedDraft.basics.toJson()),
    charactersSaved:
        generatedDraft.charactersSaved ||
        changed(
          currentDraft.characters.map((item) => item.toJson()).toList(),
          generatedDraft.characters.map((item) => item.toJson()).toList(),
        ),
    locationsSaved:
        generatedDraft.locationsSaved ||
        changed(
          currentDraft.locations.map((item) => item.toJson()).toList(),
          generatedDraft.locations.map((item) => item.toJson()).toList(),
        ),
    openingSaved:
        generatedDraft.openingSaved ||
        changed(currentDraft.opening.toJson(), generatedDraft.opening.toJson()),
    storyEventsSaved:
        generatedDraft.storyEventsSaved ||
        changed(
          currentDraft.storyEvents.map((item) => item.toJson()).toList(),
          generatedDraft.storyEvents.map((item) => item.toJson()).toList(),
        ),
  );
}
