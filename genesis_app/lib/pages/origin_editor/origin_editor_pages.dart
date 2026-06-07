import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_bottom_sheet_panel.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/origin/origin_character_form.dart';
import '../../components/page_header.dart';
import '../../network/api_exception.dart';
import '../../ui/genesis_ui.dart';
import '../create/create_form_widgets.dart';
import '../create/create_origin_draft_store.dart';
import '../create/create_origin_id_utils.dart';
import 'origin_draft_repository.dart';

part 'origin_basics_editor_page.dart';
part 'origin_characters_editor_page.dart';
part 'origin_locations_editor_page.dart';
part 'origin_story_events_editor_page.dart';

bool _characterDraftHasContent(CharacterDraft item) {
  return item.avatarUrl.trim().isNotEmpty ||
      item.name.trim().isNotEmpty ||
      item.identity.trim().isNotEmpty ||
      item.personality.trim().isNotEmpty ||
      item.bio.trim().isNotEmpty ||
      item.goal.trim().isNotEmpty;
}

bool _locationDraftHasContent(LocationDraft item) {
  return item.imageUrl.trim().isNotEmpty ||
      item.name.trim().isNotEmpty ||
      item.description.trim().isNotEmpty ||
      item.parentLocationId.trim().isNotEmpty ||
      item.initialCharacterIds.isNotEmpty;
}

class OriginSubmitResult {
  const OriginSubmitResult({required this.message, this.draft});

  final String message;
  final CreateOriginDraft? draft;
}

typedef OriginSubmitHandler =
    Future<OriginSubmitResult> Function(
      BuildContext context,
      OriginDraftRepository repository,
      CreateOriginDraft draft,
    );

enum _DraftLeaveAction { submit, save, discard }

class OriginDraftFlowPage extends StatefulWidget {
  const OriginDraftFlowPage({
    super.key,
    required this.title,
    required this.repository,
    required this.basicsPageBuilder,
    required this.charactersPageBuilder,
    required this.locationsPageBuilder,
    required this.storyEventsPageBuilder,
    required this.onSubmit,
    this.submitLabel = 'Save',
    this.submittingLabel = 'Saving...',
    this.failurePrefix = 'Save failed',
    this.leaveTitle = 'Save the draft before leaving?',
    this.leaveSubmitLabel,
    this.submitUnavailableMessage = 'No changes to save.',
    this.canSubmit,
    this.popOnSubmitSuccess = false,
    this.confirmLeaveWithDraftOptions = false,
    this.onDiscardDraft,
  });

  final String title;
  final OriginDraftRepository repository;
  final Widget Function(OriginDraftRepository repository) basicsPageBuilder;
  final Widget Function(OriginDraftRepository repository) charactersPageBuilder;
  final Widget Function(OriginDraftRepository repository) locationsPageBuilder;
  final Widget Function(OriginDraftRepository repository)
  storyEventsPageBuilder;
  final OriginSubmitHandler onSubmit;
  final String submitLabel;
  final String submittingLabel;
  final String failurePrefix;
  final String leaveTitle;
  final String? leaveSubmitLabel;
  final String submitUnavailableMessage;
  final bool Function(CreateOriginDraft draft)? canSubmit;
  final bool popOnSubmitSuccess;
  final bool confirmLeaveWithDraftOptions;
  final Future<void> Function(OriginDraftRepository repository)? onDiscardDraft;

  @override
  State<OriginDraftFlowPage> createState() => _OriginDraftFlowPageState();
}

class _OriginDraftFlowPageState extends State<OriginDraftFlowPage> {
  CreateOriginDraft _draft = CreateOriginDraft.empty();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isHandlingLeave = false;

  @override
  void initState() {
    super.initState();
    _reloadDraft();
  }

