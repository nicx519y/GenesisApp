import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../components/common/genesis_action_box.dart';
import '../../components/common/genesis_bottom_sheet_panel.dart';
import '../../components/common/genesis_center_toast.dart';
import '../../components/common/genesis_modal_routes.dart';
import '../../components/origin/origin_character_form.dart';
import '../../components/page_header.dart';
import '../../icons/custom_icon_assets.dart';
import '../../network/api_exception.dart';
import '../../ui/genesis_ui.dart';
import '../../ui/tokens/genesis_avatar_radii.dart';
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

const TextStyle _editSummaryLabelStyle = TextStyle(
  color: Colors.black,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  height: 1.2,
);

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
    this.showCurrentVersion = false,
    this.updateNotesController,
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
  final bool showCurrentVersion;
  final TextEditingController? updateNotesController;

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
    if (mounted) {
      _clearInputFocus();
    }
    if (changed == true) {
      await _reloadDraft();
    }
  }

  void _clearInputFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<bool> _submit() async {
    final latest = await widget.repository.loadSummaryDraft();
    if (!mounted) return false;
    final blockReason = _submitBlockReason(latest);
    if (blockReason != null) {
      _showError(blockReason);
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

  String? _submitBlockReason(CreateOriginDraft draft) {
    final errors = draft.validateForSubmit();
    if (errors.isNotEmpty) return errors.first;
    if (!(widget.canSubmit?.call(draft) ?? true)) {
      return widget.submitUnavailableMessage;
    }
    if (widget.updateNotesController != null &&
        widget.updateNotesController!.text.trim().isEmpty) {
      return 'Update notes are required to publish.';
    }
    return null;
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
        item.imageUrl.trim().isNotEmpty ||
        item.name.trim().isNotEmpty ||
        item.description.trim().isNotEmpty ||
        item.initialCharacterIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    const disabledSubmitColor = Color(0xFFBFD8CD);
    final canUseSubmitButton =
        !_isSubmitting && _submitBlockReason(_draft) == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(_handleLeaveRequest());
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: GenesisBackAppBar(
          pageName: widget.title,
          onBack: () => unawaited(_handleLeaveRequest()),
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _clearInputFocus,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 14),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.only(
                              bottom: 10 + keyboardInset,
                            ),
                            children: [
                              if (widget.showCurrentVersion) ...[
                                Text(
                                  'Current Version: ${_versionLabel(_draft.basics.originVersion)}',
                                  style: _editSummaryLabelStyle,
                                ),
                                const SizedBox(height: 20),
                              ],
                              _SectionRow(
                                icon: createOriginBasicsIconAsset,
                                title: 'Basics',
                                summary: _basicsSummary(_draft),
                                completed: _draft.basicsSaved,
                                modified: _basicsModified(_draft),
                                onTap: () => _openSection(
                                  widget.basicsPageBuilder(widget.repository),
                                ),
                              ),
                              _SectionRow(
                                icon: createOriginCharactersIconAsset,
                                title: 'Characters (>=1)',
                                summary: _charactersSummary(_draft),
                                completed: _draft.charactersSaved,
                                modified: _charactersModified(_draft),
                                summaryWrap: true,
                                onTap: () => _openSection(
                                  widget.charactersPageBuilder(
                                    widget.repository,
                                  ),
                                ),
                              ),
                              _SectionRow(
                                icon: createOriginLocationsIconAsset,
                                title: 'Locations (Optional)',
                                summary: _locationsSummary(_draft),
                                completed: _draft.locationsSaved,
                                modified: _locationsModified(_draft),
                                summaryWrap: true,
                                onTap: () => _openSection(
                                  widget.locationsPageBuilder(
                                    widget.repository,
                                  ),
                                ),
                              ),
                              _SectionRow(
                                icon: createOriginStoryEventsIconAsset,
                                title: 'Story Events (Optional)',
                                summary: _storyEventsSummary(_draft),
                                completed: _draft.storyEventsSaved,
                                modified: _storyEventsModified(_draft),
                                showDivider: false,
                                onTap: () => _openSection(
                                  widget.storyEventsPageBuilder(
                                    widget.repository,
                                  ),
                                ),
                              ),
                              if (widget.updateNotesController != null) ...[
                                const SizedBox(height: 20),
                                const _UpdateNotesFieldLabel(),
                                const SizedBox(height: 8),
                                _UpdateNotesField(
                                  controller: widget.updateNotesController!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(24, 8, 24, 14),
                  child: GenesisPrimaryButton(
                    label: _isSubmitting
                        ? widget.submittingLabel
                        : widget.submitLabel,
                    onPressed: canUseSubmitButton
                        ? () => unawaited(_submit())
                        : null,
                    backgroundColor: createFormGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: disabledSubmitColor,
                    disabledForegroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _basicsSummary(CreateOriginDraft draft) {
    if (!draft.basicsSaved) return 'Not started yet';
    final basics = draft.basics;
    return [
      'Worldo Name: ${_originNameSummaryValue(basics.originName)}',
      'World View: ${_summaryValue(basics.worldView)}',
      'Cover Image: ${basics.coverImageUrl.trim().isEmpty ? 'Not uploaded' : 'Uploaded'}',
      'World Logic: ${_summaryValue(basics.worldLogic)}',
      'World Time: ${_summaryValue(_worldTimeSummary(basics))}',
      'Progress Metric: ${_summaryValue(_progressMetricSummary(basics))}',
    ].join('\n');
  }

  String _worldTimeSummary(BasicsDraft basics) {
    final parts = <String>[
      if (_singleLineSummaryText(basics.startedAt).isNotEmpty)
        _singleLineSummaryText(basics.startedAt),
      if (_singleLineSummaryText(basics.tickDurationTime).isNotEmpty)
        _singleLineSummaryText(basics.tickDurationTime)
      else if (basics.tickDurationDays != null)
        basics.tickDurationDays == 1
            ? '1 day'
            : '${basics.tickDurationDays} days',
    ];
    return parts.join(', ');
  }

  String _progressMetricSummary(BasicsDraft basics) {
    final raw = basics.metricJson.trim();
    if (raw.isEmpty) return '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return raw;
      final parts = <String>[
        _summaryMetricValue(decoded['label']),
        _summaryMetricValue(decoded['label_note']),
        _summaryMetricValue(decoded['unit']),
        _summaryMetricValue(decoded['default']),
        _summaryMetricValue(decoded['range']),
      ];
      return parts.where((item) => item.isNotEmpty).join(', ');
    } catch (_) {
      return raw;
    }
  }

  String _summaryMetricValue(Object? value) {
    if (value == null) return '';
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .join(' - ');
    }
    return _singleLineSummaryText(value.toString());
  }

  String _charactersSummary(CreateOriginDraft draft) {
    if (!draft.charactersSaved) return 'Not started yet';
    final characters = draft.characters
        .where(_characterDraftHasContent)
        .toList(growable: false);
    if (characters.isEmpty) return '0 characters';
    final names = characters
        .map((item) => _singleLineSummaryText(item.name))
        .where((name) => name.isNotEmpty)
        .join(', ');
    return '${characters.length} characters: $names';
  }

  String _locationsSummary(CreateOriginDraft draft) {
    if (!draft.locationsSaved) return 'Not started yet';
    final locations = draft.locations
        .where(_locationDraftHasContent)
        .toList(growable: false);
    if (locations.isEmpty) return '0 locations';
    final names = locations
        .map((item) => _singleLineSummaryText(item.name))
        .where((name) => name.isNotEmpty)
        .join(', ');
    return '${locations.length} locations: $names';
  }

  String _storyEventsSummary(CreateOriginDraft draft) {
    if (!draft.storyEventsSaved) return 'Not started yet';
    final count = draft.storyEvents
        .map((item) => item.event.trim())
        .where((item) => item.isNotEmpty)
        .length;
    return '$count events';
  }

  String _summaryValue(String value, {int maxLength = 48}) {
    final trimmed = _singleLineSummaryText(value);
    if (trimmed.isEmpty) return '-';
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }

  String _originNameSummaryValue(String value) {
    final trimmed = _singleLineSummaryText(value);
    if (trimmed.isEmpty) return '-';
    return _summaryValue('#$trimmed');
  }

  String _singleLineSummaryText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _versionLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '-';
    if (trimmed.toUpperCase().startsWith('V')) return trimmed;
    return 'V$trimmed';
  }

  bool _basicsModified(CreateOriginDraft draft) {
    final repository = widget.repository;
    return repository is MemoryOriginDraftRepository &&
        repository.basicsChanged(draft);
  }

  bool _charactersModified(CreateOriginDraft draft) {
    final repository = widget.repository;
    return repository is MemoryOriginDraftRepository &&
        repository.charactersChanged(draft);
  }

  bool _locationsModified(CreateOriginDraft draft) {
    final repository = widget.repository;
    return repository is MemoryOriginDraftRepository &&
        repository.locationsChanged(draft);
  }

  bool _storyEventsModified(CreateOriginDraft draft) {
    final repository = widget.repository;
    return repository is MemoryOriginDraftRepository &&
        repository.storyEventsChanged(draft);
  }
}

class _UpdateNotesFieldLabel extends StatelessWidget {
  const _UpdateNotesFieldLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '📝Update notes (required to publish)',
      style: _editSummaryLabelStyle,
    );
  }
}

class _UpdateNotesField extends StatelessWidget {
  const _UpdateNotesField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return CreateTextFieldBlock(
      label: '',
      controller: controller,
      hintText: 'What changed in this version?',
      minLines: 4,
      maxLines: 4,
      textInputAction: TextInputAction.done,
      onChanged: (_) {},
      onEditingComplete: () => FocusManager.instance.primaryFocus?.unfocus(),
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }
}
