part of 'origin_editor_pages.dart';

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
  final TextEditingController _labelNoteController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _startingValueController =
      TextEditingController();
  final TextEditingController _minValueController = TextEditingController();
  final TextEditingController _maxValueController = TextEditingController();
  final FocusNode _originNameFocusNode = FocusNode();
  final FocusNode _worldViewFocusNode = FocusNode();
  final FocusNode _worldLogicFocusNode = FocusNode();
  final FocusNode _worldStartTimeFocusNode = FocusNode();
  final FocusNode _timeProgressCustomFocusNode = FocusNode();
  final FocusNode _progressMetricFocusNode = FocusNode();
  final FocusNode _labelNoteFocusNode = FocusNode();
  final FocusNode _unitFocusNode = FocusNode();
  final FocusNode _startingValueFocusNode = FocusNode();
  final FocusNode _minValueFocusNode = FocusNode();
  final FocusNode _maxValueFocusNode = FocusNode();

  bool _isSaving = false;
  String _metricMode = 'qualitative';
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
    _loadSimulationSettings(
      metricJson: draft.basics.metricJson,
      startedAt: draft.basics.startedAt,
      tickDurationTime: draft.basics.tickDurationTime,
      tickDurationDays: draft.basics.tickDurationDays,
    );
    setState(() {});
  }

  void _onFormChanged() {
    setState(() {});
  }

  Future<CreateOriginDraft> _draftWithCurrentBasics({
    required bool basicsSaved,
    String? originId,
  }) async {
    final draft = await widget.repository.loadDraft();
    return draft.copyWith(
      basics: draft.basics.copyWith(
        originId: originId ?? draft.basics.originId,
        originName: normalizeGenesisUgcTextForDisplay(
          _originNameController.text,
        ),
        worldView: normalizeGenesisUgcTextForDisplay(_worldViewController.text),
        worldLogic: normalizeGenesisUgcTextForDisplay(
          _worldLogicController.text,
        ),
        metricJson: _simulationSettingsJson(),
        startedAt: _worldStartTimeController.text.trim(),
        tickDurationTime: _tickDurationTime(),
        tickDurationDays: _tickDurationDays(),
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
      _showError('Worldo Name is required.');
      return;
    }
    if (worldView.isEmpty) {
      _showError('Worldo Brief is required.');
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
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  bool get _canSaveCurrentBasics {
    if (_originNameController.text.trim().isEmpty ||
        _worldViewController.text.trim().isEmpty ||
        _coverImageController.text.trim().isEmpty) {
      return false;
    }
    final metricJson = _simulationSettingsJson();
    if (metricJson.trim().isEmpty) return true;
    try {
      jsonDecode(metricJson);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get _canUseSaveButton {
    if (_isSaving) return false;
    return _canSaveCurrentBasics;
  }

  String get _saveDisabledReason {
    if (_isSaving) return 'Saving is already in progress.';
    if (_originNameController.text.trim().isEmpty) {
      return 'Worldo Name is required.';
    }
    if (_worldViewController.text.trim().isEmpty) {
      return 'Worldo Brief is required.';
    }
    if (_coverImageController.text.trim().isEmpty) {
      return 'Cover Image is required.';
    }
    final metricJson = _simulationSettingsJson();
    if (metricJson.trim().isNotEmpty) {
      try {
        jsonDecode(metricJson);
      } catch (_) {
        return 'Metric must be valid JSON.';
      }
    }
    return 'Complete all required fields before saving.';
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  void _loadSimulationSettings({
    required String metricJson,
    required String startedAt,
    required String tickDurationTime,
    required int? tickDurationDays,
  }) {
    _worldStartTimeController.text = startedAt.trim();
    final durationText = tickDurationTime.trim();
    if (durationText.isNotEmpty) {
      _selectedTimeProgress = _timeProgressOptionForValue(durationText);
      if (_selectedTimeProgress.isEmpty) {
        _timeProgressCustomController.text = durationText;
      }
    } else if (tickDurationDays != null) {
      final legacyValue = tickDurationDays == 1
          ? '1 day'
          : '$tickDurationDays days';
      _selectedTimeProgress = _timeProgressOptionForValue(legacyValue);
      if (_selectedTimeProgress.isEmpty) {
        _timeProgressCustomController.text = legacyValue;
      }
    }

    final raw = metricJson.trim();
    if (raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _worldStartTimeController.text = _worldStartTimeController.text.isNotEmpty
          ? _worldStartTimeController.text
          : decoded['start_time']?.toString() ?? '';
      _metricMode = decoded['mode']?.toString().trim().isNotEmpty == true
          ? decoded['mode'].toString().trim()
          : _metricMode;
      if (durationText.isEmpty && tickDurationDays == null) {
        _selectedTimeProgress = decoded['time_per_progress']?.toString() ?? '';
        _timeProgressCustomController.text =
            decoded['time_per_progress_custom']?.toString() ?? '';
      }
      _progressMetricController.text =
          decoded['label']?.toString() ??
          decoded['progress_metric']?.toString() ??
          '';
      _labelNoteController.text = decoded['label_note']?.toString() ?? '';
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
      'label': normalizeGenesisUgcTextForDisplay(
        _progressMetricController.text,
      ),
      'label_note': normalizeGenesisUgcTextForDisplay(
        _labelNoteController.text,
      ),
      'unit': normalizeGenesisUgcTextForDisplay(_unitController.text),
    }..removeWhere((_, value) => value.isEmpty);

    if (values.isEmpty) return _worldMetricFallbackJson();

    final payload = <String, dynamic>{
      'mode': _metricMode.trim().isEmpty ? 'qualitative' : _metricMode.trim(),
      ...values,
      if (_minValueController.text.trim().isNotEmpty &&
          _maxValueController.text.trim().isNotEmpty)
        'range': [
          _numericSetting(_minValueController.text.trim()),
          _numericSetting(_maxValueController.text.trim()),
        ],
      if (_startingValueController.text.trim().isNotEmpty)
        'default': _numericSetting(_startingValueController.text.trim()),
    };
    return jsonEncode(payload);
  }

  String _worldMetricFallbackJson() {
    final raw = _metricController.text.trim();
    if (raw.isEmpty) return '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return raw;
      final payload = <String, dynamic>{
        for (final key in const [
          'mode',
          'label',
          'label_note',
          'unit',
          'range',
          'default',
        ])
          if (decoded[key] != null && decoded[key].toString().trim().isNotEmpty)
            key: decoded[key],
      };
      return payload.isEmpty ? '' : jsonEncode(payload);
    } catch (_) {
      return raw;
    }
  }

  int? _tickDurationDays() {
    final value = _tickDurationTime();
    if (value == null) return null;
    return _daysForTimeProgressValue(value);
  }

  String? _tickDurationTime() {
    final selected = _selectedTimeProgress.trim();
    if (selected.isNotEmpty) return selected;
    final custom = _timeProgressCustomController.text.trim();
    return custom.isEmpty ? null : custom;
  }

  int? _daysForTimeProgressValue(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      '1 day' => 1,
      '1 week' => 7,
      _ =>
        normalized.endsWith('days') || normalized.endsWith('day')
            ? int.tryParse(
                RegExp(r'\d+').firstMatch(normalized)?.group(0) ?? '',
              )
            : int.tryParse(normalized),
    };
  }

  String _timeProgressOptionForValue(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      '6 hours' => '6 hours',
      '12 hours' => '12 hours',
      '1 day' => '1 day',
      '1 week' => '1 week',
      _ => '',
    };
  }

  void _selectTimeProgress(String value) {
    setState(() {
      if (_selectedTimeProgress == value) {
        _selectedTimeProgress = '';
      } else {
        _selectedTimeProgress = value;
        _timeProgressCustomController.clear();
      }
    });
  }

  void _handleTimeProgressCustomChanged(String value) {
    setState(() {
      if (value.trim().isNotEmpty) {
        _selectedTimeProgress = '';
      }
    });
  }

  Object _numericSetting(String text) {
    final intValue = int.tryParse(text);
    if (intValue != null) return intValue;
    return double.tryParse(text) ?? text;
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
    _labelNoteController.dispose();
    _unitController.dispose();
    _startingValueController.dispose();
    _minValueController.dispose();
    _maxValueController.dispose();
    _originNameFocusNode.dispose();
    _worldViewFocusNode.dispose();
    _worldLogicFocusNode.dispose();
    _worldStartTimeFocusNode.dispose();
    _timeProgressCustomFocusNode.dispose();
    _progressMetricFocusNode.dispose();
    _labelNoteFocusNode.dispose();
    _unitFocusNode.dispose();
    _startingValueFocusNode.dispose();
    _minValueFocusNode.dispose();
    _maxValueFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.genesisColors.pageBackground,
      appBar: GenesisAppBar(
        title: 'Basics',
        variant: GenesisAppBarVariant.leadingTitle,
        backButtonKey: const ValueKey('basics-back-button'),
        backForegroundColor: context.genesisCreateColors.text,
        titleStyle: GenesisTypography.navigationTitle.copyWith(
          color: context.genesisCreateColors.text,
        ),
      ),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BasicsTextField(
                        label: 'Worldo Name',
                        requiredIndicator: true,
                        controller: _originNameController,
                        hintText: 'eg. Main Street',
                        maxLength: 30,
                        maxLines: 1,
                        focusNode: _originNameFocusNode,
                        nextFocusNode: _worldViewFocusNode,
                        prefix: Text(
                          '#',
                          style: TextStyle(
                            color: context.genesisCreateColors.successText,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.55,
                          ),
                        ),
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 14),
                      _BasicsTextField(
                        label: 'Worldo Brief',
                        requiredIndicator: true,
                        controller: _worldViewController,
                        hintText:
                            'eg. Half the shops on Main Street are boarded up. By Labor Day, the richest storefront owns the town.',
                        maxLength: 300,
                        note:
                            'The public hook players see first — the setting, the core conflict, and what makes it intriguing.',
                        minLines: 3,
                        maxLines: 8,
                        minimumHeight: 88,
                        fieldPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        focusNode: _worldViewFocusNode,
                        nextFocusNode: _worldLogicFocusNode,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 18),
                      const _BasicsFieldLabel(
                        'Cover Image',
                        requiredIndicator: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CreateUploadBox(
                            controller: _coverImageController,
                            label: 'Upload',
                            width: 132,
                            height: 176,
                            iconSize: 22,
                            borderRadius: 13,
                            cropSize: const Size(800, 1200),
                            emptyLabelFontSize: 11,
                            emptyIconLabelGap: 9,
                            emptyBackgroundColor: Colors.transparent,
                            emptyIconColor:
                                context.genesisCreateColors.successText,
                            emptyLabelColor:
                                context.genesisCreateColors.successText,
                            dashColor: context.genesisCreateColors.text
                                .withValues(alpha: 0.28),
                            dashStrokeWidth: 1.5,
                            onChanged: _onFormChanged,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _BasicsFormNote(
                              note:
                                  'Used for cards and detail pages. Recommend ~768×1024 px. Supported formats: JPG, PNG, WEBP.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      const _AdvancedSettingsDivider(),
                      const SizedBox(height: 26),
                      const _BasicsSectionHeading(
                        'Worldo Settings - Hidden (Optional)',
                      ),
                      const SizedBox(height: 12),
                      _BasicsTextField(
                        label: '',
                        controller: _worldLogicController,
                        hintText:
                            'eg. The banker secretly controls who gets loans; whoever overextends can be squeezed out.',
                        maxLength: 1000,
                        note:
                            'The hidden rules and backstory that drive the story — agendas, mechanics, and secret limits.',
                        minLines: 3,
                        maxLines: 12,
                        minimumHeight: 88,
                        fieldPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        focusNode: _worldLogicFocusNode,
                        nextFocusNode: _worldStartTimeFocusNode,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 26),
                      const _BasicsSectionHeading('Worldo Time (Optional)'),
                      const SizedBox(height: 8),
                      const _BasicsFormNote(
                        note:
                            'This worldo starts at {Start Time}; each time the user taps *progress*, the timeline moves forward by {Time per Progress}.',
                        markdown: true,
                      ),
                      const SizedBox(height: 13),
                      const _SimulationFieldLabel('Start Time'),
                      const SizedBox(height: 7),
                      _BasicsTextField(
                        label: '',
                        controller: _worldStartTimeController,
                        hintText: 'eg. Day 1, 09:00 / 2026-01-01',
                        maxLength: 30,
                        showCounter: false,
                        maxLines: 1,
                        focusNode: _worldStartTimeFocusNode,
                        nextFocusNode: _timeProgressCustomFocusNode,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 14),
                      const _SimulationFieldLabel('Time per Progress'),
                      const SizedBox(height: 7),
                      _TimeProgressPicker(
                        selected: _selectedTimeProgress,
                        onSelected: _selectTimeProgress,
                      ),
                      const SizedBox(height: 8),
                      _BasicsTextField(
                        label: '',
                        controller: _timeProgressCustomController,
                        hintText: 'eg. 8 hours / 3 days',
                        maxLength: 10,
                        showCounter: false,
                        maxLines: 1,
                        minimumHeight: 38,
                        fieldPadding: const EdgeInsets.symmetric(
                          horizontal: 13,
                        ),
                        fieldBorderRadius: 11,
                        prefixGap: 9,
                        focusNode: _timeProgressCustomFocusNode,
                        nextFocusNode: _progressMetricFocusNode,
                        prefix: Text(
                          'Custom',
                          style: TextStyle(
                            color: context.genesisCreateColors.text.withValues(
                              alpha: 0.73,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onChanged: _handleTimeProgressCustomChanged,
                      ),
                      const SizedBox(height: 26),
                      const _BasicsSectionHeading('Worldo Metric (Optional)'),
                      const SizedBox(height: 8),
                      const _BasicsFormNote(
                        note:
                            "This worldo updates each character's {Metric Label} every progress, shown in {Unit}. Each character starts at {Starting}, and the value can move within {Delta Min}–{Delta Max}.",
                      ),
                      const SizedBox(height: 13),
                      const _SimulationFieldLabel('Metric Label'),
                      const SizedBox(height: 7),
                      _BasicsTextField(
                        label: '',
                        controller: _progressMetricController,
                        hintText: 'eg. Wealth / Goal Progress',
                        maxLength: 20,
                        showCounter: false,
                        maxLines: 1,
                        focusNode: _progressMetricFocusNode,
                        nextFocusNode: _labelNoteFocusNode,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 14),
                      const _SimulationFieldLabel('Label note'),
                      const SizedBox(height: 7),
                      _BasicsTextField(
                        label: '',
                        controller: _labelNoteController,
                        hintText: 'Describe what this metric measures',
                        maxLength: 50,
                        showCounter: false,
                        maxLines: 1,
                        focusNode: _labelNoteFocusNode,
                        nextFocusNode: _unitFocusNode,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 14),
                      const _SimulationFieldLabel('Unit'),
                      const SizedBox(height: 7),
                      _BasicsTextField(
                        label: '',
                        controller: _unitController,
                        hintText: 'eg. coins / %',
                        maxLength: 10,
                        showCounter: false,
                        maxLines: 1,
                        focusNode: _unitFocusNode,
                        nextFocusNode: _startingValueFocusNode,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 14),
                      const _SimulationFieldLabel('Value Range'),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: _BasicsTextField(
                              label: '',
                              controller: _startingValueController,
                              hintText: 'Starting',
                              maxLength: 10,
                              showCounter: false,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              focusNode: _startingValueFocusNode,
                              nextFocusNode: _minValueFocusNode,
                              onChanged: (_) => _onFormChanged(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BasicsTextField(
                              label: '',
                              controller: _minValueController,
                              hintText: 'Delta Min',
                              maxLength: 10,
                              showCounter: false,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              focusNode: _minValueFocusNode,
                              nextFocusNode: _maxValueFocusNode,
                              onChanged: (_) => _onFormChanged(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _BasicsTextField(
                              label: '',
                              controller: _maxValueController,
                              hintText: 'Delta Max',
                              maxLength: 10,
                              showCounter: false,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              focusNode: _maxValueFocusNode,
                              onChanged: (_) => _onFormChanged(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _KeyboardHiddenBottomAction(
                minimum: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  height: 44,
                  borderRadius: BorderRadius.circular(13),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  onPressed: _canUseSaveButton ? _onSave : null,
                  onDisabledPressed: () => _showError(_saveDisabledReason),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BasicsTextField extends StatelessWidget {
  const _BasicsTextField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.maxLength,
    this.showCounter = true,
    this.note,
    this.minLines = 1,
    this.maxLines,
    this.prefix,
    this.requiredIndicator = false,
    this.minimumHeight = 46,
    this.fieldPadding = const EdgeInsets.symmetric(horizontal: 14),
    this.fieldBorderRadius = 13,
    this.prefixGap = 8,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.nextFocusNode,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int? maxLength;
  final bool showCounter;
  final String? note;
  final int minLines;
  final int? maxLines;
  final Widget? prefix;
  final bool requiredIndicator;
  final double minimumHeight;
  final EdgeInsets fieldPadding;
  final double fieldBorderRadius;
  final double prefixGap;
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;

  @override
  Widget build(BuildContext context) {
    final textColor = context.genesisCreateColors.text;
    return CreateTextFieldBlock(
      label: label,
      controller: controller,
      hintText: hintText,
      onChanged: onChanged,
      maxLength: maxLength,
      showCounter: showCounter,
      note: note,
      minLines: minLines,
      maxLines: maxLines,
      prefix: prefix,
      requiredIndicator: requiredIndicator,
      // SPEC 5b: field labels are 700 14px.
      labelSize: 14,
      labelFontWeight: FontWeight.w700,
      labelInputGap: 8,
      fieldBorderRadius: fieldBorderRadius,
      fieldPadding: fieldPadding,
      minimumHeight: minimumHeight,
      inputFontSize: 13,
      hintFontSize: 13,
      inputLineHeight: 1.55,
      textAlign: textAlign,
      prefixGap: prefixGap,
      supportLineGap: 7,
      supportItemGap: 12,
      supportTextStyle: const TextStyle(fontSize: 11, height: 1.5),
      supportTextColor: textColor.withValues(alpha: 0.62),
      supportIconColor: textColor.withValues(alpha: 0.45),
      supportIconSize: 12,
      supportIconGap: 7,
      counterTextStyle: TextStyle(
        color: textColor.withValues(alpha: 0.5),
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
      focusNode: focusNode,
      nextFocusNode: nextFocusNode,
    );
  }
}

class _BasicsFormNote extends StatelessWidget {
  const _BasicsFormNote({required this.note, this.markdown = false});

  final String note;
  final bool markdown;

  @override
  Widget build(BuildContext context) {
    final textColor = context.genesisCreateColors.text;
    return CreateFormNote(
      note: note,
      markdown: markdown,
      textStyle: const TextStyle(fontSize: 11, height: 1.5),
      textColor: textColor.withValues(alpha: 0.62),
      iconColor: textColor.withValues(alpha: 0.45),
      iconSize: 12,
      iconGap: 7,
    );
  }
}

class _BasicsFieldLabel extends StatelessWidget {
  const _BasicsFieldLabel(this.text, {this.requiredIndicator = false});

  final String text;
  final bool requiredIndicator;

  @override
  Widget build(BuildContext context) {
    return GenesisFieldLabel(
      text: text,
      requiredIndicator: requiredIndicator,
      requiredColor: context.genesisCreateColors.accent,
      style: TextStyle(
        color: context.genesisCreateColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    );
  }
}

class _BasicsSectionHeading extends StatelessWidget {
  const _BasicsSectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GenesisTypography.sectionTitle.copyWith(
        color: context.genesisCreateColors.text,
      ),
    );
  }
}

class _AdvancedSettingsDivider extends StatelessWidget {
  const _AdvancedSettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            height: 1,
            color: context.genesisCreateColors.text.withValues(alpha: 0.14),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11),
          child: Text(
            'Advanced Settings (Optional)',
            style: TextStyle(
              color: context.genesisCreateColors.text.withValues(alpha: 0.56),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            height: 1,
            color: context.genesisCreateColors.text.withValues(alpha: 0.14),
          ),
        ),
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
      style: TextStyle(
        color: context.genesisCreateColors.text.withValues(alpha: 0.73),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }
}

class _TimeProgressPicker extends StatelessWidget {
  const _TimeProgressPicker({required this.selected, required this.onSelected});

  static const List<String> _options = <String>[
    '6 hours',
    '12 hours',
    '1 day',
    '1 week',
  ];

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var row = 0; row < 2; row += 1) ...[
          Row(
            children: [
              for (var column = 0; column < 2; column += 1) ...[
                if (column > 0) const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: _TimeProgressOption(
                      label: _options[row * 2 + column],
                      selected: _options[row * 2 + column] == selected,
                      onTap: () {
                        final option = _options[row * 2 + column];
                        onSelected(option == selected ? '' : option);
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (row == 0) const SizedBox(height: 8),
        ],
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
      key: ValueKey('time-progress-option-$label'),
      color: selected
          ? context.genesisCreateColors.selectedOptionSurface
          : context.genesisCreateColors.fieldFill,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected
                  ? context.genesisCreateColors.selectedOptionText
                  : context.genesisCreateColors.text.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