  Future<void> _reloadDraft() async {
    final draft = await widget.repository.loadSummaryDraft();
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _isLoading = false;
    });
  }

  Future<void> _openSection(Widget page) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute<bool>(builder: (_) => page));
    if (changed == true) {
      await _reloadDraft();
    }
  }

  Future<bool> _submit() async {
    final latest = await widget.repository.loadSummaryDraft();
    if (!mounted) return false;
    final errors = latest.validateForSubmit();
    if (errors.isNotEmpty) {
      _showError(errors.first);
      setState(() => _draft = latest);
      return false;
    }
    if (!(widget.canSubmit?.call(latest) ?? true)) {
      _showError(widget.submitUnavailableMessage);
      setState(() => _draft = latest);
      return false;
    }

    setState(() {
      _isSubmitting = true;
      _draft = latest;
    });

    try {
      final result = await widget.onSubmit(context, widget.repository, latest);
      if (!mounted) return false;
      showGenesisToast(context, result.message);
      if (result.draft != null) {
        setState(() {
          _draft = result.draft!;
          _isSubmitting = false;
        });
      } else {
        setState(() => _isSubmitting = false);
        await _reloadDraft();
      }
      if (widget.popOnSubmitSuccess && mounted) {
        Navigator.of(context).maybePop();
      }
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      setState(() => _isSubmitting = false);
      _showError(e.message);
      return false;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _isSubmitting = false);
      _showError('${widget.failurePrefix}: $e');
      return false;
    }
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  Future<void> _handleLeaveRequest() async {
    if (_isHandlingLeave) return;
    _isHandlingLeave = true;
    try {
      final latest = await widget.repository.loadSummaryDraft();
      if (!mounted) return;
      if (!widget.confirmLeaveWithDraftOptions ||
          !_shouldConfirmLeave(latest)) {
        Navigator.of(context).pop();
        return;
      }

      final action = await showGenesisActionBox<_DraftLeaveAction>(
        context: context,
        title: widget.leaveTitle,
        actions: [
          GenesisActionBoxAction<_DraftLeaveAction>(
            label: widget.leaveSubmitLabel ?? 'Save',
            value: widget.leaveSubmitLabel == null
                ? _DraftLeaveAction.save
                : _DraftLeaveAction.submit,
          ),
          const GenesisActionBoxAction<_DraftLeaveAction>(
            label: 'Discard',
            value: _DraftLeaveAction.discard,
            color: createFormText,
          ),
        ],
      );
      if (!mounted || action == null) return;
      if (action == _DraftLeaveAction.save) {
        await widget.repository.saveFinalDraft(latest);
      } else if (action == _DraftLeaveAction.submit) {
        final submitted = await _submit();
        if (!submitted || !mounted) return;
      } else {
        await widget.onDiscardDraft?.call(widget.repository);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      _isHandlingLeave = false;
    }
  }

  bool _shouldConfirmLeave(CreateOriginDraft draft) {
    if (widget.leaveSubmitLabel != null) {
      return widget.repository.hasSubmitChanges(draft);
    }
    return _hasDraftContent(draft);
  }

  bool _hasDraftContent(CreateOriginDraft draft) {
    return draft.basicsSaved ||
        draft.charactersSaved ||
        draft.locationsSaved ||
        draft.storyEventsSaved ||
        draft.basics.originName.trim().isNotEmpty ||
        draft.basics.worldView.trim().isNotEmpty ||
        draft.basics.worldLogic.trim().isNotEmpty ||
        draft.basics.metricJson.trim().isNotEmpty ||
        draft.basics.coverImageUrl.trim().isNotEmpty ||
        draft.characters.any(_characterHasContent) ||
        draft.locations.any(_locationHasContent) ||
        draft.storyEvents.any((item) => item.event.trim().isNotEmpty);
  }

  bool _characterHasContent(CharacterDraft item) {
    return item.charId.trim().isNotEmpty ||
        item.avatarUrl.trim().isNotEmpty ||
        item.name.trim().isNotEmpty ||
        item.identity.trim().isNotEmpty ||
        item.personality.trim().isNotEmpty ||
        item.bio.trim().isNotEmpty ||
        item.goal.trim().isNotEmpty;
  }

  bool _locationHasContent(LocationDraft item) {
    return item.locationId.trim().isNotEmpty ||
        item.parentLocationId.trim().isNotEmpty ||
        item.imageUrl.trim().isNotEmpty ||
        item.name.trim().isNotEmpty ||
        item.description.trim().isNotEmpty ||
        item.initialCharacterIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final submitReady =
        !_isSubmitting &&
        _draft.validateForSubmit().isEmpty &&
        (widget.canSubmit?.call(_draft) ?? true);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleLeaveRequest());
      },
      child: Scaffold(
        appBar: GenesisBackAppBar(
          pageName: widget.title,
          onBack: () => unawaited(_handleLeaveRequest()),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 14),
                Expanded(
                  child: ListView(
                    children: [
                      _SectionRow(
                        icon: '🌐',
                        title: 'Basics',
                        summary: _basicsSummary(_draft),
                        completed: _draft.basicsSaved,
                        onTap: () => _openSection(
                          widget.basicsPageBuilder(widget.repository),
                        ),
                      ),
                      _SectionRow(
                        icon: '👤',
                        title: 'Characters',
                        summary: _charactersSummary(_draft),
                        completed: _draft.charactersSaved,
                        onTap: () => _openSection(
                          widget.charactersPageBuilder(widget.repository),
                        ),
                      ),
                      _SectionRow(
                        icon: '📍',
                        title: 'Locations',
                        summary: _locationsSummary(_draft),
                        completed: _draft.locationsSaved,
                        onTap: () => _openSection(
                          widget.locationsPageBuilder(widget.repository),
                        ),
                      ),
                      _SectionRow(
                        icon: '📜',
                        title: 'Story Events (Optional)',
                        summary: _storyEventsSummary(_draft),
                        completed: _draft.storyEventsSaved,
                        showDivider: false,
                        onTap: () => _openSection(
                          widget.storyEventsPageBuilder(widget.repository),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: GenesisPrimaryButton(
            label: _isSubmitting ? widget.submittingLabel : widget.submitLabel,
            onPressed: _isSubmitting ? null : () => unawaited(_submit()),
            backgroundColor: submitReady
                ? const Color(0xFF198B64)
                : const Color(0xFFBFD8CD),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFBFD8CD),
            disabledForegroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  String _basicsSummary(CreateOriginDraft draft) {
    if (!draft.basicsSaved) return 'Not started yet';
    final basics = draft.basics;
    return [
      'World Name: ${_summaryValue(basics.originName)}',
      'World View: ${_summaryValue(basics.worldView)}',
      'Cover Image: ${basics.coverImageUrl.trim().isEmpty ? 'Not uploaded' : 'Uploaded'}',
    ].join('\n');
  }

  String _charactersSummary(CreateOriginDraft draft) {
    if (!draft.charactersSaved) return 'Not started yet';
    final characters = draft.characters
        .where(_characterDraftHasContent)
        .toList(growable: false);
    if (characters.isEmpty) return '0 characters';
    return characters
        .take(3)
        .map((item) {
          final title = _summaryValue(item.name, maxLength: 18);
          final detail = [
            item.identity.trim(),
            item.personality.trim(),
          ].where((value) => value.isNotEmpty).join(' / ');
          if (detail.isEmpty) return title;
          return '$title: ${_summaryValue(detail, maxLength: 34)}';
        })
        .join('\n');
  }

  String _locationsSummary(CreateOriginDraft draft) {
    if (!draft.locationsSaved) return 'Not started yet';
    final locations = draft.locations
        .where(_locationDraftHasContent)
        .toList(growable: false);
    if (locations.isEmpty) return '0 locations';
    return locations
        .take(3)
        .map((item) {
          final title = _summaryValue(item.name, maxLength: 20);
          final description = item.description.trim();
          if (description.isEmpty) return title;
          return '$title: ${_summaryValue(description, maxLength: 34)}';
        })
        .join('\n');
  }

  String _storyEventsSummary(CreateOriginDraft draft) {
    if (!draft.storyEventsSaved) return 'Not started yet';
    final count = draft.storyEvents
        .map((item) => item.event.trim())
        .where((item) => item.isNotEmpty)
        .length;
    return '$count Events';
  }

  String _summaryValue(String value, {int maxLength = 48}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }
}
