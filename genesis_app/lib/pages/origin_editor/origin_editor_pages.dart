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

class OriginBasicsEditorPage extends StatefulWidget {
  const OriginBasicsEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginBasicsEditorPage> createState() => _OriginBasicsEditorPageState();
}

class _OriginBasicsEditorPageState extends State<OriginBasicsEditorPage> {
  final TextEditingController _originNameController = TextEditingController();
  final TextEditingController _worldViewController = TextEditingController();
  final TextEditingController _worldLogicController = TextEditingController();
  final TextEditingController _metricController = TextEditingController();
  final TextEditingController _coverImageController = TextEditingController();
  final TextEditingController _worldStartTimeController =
      TextEditingController();
  final TextEditingController _timeProgressCustomController =
      TextEditingController();
  final TextEditingController _progressMetricController =
      TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _startingValueController =
      TextEditingController();
  final TextEditingController _minValueController = TextEditingController();
  final TextEditingController _maxValueController = TextEditingController();

  bool _isSaving = false;
  bool _isFinalSynced = false;
  String _selectedTimeProgress = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final draft = await widget.repository.loadDraft();
    if (!mounted) return;
    _originNameController.text = draft.basics.originName;
    _worldViewController.text = draft.basics.worldView;
    _worldLogicController.text = draft.basics.worldLogic;
    _metricController.text = draft.basics.metricJson;
    _coverImageController.text = draft.basics.coverImageUrl;
    _loadSimulationSettings(draft.basics.metricJson);
    _isFinalSynced = draft.basicsSaved;
    setState(() {});
  }

  void _onFormChanged() {
    setState(() => _isFinalSynced = false);
  }

  Future<CreateOriginDraft> _draftWithCurrentBasics({
    required bool basicsSaved,
    String? originId,
  }) async {
    final draft = await widget.repository.loadDraft();
    return draft.copyWith(
      basics: draft.basics.copyWith(
        originId: originId ?? draft.basics.originId,
        originName: _originNameController.text.trim(),
        worldView: _worldViewController.text.trim(),
        worldLogic: _worldLogicController.text.trim(),
        metricJson: _simulationSettingsJson(),
        coverImageUrl: _coverImageController.text.trim(),
      ),
      basicsSaved: basicsSaved,
    );
  }

  Future<void> _onSave() async {
    final originName = _originNameController.text.trim();
    final worldView = _worldViewController.text.trim();
    final metricJson = _simulationSettingsJson();
    final coverImage = _coverImageController.text.trim();

    if (originName.isEmpty) {
      _showError('Origin Name is required.');
      return;
    }
    if (worldView.isEmpty) {
      _showError('World View is required.');
      return;
    }
    if (coverImage.isEmpty) {
      _showError('Cover Image is required.');
      return;
    }
    if (metricJson.isNotEmpty) {
      try {
        jsonDecode(metricJson);
      } catch (_) {
        _showError('Metric must be valid JSON.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final uidFuture = readCreateOriginUid(context);
    final draft = await widget.repository.loadDraft();
    final uid = await uidFuture;
    final originId = draft.basics.originId.trim().isEmpty
        ? createUidTimestampHashId(uid: uid, prefix: 'origin')
        : draft.basics.originId.trim();
    final updatedDraft = await _draftWithCurrentBasics(
      basicsSaved: true,
      originId: originId,
    );
    await widget.repository.saveFinalDraft(updatedDraft);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isFinalSynced = true;
    });
    Navigator.of(context).pop(true);
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  void _loadSimulationSettings(String metricJson) {
    final raw = metricJson.trim();
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _worldStartTimeController.text = decoded['start_time']?.toString() ?? '';
      _selectedTimeProgress = decoded['time_per_progress']?.toString() ?? '';
      _timeProgressCustomController.text =
          decoded['time_per_progress_custom']?.toString() ?? '';
      _progressMetricController.text =
          decoded['label']?.toString() ??
          decoded['progress_metric']?.toString() ??
          '';
      _unitController.text = decoded['unit']?.toString() ?? '';
      final range = decoded['range'];
      if (range is List) {
        if (range.isNotEmpty) _minValueController.text = '${range.first}';
        if (range.length > 1) _maxValueController.text = '${range[1]}';
      }
      _startingValueController.text =
          decoded['default']?.toString() ??
          decoded['starting_value']?.toString() ??
          '';
    } catch (_) {
      return;
    }
  }

  String _simulationSettingsJson() {
    final values = <String, String>{
      'start_time': _worldStartTimeController.text.trim(),
      'time_per_progress': _selectedTimeProgress.trim(),
      'time_per_progress_custom': _timeProgressCustomController.text.trim(),
      'progress_metric': _progressMetricController.text.trim(),
      'label': _progressMetricController.text.trim(),
      'unit': _unitController.text.trim(),
      'starting_value': _startingValueController.text.trim(),
      'min': _minValueController.text.trim(),
      'max': _maxValueController.text.trim(),
    }..removeWhere((_, value) => value.isEmpty);

    if (values.isEmpty) return _metricController.text.trim();

    final payload = <String, dynamic>{
      ...values,
      'mode': 'quantitative',
      if (_minValueController.text.trim().isNotEmpty ||
          _maxValueController.text.trim().isNotEmpty)
        'range': [
          _minValueController.text.trim(),
          _maxValueController.text.trim(),
        ],
      if (_startingValueController.text.trim().isNotEmpty)
        'default': _startingValueController.text.trim(),
    };
    return jsonEncode(payload);
  }

  @override
  void dispose() {
    _originNameController.dispose();
    _worldViewController.dispose();
    _worldLogicController.dispose();
    _metricController.dispose();
    _coverImageController.dispose();
    _worldStartTimeController.dispose();
    _timeProgressCustomController.dispose();
    _progressMetricController.dispose();
    _unitController.dispose();
    _startingValueController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: '🌐 Basics'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Define the core settings of your new world.',
                        style: TextStyle(
                          color: createFormMuted,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 26),
                      CreateTextFieldBlock(
                        label: 'Origin Name *',
                        controller: _originNameController,
                        hintText: 'Enter world name...',
                        maxLength: 30,
                        maxLines: 1,
                        prefix: const Text(
                          '#',
                          style: TextStyle(
                            color: createFormText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 24),
                      CreateTextFieldBlock(
                        label: 'World View - Public*',
                        controller: _worldViewController,
                        hintText:
                            'Describe what users see at first glance: the grand cities, immediate crises, and well-known legends...',
                        maxLength: 1000,
                        minLines: 4,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Cover Image *',
                        style: TextStyle(
                          color: createFormText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CreateUploadBox(
                            controller: _coverImageController,
                            label: 'Upload World Image',
                            width: 170,
                            height: 230,
                            iconSize: 42,
                            cropSize: const Size(768, 1024),
                            onChanged: _onFormChanged,
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Used for cards and detail pages.\nRecommend ~768×1024 px.\nSupported formats: JPG, PNG, WEBP.',
                              style: TextStyle(
                                color: createFormMuted,
                                fontSize: 12,
                                height: 1.28,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const _AdvancedSettingsDivider(),
                      const SizedBox(height: 26),
                      CreateTextFieldBlock(
                        label: 'World Logic - Hidden (Optional)',
                        controller: _worldLogicController,
                        hintText:
                            'Define the logic for AI to drive the story: hidden conspiracies, physical laws, undisclosed boss weaknesses, and numerical boundaries...',
                        maxLength: 2000,
                        minLines: 5,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Simulation Settings (Optional)',
                        style: TextStyle(
                          color: createFormText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _SimulationFieldLabel('World Start Time'),
                      const SizedBox(height: 10),
                      CreateTextFieldBlock(
                        label: '',
                        controller: _worldStartTimeController,
                        hintText: 'Day 1 / 2026-01-01 / Dark Year One',
                        maxLines: 1,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Time per Progress',
                        style: TextStyle(
                          color: createFormMuted,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _TimeProgressPicker(
                        selected: _selectedTimeProgress,
                        onSelected: (value) {
                          setState(() => _selectedTimeProgress = value);
                          _onFormChanged();
                        },
                      ),
                      const SizedBox(height: 10),
                      CreateTextFieldBlock(
                        label: '',
                        controller: _timeProgressCustomController,
                        hintText: 'e.g. one season, one council meeting',
                        maxLines: 1,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 18),
                      const _SimulationFieldLabel('Progress Metric'),
                      const SizedBox(height: 10),
                      CreateTextFieldBlock(
                        label: '',
                        controller: _progressMetricController,
                        hintText: 'Goal Progress / Wealth / Affection',
                        maxLines: 1,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 18),
                      const _SimulationFieldLabel('Unit'),
                      const SizedBox(height: 10),
                      CreateTextFieldBlock(
                        label: '',
                        controller: _unitController,
                        hintText: '%, percent, pts, coins, reputation',
                        maxLines: 1,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Value Range',
                        style: TextStyle(
                          color: createFormMuted,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: CreateTextFieldBlock(
                              label: '',
                              controller: _startingValueController,
                              hintText: 'Starting',
                              maxLines: 1,
                              onChanged: (_) => _onFormChanged(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CreateTextFieldBlock(
                              label: '',
                              controller: _minValueController,
                              hintText: 'Min',
                              maxLines: 1,
                              onChanged: (_) => _onFormChanged(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CreateTextFieldBlock(
                              label: '',
                              controller: _maxValueController,
                              hintText: 'Max',
                              maxLines: 1,
                              onChanged: (_) => _onFormChanged(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(24, 8, 24, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  onPressed: (_isSaving || _isFinalSynced) ? null : _onSave,
                  backgroundColor: createFormGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFBFD8CD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvancedSettingsDivider extends StatelessWidget {
  const _AdvancedSettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(height: 1, color: createFormBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Advanced Settings (Optional)',
            style: TextStyle(
              color: createFormMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(height: 1, color: createFormBorder)),
      ],
    );
  }
}

class _SimulationFieldLabel extends StatelessWidget {
  const _SimulationFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: createFormMuted, fontSize: 12, height: 1.2),
    );
  }
}

class _TimeProgressPicker extends StatelessWidget {
  const _TimeProgressPicker({required this.selected, required this.onSelected});

  static const List<String> _options = <String>[
    'Half day',
    '1 day',
    '1 week',
    '1 month',
  ];

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 4.8,
      children: [
        for (final option in _options)
          _TimeProgressOption(
            label: option,
            selected: option == selected,
            onTap: () => onSelected(option == selected ? '' : option),
          ),
      ],
    );
  }
}

class _TimeProgressOption extends StatelessWidget {
  const _TimeProgressOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE0EEE8) : createFormFieldFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? createFormGreen : createFormMuted,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class OriginCharactersEditorPage extends StatefulWidget {
  const OriginCharactersEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginCharactersEditorPage> createState() =>
      _OriginCharactersEditorPageState();
}

class _OriginCharactersEditorPageState
    extends State<OriginCharactersEditorPage> {
  static const int _maxCharacters = 8;

  final List<OriginCharacterForm> _forms = <OriginCharacterForm>[];
  String _uid = 'anonymous';
  bool _isSaving = false;
  bool _isFinalSynced = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uidFuture = readCreateOriginUid(context);
    final draft = await widget.repository.loadDraft();
    _uid = await uidFuture;
    final source = draft.characters.isEmpty
        ? const <CharacterDraft>[CharacterDraft()]
        : draft.characters;
    final missingIds = source.any((item) => item.charId.trim().isEmpty);
    for (final item in source) {
      _forms.add(_characterFormFromDraft(item, uid: _uid));
    }
    if (!mounted) return;
    _isFinalSynced = draft.charactersSaved && !missingIds;
    setState(() {});
  }

  void _addCharacter() {
    if (_forms.length >= _maxCharacters) {
      _showError('You can add up to $_maxCharacters characters.');
      return;
    }
    setState(() {
      _forms.add(
        OriginCharacterForm.empty(
          charId: createUidTimestampHashId(uid: _uid, prefix: 'char'),
        ),
      );
    });
    _onFormChanged();
  }

  Future<void> _requestRemoveCharacter(int index) async {
    final form = _forms[index];
    if (form.hasContent) {
      final confirmed = await confirmCreateFormDelete(
        context,
        itemLabel: 'Character ${index + 1}',
      );
      if (!confirmed || !mounted) return;
    }
    _removeCharacter(index);
  }

  void _removeCharacter(int index) {
    if (_forms.length <= 1) {
      _forms[index].clear();
    } else {
      final form = _forms.removeAt(index);
      form.dispose();
    }
    _onFormChanged();
  }

  void _onFormChanged() {
    setState(() => _isFinalSynced = false);
  }

  List<CharacterDraft> _snapshotCharacters() {
    return _forms
        .map(
          (form) => CharacterDraft(
            charId: form.charId,
            avatarUrl: form.avatarUrl.text.trim(),
            name: form.name.text.trim(),
            identity: form.identity.text.trim(),
            personality: form.personality.text.trim(),
            bio: form.bio.text.trim(),
            goal: form.goal.text.trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _saveCharacters() async {
    for (int i = 0; i < _forms.length; i++) {
      final form = _forms[i];
      if (!form.hasContent) continue;
      if (form.name.text.trim().isEmpty) {
        _showError('Character ${i + 1}: Name is required.');
        return;
      }
      if (form.identity.text.trim().isEmpty) {
        _showError('Character ${i + 1}: Identity is required.');
        return;
      }
      if (form.personality.text.trim().isEmpty) {
        _showError('Character ${i + 1}: Personality is required.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    final characters = _snapshotCharacters()
        .where(_characterDraftHasContent)
        .toList(growable: false);
    final validCharacterIds = characters
        .map((item) => item.charId.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    final updatedDraft = draft
        .copyWith(characters: characters, charactersSaved: true)
        .pruneLocationBindings(validCharacterIds);

    await widget.repository.saveFinalDraft(updatedDraft);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isFinalSynced = true;
    });
    Navigator.of(context).pop(true);
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  OriginCharacterForm _characterFormFromDraft(
    CharacterDraft draft, {
    required String uid,
  }) {
    return OriginCharacterForm.fromValues(
      charId: draft.charId.trim().isEmpty
          ? createUidTimestampHashId(uid: uid, prefix: 'char')
          : draft.charId.trim(),
      avatarUrl: draft.avatarUrl,
      name: draft.name,
      identity: draft.identity,
      personality: draft.personality,
      bio: draft.bio,
      goal: draft.goal,
    );
  }

  @override
  void dispose() {
    for (final form in _forms) {
      form.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: '👤 Characters'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Define the souls that inhabit your world. Each character requires an identity and personality to interact authentically.',
                        style: TextStyle(
                          color: createFormMuted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_forms.length}/$_maxCharacters (Added / Max)',
                          style: const TextStyle(
                            color: createFormText,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (int i = 0; i < _forms.length; i++) ...[
                        _CharacterCard(
                          index: i + 1,
                          form: _forms[i],
                          onChanged: _onFormChanged,
                          onDelete: () {
                            _requestRemoveCharacter(i);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      CreateAddButton(
                        label: '+ Add Character',
                        onTap: _addCharacter,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(24, 8, 24, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  onPressed: (_isSaving || _isFinalSynced)
                      ? null
                      : _saveCharacters,
                  backgroundColor: createFormGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFBFD8CD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OriginLocationsEditorPage extends StatefulWidget {
  const OriginLocationsEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginLocationsEditorPage> createState() =>
      _OriginLocationsEditorPageState();
}

class _OriginLocationsEditorPageState extends State<OriginLocationsEditorPage> {
  static const int _maxLocations = 10;

  final List<_LocationForm> _forms = <_LocationForm>[];
  String _uid = 'anonymous';
  List<CharacterDraft> _finalCharacters = const <CharacterDraft>[];
  bool _isSaving = false;
  bool _isFinalSynced = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uidFuture = readCreateOriginUid(context);
    final draft = await widget.repository.loadDraft();
    _finalCharacters = await widget.repository.loadSavedCharacters();
    _uid = await uidFuture;
    final source = draft.locations.isEmpty
        ? const <LocationDraft>[LocationDraft()]
        : draft.locations;
    final missingIds = source.any((item) => item.locationId.trim().isEmpty);
    for (final item in source) {
      _forms.add(_LocationForm.fromDraft(item, uid: _uid));
    }
    if (!mounted) return;
    _isFinalSynced = draft.locationsSaved && !missingIds;
    setState(() {});
  }

  void _addLocation() {
    if (_forms.length >= _maxLocations) {
      _showError('You can add up to $_maxLocations locations.');
      return;
    }
    setState(() {
      _forms.add(
        _LocationForm.empty(
          locationId: createUidTimestampHashId(uid: _uid, prefix: 'location'),
        ),
      );
    });
    _onFormChanged();
  }

  Future<void> _requestRemoveLocation(int index) async {
    final form = _forms[index];
    if (form.hasContent) {
      final confirmed = await confirmCreateFormDelete(
        context,
        itemLabel: 'Location ${index + 1}',
      );
      if (!confirmed || !mounted) return;
    }
    _removeLocation(index);
  }

  void _removeLocation(int index) {
    if (_forms.length <= 1) {
      _forms[index].clear();
    } else {
      final form = _forms.removeAt(index);
      form.dispose();
    }
    _onFormChanged();
  }

  void _onFormChanged() {
    setState(() => _isFinalSynced = false);
  }

  List<LocationDraft> _snapshotLocations() {
    final validCharacterIds = _finalCharacters
        .map((item) => item.charId.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    return _forms
        .map(
          (form) => LocationDraft(
            locationId: form.locationId,
            parentLocationId: form.parentLocationId,
            imageUrl: form.imageUrl.text.trim(),
            name: form.name.text.trim(),
            description: form.description.text.trim(),
            initialCharacterIds: form.selectedCharacterIds
                .where(validCharacterIds.contains)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _openParentLocationPicker(int locationIndex) async {
    final form = _forms[locationIndex];
    final options = _parentLocationOptions(locationIndex);
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ParentLocationPickerSheet(
          options: options,
          initialSelectedId: form.parentLocationId,
        );
      },
    );
    if (selectedId == null || !mounted) return;
    setState(() {
      form.parentLocationId = selectedId;
    });
    _onFormChanged();
  }

  Future<void> _openCharacterPicker(int locationIndex) async {
    final characters = await widget.repository.loadSavedCharacters();
    if (!mounted) return;
    setState(() => _finalCharacters = characters);
    if (characters.isEmpty) {
      _showError('There are no characters yet.');
      return;
    }

    final blockedIds = _boundCharacterIdsExcept(locationIndex);
    final currentIds = _forms[locationIndex].selectedCharacterIds.toSet();
    final availableCharacters = characters
        .where((item) {
          final charId = item.charId.trim();
          if (charId.isEmpty) return false;
          return currentIds.contains(charId) || !blockedIds.contains(charId);
        })
        .toList(growable: false);

    if (availableCharacters.isEmpty) {
      _showError('There are no available characters.');
      return;
    }

    final selectedIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _CharacterPickerSheet(
          characters: availableCharacters,
          initialSelectedIds: currentIds,
        );
      },
    );
    if (selectedIds == null || !mounted) return;
    setState(() {
      _forms[locationIndex].selectedCharacterIds = selectedIds;
    });
    _onFormChanged();
  }

  Set<String> _boundCharacterIdsExcept(int excludedIndex) {
    final ids = <String>{};
    for (int i = 0; i < _forms.length; i++) {
      if (i == excludedIndex) continue;
      ids.addAll(_forms[i].selectedCharacterIds);
    }
    return ids;
  }

  List<_ParentLocationOption> _parentLocationOptions(int locationIndex) {
    final options = <_ParentLocationOption>[
      const _ParentLocationOption(id: '', label: 'World Root'),
    ];
    final childId = _forms[locationIndex].locationId.trim();
    for (int i = 0; i < _forms.length; i++) {
      if (i == locationIndex) continue;
      final form = _forms[i];
      final locationId = form.locationId.trim();
      if (locationId.isEmpty) continue;
      if (_wouldCreateParentCycle(childId: childId, parentId: locationId)) {
        continue;
      }
      final name = form.name.text.trim();
      options.add(
        _ParentLocationOption(
          id: locationId,
          label: name.isEmpty ? 'Location ${i + 1}' : name,
        ),
      );
    }
    return options;
  }

  bool _wouldCreateParentCycle({
    required String childId,
    required String parentId,
  }) {
    if (childId.isEmpty || parentId.isEmpty) return false;
    if (childId == parentId) return true;
    final parentsById = <String, String>{
      for (final form in _forms)
        if (form.locationId.trim().isNotEmpty)
          form.locationId.trim(): form.parentLocationId.trim(),
    };
    var current = parentId;
    final seen = <String>{childId};
    while (current.isNotEmpty) {
      if (!seen.add(current)) return true;
      current = parentsById[current] ?? '';
    }
    return false;
  }

  Future<void> _saveLocations() async {
    for (int i = 0; i < _forms.length; i++) {
      final form = _forms[i];
      if (!form.hasContent) continue;
      if (form.name.text.trim().isEmpty) {
        _showError('Location ${i + 1}: Location Name is required.');
        return;
      }
      final parentId = form.parentLocationId.trim();
      if (parentId.isNotEmpty &&
          !_forms.any((item) => item.locationId.trim() == parentId)) {
        _showError('Location ${i + 1}: Parent Location is invalid.');
        return;
      }
      if (_wouldCreateParentCycle(
        childId: form.locationId.trim(),
        parentId: parentId,
      )) {
        _showError('Location ${i + 1}: Parent Location creates a cycle.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    _finalCharacters = await widget.repository.loadSavedCharacters();
    final locations = _snapshotLocations()
        .where(_locationDraftHasContent)
        .toList(growable: false);

    await widget.repository.saveFinalDraft(
      draft.copyWith(locations: locations, locationsSaved: true),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isFinalSynced = true;
    });
    Navigator.of(context).pop(true);
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  @override
  void dispose() {
    for (final form in _forms) {
      form.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: '📍 Locations'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Place your world on the map. Add a location image and name, then link characters who start there.',
                        style: TextStyle(
                          color: createFormMuted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_forms.length}/$_maxLocations (Added / Max)',
                          style: const TextStyle(
                            color: createFormText,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (int i = 0; i < _forms.length; i++) ...[
                        _LocationCard(
                          index: i + 1,
                          form: _forms[i],
                          characters: _finalCharacters,
                          parentOptions: _parentLocationOptions(i),
                          onChanged: _onFormChanged,
                          onPickParentLocation: () =>
                              _openParentLocationPicker(i),
                          onPickCharacters: () => _openCharacterPicker(i),
                          onDelete: () {
                            _requestRemoveLocation(i);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      CreateAddButton(
                        label: '+ Add Location',
                        onTap: _addLocation,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(28, 8, 28, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  onPressed: (_isSaving || _isFinalSynced)
                      ? null
                      : _saveLocations,
                  backgroundColor: createFormGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFBFD8CD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OriginStoryEventsEditorPage extends StatefulWidget {
  const OriginStoryEventsEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginStoryEventsEditorPage> createState() =>
      _OriginStoryEventsEditorPageState();
}

class _OriginStoryEventsEditorPageState
    extends State<OriginStoryEventsEditorPage> {
  static const int _maxEvents = 20;
  final List<TextEditingController> _eventControllers =
      <TextEditingController>[];

  bool _isSaving = false;
  bool _isFinalSynced = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final draft = await widget.repository.loadDraft();
    final source = draft.storyEvents.isEmpty
        ? const <StoryEventDraft>[StoryEventDraft()]
        : draft.storyEvents;
    for (final event in source) {
      _eventControllers.add(TextEditingController(text: event.event));
    }
    if (!mounted) return;
    _isFinalSynced = draft.storyEventsSaved;
    setState(() {});
  }

  void _addEvent() {
    if (_eventControllers.length >= _maxEvents) {
      _showError('You can add up to $_maxEvents events.');
      return;
    }
    setState(() => _eventControllers.add(TextEditingController()));
    _onFormChanged();
  }

  Future<void> _requestRemoveEvent(int index) async {
    final controller = _eventControllers[index];
    if (controller.text.trim().isNotEmpty) {
      final confirmed = await confirmCreateFormDelete(
        context,
        itemLabel: 'Event ${index + 1}',
      );
      if (!confirmed || !mounted) return;
    }
    _removeEvent(index);
  }

  void _removeEvent(int index) {
    if (_eventControllers.length <= 1) {
      _eventControllers[index].clear();
    } else {
      final controller = _eventControllers.removeAt(index);
      controller.dispose();
    }
    _onFormChanged();
  }

  void _onFormChanged() {
    setState(() => _isFinalSynced = false);
  }

  List<StoryEventDraft> _snapshotEvents() {
    return _eventControllers
        .map((controller) => StoryEventDraft(event: controller.text.trim()))
        .toList(growable: false);
  }

  Future<void> _saveEvents() async {
    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    final events = _snapshotEvents()
        .where((item) => item.event.trim().isNotEmpty)
        .toList(growable: false);

    await widget.repository.saveFinalDraft(
      draft.copyWith(storyEvents: events, storyEventsSaved: true),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isFinalSynced = true;
    });
    Navigator.of(context).pop(true);
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  @override
  void dispose() {
    for (final controller in _eventControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: '📜 Story Events'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Optional story beats or scenes. Each event is free text; keep them short and clear for the world runtime.',
                        style: TextStyle(
                          color: createFormMuted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_eventControllers.length}/$_maxEvents (Added / Max)',
                          style: const TextStyle(
                            color: createFormText,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (int i = 0; i < _eventControllers.length; i++) ...[
                        _StoryEventCard(
                          index: i + 1,
                          controller: _eventControllers[i],
                          onChanged: _onFormChanged,
                          onDelete: () {
                            _requestRemoveEvent(i);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      CreateAddButton(label: '+ Add Event', onTap: _addEvent),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(28, 8, 28, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  onPressed: (_isSaving || _isFinalSynced) ? null : _saveEvents,
                  backgroundColor: createFormGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFBFD8CD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.title,
    required this.summary,
    required this.completed,
    required this.onTap,
    this.showDivider = true,
  });

  final String icon;
  final String title;
  final String summary;
  final bool completed;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final line in _summaryLines)
                                      Text(
                                        line,
                                        textAlign: TextAlign.left,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: const TextStyle(
                                          color: Color(0xFF6F6F6F),
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (completed)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF198B64),
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF8A8A8A),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
        ],
      ),
    );
  }

  List<String> get _summaryLines {
    return summary
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.index,
    required this.form,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final OriginCharacterForm form;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Character $index',
      onDelete: onDelete,
      child: OriginCharacterFormFields(form: form, onChanged: onChanged),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.index,
    required this.form,
    required this.characters,
    required this.parentOptions,
    required this.onChanged,
    required this.onPickParentLocation,
    required this.onPickCharacters,
    required this.onDelete,
  });

  final int index;
  final _LocationForm form;
  final List<CharacterDraft> characters;
  final List<_ParentLocationOption> parentOptions;
  final VoidCallback onChanged;
  final VoidCallback onPickParentLocation;
  final VoidCallback onPickCharacters;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Location $index',
      onDelete: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreateUploadBox(
                controller: form.imageUrl,
                label: 'IMAGE\n(Optional)',
                width: 96,
                height: 150,
                iconSize: 36,
                cropSize: const Size(384, 600),
                onChanged: onChanged,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CreateTextFieldBlock(
                  label: 'Location Name *',
                  controller: form.name,
                  hintText: 'Enter location name...',
                  maxLength: 25,
                  maxLines: 1,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          CreateTextFieldBlock(
            label: 'Description (Optional)',
            controller: form.description,
            hintText: 'Show in Origin location list',
            maxLength: 100,
            minLines: 2,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 22),
          _ParentLocationField(
            form: form,
            options: parentOptions,
            onPickParentLocation: onPickParentLocation,
          ),
          const SizedBox(height: 22),
          _InitialCharactersField(
            form: form,
            characters: characters,
            onPickCharacters: onPickCharacters,
          ),
        ],
      ),
    );
  }
}

class _ParentLocationField extends StatelessWidget {
  const _ParentLocationField({
    required this.form,
    required this.options,
    required this.onPickParentLocation,
  });

  final _LocationForm form;
  final List<_ParentLocationOption> options;
  final VoidCallback onPickParentLocation;

  @override
  Widget build(BuildContext context) {
    final selected = options.firstWhere(
      (option) => option.id == form.parentLocationId.trim(),
      orElse: () => options.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parent Location',
          style: TextStyle(
            color: createFormText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          key: const ValueKey('location-parent-picker'),
          behavior: HitTestBehavior.opaque,
          onTap: onPickParentLocation,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: createFormFieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: createFormText,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onPickParentLocation,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: createFormGreen,
                    size: 32,
                  ),
                  splashRadius: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialCharactersField extends StatelessWidget {
  const _InitialCharactersField({
    required this.form,
    required this.characters,
    required this.onPickCharacters,
  });

  final _LocationForm form;
  final List<CharacterDraft> characters;
  final VoidCallback onPickCharacters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Initial Characters (Optional)',
          style: TextStyle(
            color: createFormText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          key: const ValueKey('location-character-picker'),
          behavior: HitTestBehavior.opaque,
          onTap: onPickCharacters,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: createFormFieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _selectedNames.isEmpty
                          ? createFormHint
                          : createFormText,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onPickCharacters,
                  icon: const Icon(Icons.add, color: createFormGreen, size: 32),
                  splashRadius: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _selectedNames {
    final byId = {
      for (final item in characters) item.charId.trim(): item.name.trim(),
    };
    return form.selectedCharacterIds
        .map((id) => byId[id] ?? '')
        .where((name) => name.isNotEmpty)
        .join(', ');
  }
}

class _CharacterPickerSheet extends StatefulWidget {
  const _CharacterPickerSheet({
    required this.characters,
    required this.initialSelectedIds,
  });

  final List<CharacterDraft> characters;
  final Set<String> initialSelectedIds;

  @override
  State<_CharacterPickerSheet> createState() => _CharacterPickerSheetState();
}

class _ParentLocationOption {
  const _ParentLocationOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _ParentLocationPickerSheet extends StatefulWidget {
  const _ParentLocationPickerSheet({
    required this.options,
    required this.initialSelectedId,
  });

  final List<_ParentLocationOption> options;
  final String initialSelectedId;

  @override
  State<_ParentLocationPickerSheet> createState() =>
      _ParentLocationPickerSheetState();
}

class _ParentLocationPickerSheetState
    extends State<_ParentLocationPickerSheet> {
  late String _selectedId = widget.initialSelectedId.trim();

  @override
  Widget build(BuildContext context) {
    return GenesisBottomSheetPanel(
      title: 'Select Parent Location',
      height: MediaQuery.sizeOf(context).height * 0.58,
      trailing: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close, size: 30, color: createFormMuted),
        splashRadius: 24,
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: widget.options.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: createFormBorder),
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final selected = option.id == _selectedId;
                return ListTile(
                  key: ValueKey('parent-location-option-${option.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: createFormText,
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected
                          ? createFormGreen
                          : const Color(0xFF9B9B9B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  onTap: () => setState(() => _selectedId = option.id),
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GenesisPrimaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: Colors.white,
                  foregroundColor: createFormText,
                  side: const BorderSide(color: createFormBorder),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: GenesisPrimaryButton(
                  label: 'Select',
                  onPressed: () => Navigator.of(context).pop(_selectedId),
                  backgroundColor: createFormGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterPickerSheetState extends State<_CharacterPickerSheet> {
  late final Set<String> _selectedIds = <String>{...widget.initialSelectedIds};

  @override
  Widget build(BuildContext context) {
    return GenesisBottomSheetPanel(
      title: 'Select Characters',
      height: MediaQuery.sizeOf(context).height * 0.58,
      trailing: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close, size: 30, color: createFormMuted),
        splashRadius: 24,
      ),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 22,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: widget.characters.length,
              itemBuilder: (context, index) {
                final character = widget.characters[index];
                final charId = character.charId.trim();
                final selected = _selectedIds.contains(charId);
                return _CharacterPickerTile(
                  character: character,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedIds.remove(charId);
                      } else {
                        _selectedIds.add(charId);
                      }
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: GenesisPrimaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  backgroundColor: Colors.white,
                  foregroundColor: createFormText,
                  side: const BorderSide(color: createFormBorder),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: GenesisPrimaryButton(
                  label: 'Select',
                  onPressed: () =>
                      Navigator.of(context).pop(_selectedIds.toList()),
                  backgroundColor: createFormGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterPickerTile extends StatelessWidget {
  const _CharacterPickerTile({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final CharacterDraft character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('character-picker-tile-${character.charId.trim()}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: createFormFieldFill,
                    child: character.avatarUrl.trim().isEmpty
                        ? GenesisAvatarFallback(
                            name: character.name,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 8,
                          )
                        : GenesisAvatar(
                            url: character.avatarUrl.trim(),
                            name: character.name,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: 8,
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected
                          ? createFormGreen
                          : const Color(0xFF9B9B9B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            character.name.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: createFormText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationForm {
  _LocationForm({
    required this.locationId,
    required this.parentLocationId,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.selectedCharacterIds,
  });

  factory _LocationForm.empty({required String locationId}) {
    return _LocationForm(
      locationId: locationId,
      parentLocationId: '',
      imageUrl: TextEditingController(),
      name: TextEditingController(),
      description: TextEditingController(),
      selectedCharacterIds: <String>[],
    );
  }

  factory _LocationForm.fromDraft(LocationDraft draft, {required String uid}) {
    return _LocationForm(
      locationId: draft.locationId.trim().isEmpty
          ? createUidTimestampHashId(uid: uid, prefix: 'location')
          : draft.locationId.trim(),
      parentLocationId: draft.parentLocationId.trim(),
      imageUrl: TextEditingController(text: draft.imageUrl),
      name: TextEditingController(text: draft.name),
      description: TextEditingController(text: draft.description),
      selectedCharacterIds: draft.initialCharacterIds,
    );
  }

  final String locationId;
  String parentLocationId;
  final TextEditingController imageUrl;
  final TextEditingController name;
  final TextEditingController description;
  List<String> selectedCharacterIds;

  void dispose() {
    imageUrl.dispose();
    name.dispose();
    description.dispose();
  }

  bool get hasContent {
    return [
          imageUrl,
          name,
          description,
        ].any((controller) => controller.text.trim().isNotEmpty) ||
        parentLocationId.trim().isNotEmpty ||
        selectedCharacterIds.isNotEmpty;
  }

  void clear() {
    parentLocationId = '';
    imageUrl.clear();
    name.clear();
    description.clear();
    selectedCharacterIds = <String>[];
  }
}

class _StoryEventCard extends StatelessWidget {
  const _StoryEventCard({
    required this.index,
    required this.controller,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Event $index',
      onDelete: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          CreateTextFieldBlock(
            label: '',
            controller: controller,
            hintText: 'Event (any language)',
            maxLength: 1000,
            minLines: 7,
            labelSize: 0,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
