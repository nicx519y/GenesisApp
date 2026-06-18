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
        originName: _originNameController.text.trim(),
        worldView: _worldViewController.text.trim(),
        worldLogic: _worldLogicController.text.trim(),
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
      'label': _progressMetricController.text.trim(),
      'label_note': _labelNoteController.text.trim(),
      'unit': _unitController.text.trim(),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'Basics'),
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
                            fontWeight: FontWeight.w600,
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
                        maxLength: 300,
                        minLines: 4,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Cover Image *',
                        style: TextStyle(
                          color: createFormText,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                            cropSize: const Size(800, 1200),
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
                          fontWeight: FontWeight.w600,
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
                        onSelected: _selectTimeProgress,
                      ),
                      const SizedBox(height: 10),
                      CreateTextFieldBlock(
                        label: '',
                        controller: _timeProgressCustomController,
                        hintText: 'Custom, e.g. 3 days',
                        maxLines: 1,
                        onChanged: _handleTimeProgressCustomChanged,
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
                      const _SimulationFieldLabel('Label note'),
                      const SizedBox(height: 10),
                      CreateTextFieldBlock(
                        label: '',
                        controller: _labelNoteController,
                        hintText: 'Describe what this metric measures',
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
                  onPressed: _canUseSaveButton ? _onSave : null,
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
              fontWeight: FontWeight.w600,
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
    '6 hours',
    '12 hours',
    '1 day',
    '1 week',
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
      key: ValueKey('time-progress-option-$label'),
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
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
