part of 'origin_editor_pages.dart';

class OriginStoryEventsEditorPage extends StatefulWidget {
  const OriginStoryEventsEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginStoryEventsEditorPage> createState() =>
      _OriginStoryEventsEditorPageState();
}

class _OriginStoryEventsEditorPageState
    extends State<OriginStoryEventsEditorPage> {
  static const int _maxEvents = 10;
  final List<TextEditingController> _eventControllers =
      <TextEditingController>[];
  final List<FocusNode> _eventFocusNodes = <FocusNode>[];

  bool _isSaving = false;

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
      _eventFocusNodes.add(FocusNode());
    }
    if (!mounted) return;
    setState(() {});
  }

  void _addEvent() {
    if (_eventControllers.length >= _maxEvents) {
      _showError('You can add up to $_maxEvents events.');
      return;
    }
    setState(() {
      _eventControllers.add(TextEditingController());
      _eventFocusNodes.add(FocusNode());
    });
    _onFormChanged();
  }

  void _requestRemoveEvent(int index) {
    _removeEvent(index);
  }

  void _removeEvent(int index) {
    if (_eventControllers.length <= 1) {
      _eventControllers[index].clear();
    } else {
      final controller = _eventControllers.removeAt(index);
      final focusNode = _eventFocusNodes.removeAt(index);
      controller.dispose();
      focusNode.dispose();
    }
    _onFormChanged();
  }

  void _onFormChanged() {
    setState(() {});
  }

  List<StoryEventDraft> _snapshotEvents() {
    return _eventControllers
        .map(
          (controller) => StoryEventDraft(
            event: normalizeGenesisUgcTextForDisplay(controller.text),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _saveEvents() async {
    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    final events = _snapshotEvents()
        .where((item) => item.event.trim().isNotEmpty)
        .toList(growable: false);

    await widget.repository.saveFinalDraft(
      draft.copyWith(storyEvents: events, storyEventsSaved: events.isNotEmpty),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  bool get _canUseSaveButton {
    return !_isSaving;
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  @override
  void dispose() {
    for (final controller in _eventControllers) {
      controller.dispose();
    }
    for (final focusNode in _eventFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'Story Events'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_eventControllers.length}/$_maxEvents (Added / Max)',
                          style: const TextStyle(
                            color: createFormText,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (int i = 0; i < _eventControllers.length; i++) ...[
                        _StoryEventCard(
                          index: i + 1,
                          controller: _eventControllers[i],
                          focusNode: _eventFocusNodes[i],
                          nextFocusNode: i + 1 < _eventFocusNodes.length
                              ? _eventFocusNodes[i + 1]
                              : null,
                          onChanged: _onFormChanged,
                          onDelete: () {
                            _requestRemoveEvent(i);
                          },
                        ),
                        if (i + 1 < _eventControllers.length)
                          const SizedBox(height: 12),
                      ],
                      if (_eventControllers.isNotEmpty)
                        const SizedBox(height: 12),
                      CreateInlineAddButton(
                        label: '+ Add Event',
                        onTap: _addEvent,
                        fontSize: 16,
                        centered: true,
                        contentPadding: const EdgeInsets.fromLTRB(0, 11, 0, 5),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              _KeyboardHiddenBottomAction(
                minimum: const EdgeInsets.fromLTRB(28, 8, 28, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  width: _primaryActionButtonWidth(context),
                  onPressed: _canUseSaveButton ? _saveEvents : null,
                  onDisabledPressed: () =>
                      _showError('Saving is already in progress.'),
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
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.completed,
    required this.onTap,
    this.modified = false,
    this.summaryWrap = false,
    this.showDivider = true,
  });

  final String? icon;
  final String title;
  final String summary;
  final bool completed;
  final VoidCallback? onTap;
  final bool modified;
  final bool summaryWrap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  key: ValueKey<String>('section-icon-$title'),
                  width: 24,
                  height: 24,
                  child: icon == null
                      ? null
                      : SvgPicture.asset(icon!, fit: BoxFit.contain),
                ),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                summaryWrap
                                    ? Text(
                                        _summarySingleLine,
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(
                                          color: Color(0xFF666666),
                                          fontSize: 12,
                                          height: 1.4,
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (final line in _summaryLines)
                                            Text(
                                              line,
                                              textAlign: TextAlign.left,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              softWrap: false,
                                              style: const TextStyle(
                                                color: Color(0xFF666666),
                                                fontSize: 12,
                                                height: 1.4,
                                              ),
                                            ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (modified) ...[
                            _ModifiedSectionBadge(
                              key: ValueKey('section-modified-$title'),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (completed)
                            const Text(
                              '✓',
                              style: TextStyle(
                                color: Color(0xFF1C7D56),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1,
                              ),
                            ),
                          if (onTap != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF666666),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            const Divider(height: 1, thickness: 1, color: Color(0xFFEAEAEA)),
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

  String get _summarySingleLine {
    return summary.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _ModifiedSectionBadge extends StatelessWidget {
  const _ModifiedSectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: SvgPicture.asset(refreshModifiedIconAsset, fit: BoxFit.contain),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.index,
    required this.form,
    required this.nextFocusNode,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final OriginCharacterForm form;
  final FocusNode? nextFocusNode;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Character $index',
      onDelete: onDelete,
      showBorder: false,
      child: OriginCharacterFormFields(
        form: form,
        onChanged: onChanged,
        showFieldNotes: true,
        labelFontWeight: FontWeight.w400,
        nextFocusNode: nextFocusNode,
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    super.key,
    required this.index,
    this.title,
    required this.form,
    required this.nextFocusNode,
    required this.characters,
    required this.onChanged,
    required this.onPickCharacters,
    required this.onRemoveCharacter,
    required this.onDelete,
    this.deleteEnabled = true,
    this.onDeleteDisabled,
    this.showHeader = true,
    this.showBorder = true,
    this.titleFontSize = 16,
    this.titleSuffix,
    this.nameFieldLabel = 'Location Name *',
    this.fieldLabelFontWeight = FontWeight.w600,
    this.availableCharacters,
    this.onAddCharacter,
  });

  final int index;
  final String? title;
  final _LocationForm form;
  final FocusNode? nextFocusNode;
  final List<CharacterDraft> characters;
  final VoidCallback onChanged;
  final VoidCallback onPickCharacters;
  final ValueChanged<String> onRemoveCharacter;
  final VoidCallback onDelete;
  final bool deleteEnabled;
  final VoidCallback? onDeleteDisabled;
  final bool showHeader;
  final bool showBorder;
  final double titleFontSize;
  final String? titleSuffix;
  final String nameFieldLabel;
  final FontWeight fieldLabelFontWeight;
  final List<CharacterDraft>? availableCharacters;
  final ValueChanged<String>? onAddCharacter;

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CreateUploadBox(
              controller: form.imageUrl,
              label: 'IMAGE\n(Optional)',
              width: 96,
              height: 144,
              iconSize: 36,
              cropSize: const Size(1500, 3000),
              emptyIconLabelGap: 8,
              onChanged: onChanged,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CreateTextFieldBlock(
                label: nameFieldLabel,
                controller: form.name,
                hintText: 'eg. Main Street',
                maxLength: 25,
                maxLines: 1,
                labelFontWeight: fieldLabelFontWeight,
                labelInputGap: 8,
                focusNode: form.nameFocusNode,
                nextFocusNode: nextFocusNode,
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _InitialCharactersField(
          form: form,
          characters: characters,
          labelFontWeight: fieldLabelFontWeight,
          onPickCharacters: onPickCharacters,
          onRemoveCharacter: onRemoveCharacter,
          availableCharacters: availableCharacters,
          onAddCharacter: onAddCharacter,
        ),
      ],
    );
    if (!showHeader) return fields;
    return CreateFormCard(
      title: title ?? 'Location $index',
      onDelete: onDelete,
      deleteEnabled: deleteEnabled,
      onDeleteDisabled: onDeleteDisabled,
      showBorder: showBorder,
      titleFontSize: titleFontSize,
      titleSuffix: titleSuffix,
      child: fields,
    );
  }
}

class _InitialCharactersField extends StatelessWidget {
  const _InitialCharactersField({
    required this.form,
    required this.characters,
    required this.labelFontWeight,
    required this.onPickCharacters,
    required this.onRemoveCharacter,
    this.availableCharacters,
    this.onAddCharacter,
  });

  final _LocationForm form;
  final List<CharacterDraft> characters;
  final FontWeight labelFontWeight;
  final VoidCallback onPickCharacters;
  final ValueChanged<String> onRemoveCharacter;
  final List<CharacterDraft>? availableCharacters;
  final ValueChanged<String>? onAddCharacter;

  @override
  Widget build(BuildContext context) {
    final selectedCharacters = _selectedCharacters;
    final usesInlineSelection = availableCharacters != null;
    final selectionField = Container(
      key: usesInlineSelection
          ? const ValueKey('location-character-selection')
          : null,
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: createFormFieldFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leftPadding = selectedCharacters.isEmpty ? 12.0 : 4.0;
          final trailingWidth = usesInlineSelection ? 0.0 : 46.0;
          final chipAreaWidth =
              constraints.maxWidth - leftPadding - trailingWidth;
          final chipsWrap = _chipsWillWrap(
            context,
            selectedCharacters,
            chipAreaWidth <= 0 ? 0 : chipAreaWidth,
          );
          final contentPadding = chipsWrap
              ? EdgeInsets.fromLTRB(leftPadding, 6, 4, 6)
              : EdgeInsets.fromLTRB(leftPadding, 4, 4, 4);
          return Padding(
            padding: contentPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: selectedCharacters.isEmpty
                      ? SizedBox(
                          height: 32,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              usesInlineSelection
                                  ? 'Select from available characters below'
                                  : 'Select initial characters',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: createFormHint,
                                fontSize: 14,
                                height: 1.2,
                              ),
                            ),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 32),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 3,
                              runSpacing: 3,
                              children: [
                                for (final character in selectedCharacters)
                                  _InitialCharacterChip(
                                    characterId: character.charId.trim(),
                                    name: character.name.trim(),
                                    onRemove: onRemoveCharacter,
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
                if (!usesInlineSelection) ...[
                  const SizedBox(width: 4),
                  const SizedBox(
                    width: 38,
                    height: 32,
                    child: Icon(Icons.add, color: createFormGreen, size: 28),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Initial Characters (Optional)',
          style: TextStyle(
            color: createFormText,
            fontSize: 14,
            fontWeight: labelFontWeight,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        if (usesInlineSelection)
          selectionField
        else
          GestureDetector(
            key: const ValueKey('location-character-picker'),
            behavior: HitTestBehavior.opaque,
            onTap: onPickCharacters,
            child: selectionField,
          ),
        const SizedBox(height: 8),
        const CreateFormNote(
          note: 'The characters who start here when the worldo begins.',
        ),
        if (usesInlineSelection) ...[
          const SizedBox(height: 14),
          Align(
            key: const ValueKey('available-initial-characters-label'),
            alignment: Alignment.center,
            child: Text(
              'Available to select',
              style: TextStyle(
                color: createFormText,
                fontSize: 14,
                height: 1.2,
                fontWeight: labelFontWeight,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (availableCharacters!.isEmpty)
            const Text(
              'No characters available.',
              style: TextStyle(
                color: createFormMuted,
                fontSize: 12,
                height: 1.2,
              ),
            )
          else
            Wrap(
              key: const ValueKey('available-initial-characters'),
              direction: Axis.horizontal,
              alignment: WrapAlignment.start,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final character in availableCharacters!)
                  _AvailableInitialCharacterChip(
                    characterId: character.charId.trim(),
                    avatarUrl: character.avatarUrl.trim(),
                    name: character.name.trim(),
                    onAdd: onAddCharacter!,
                  ),
              ],
            ),
        ],
      ],
    );
  }

  bool _chipsWillWrap(
    BuildContext context,
    List<CharacterDraft> selectedCharacters,
    double maxWidth,
  ) {
    if (selectedCharacters.length <= 1 || maxWidth <= 0) return false;
    double lineWidth = 0;
    for (final character in selectedCharacters) {
      final chipWidth = _estimatedChipWidth(context, character.name.trim());
      if (lineWidth == 0) {
        lineWidth = chipWidth;
      } else if (lineWidth + 3 + chipWidth > maxWidth) {
        return true;
      } else {
        lineWidth += 3 + chipWidth;
      }
    }
    return false;
  }

  double _estimatedChipWidth(BuildContext context, String name) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    return (textPainter.width + 38).clamp(0.0, 180.0).toDouble();
  }

  List<CharacterDraft> get _selectedCharacters {
    final byId = {for (final item in characters) item.charId.trim(): item};
    return form.selectedCharacterIds
        .map((id) => byId[id])
        .whereType<CharacterDraft>()
        .where((item) => item.name.trim().isNotEmpty)
        .toList(growable: false);
  }
}

class _AvailableInitialCharacterChip extends StatelessWidget {
  const _AvailableInitialCharacterChip({
    required this.characterId,
    required this.avatarUrl,
    required this.name,
    required this.onAdd,
  });

  final String characterId;
  final String avatarUrl;
  final String name;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('available-initial-character-$characterId'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onAdd(characterId),
      child: Container(
        height: 32,
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD9E5DF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GenesisCharacterAvatar(
              url: avatarUrl,
              name: name,
              size: 20,
              borderRadius: GenesisAvatarRadii.character,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: createFormText,
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitialCharacterChip extends StatelessWidget {
  const _InitialCharacterChip({
    required this.characterId,
    required this.name,
    required this.onRemove,
  });

  final String characterId;
  final String name;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('initial-character-chip-remove-$characterId'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onRemove(characterId),
      child: Container(
        key: ValueKey('initial-character-chip-$characterId'),
        constraints: const BoxConstraints(maxWidth: 180),
        height: 32,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD9E5DF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: createFormText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 1),
            const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.close, size: 14, color: createFormMuted),
            ),
          ],
        ),
      ),
    );
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

class _CharacterPickerSheetState extends State<_CharacterPickerSheet> {
  late final Set<String> _selectedIds = <String>{...widget.initialSelectedIds};

  @override
  Widget build(BuildContext context) {
    return GenesisBottomSheetPanel(
      title: 'Select Characters',
      height: MediaQuery.sizeOf(context).height * 0.58,
      trailing: GenesisBottomSheetCloseButton(
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 116,
                crossAxisSpacing: 8,
                mainAxisSpacing: 2,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 82,
            height: 82,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GenesisCharacterAvatar(
                  url: character.avatarUrl.trim(),
                  name: character.name,
                  size: 82,
                  borderRadius: GenesisAvatarRadii.character,
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: selected ? GenesisColors.brand : Colors.white10,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 5,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Text(
            character.name.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.1,
              fontWeight: FontWeight.w400,
              color: Color(0xFF111111),
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
    required this.level,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.selectedCharacterIds,
  });

  factory _LocationForm.empty({required String locationId}) {
    return _LocationForm(
      locationId: locationId,
      parentLocationId: '',
      level: 0,
      imageUrl: TextEditingController(),
      name: TextEditingController(),
      description: TextEditingController(),
      selectedCharacterIds: <String>[],
    );
  }

  factory _LocationForm.treeLeaf({
    required String locationId,
    required String parentLocationId,
    LocationDraft? draft,
  }) {
    return _LocationForm(
      locationId: locationId,
      parentLocationId: parentLocationId,
      level: 3,
      imageUrl: TextEditingController(text: draft?.imageUrl ?? ''),
      name: TextEditingController(text: draft?.name ?? ''),
      description: TextEditingController(text: draft?.description ?? ''),
      selectedCharacterIds:
          draft?.initialCharacterIds.toList(growable: true) ?? <String>[],
    );
  }

  factory _LocationForm.fromDraft(LocationDraft draft, {required String uid}) {
    return _LocationForm(
      locationId: draft.locationId.trim().isEmpty
          ? createUidTimestampHashId(uid: uid, prefix: 'location')
          : draft.locationId.trim(),
      parentLocationId: draft.parentLocationId,
      level: draft.level,
      imageUrl: TextEditingController(text: draft.imageUrl),
      name: TextEditingController(text: draft.name),
      description: TextEditingController(text: draft.description),
      selectedCharacterIds: draft.initialCharacterIds,
    );
  }

  factory _LocationForm.copyOf(_LocationForm source) {
    return _LocationForm(
      locationId: source.locationId,
      parentLocationId: source.parentLocationId,
      level: source.level,
      imageUrl: TextEditingController(text: source.imageUrl.text),
      name: TextEditingController(text: source.name.text),
      description: TextEditingController(text: source.description.text),
      selectedCharacterIds: source.selectedCharacterIds.toList(growable: true),
    );
  }

  final String locationId;
  final String parentLocationId;
  final int level;
  final TextEditingController imageUrl;
  final TextEditingController name;
  final TextEditingController description;
  final FocusNode nameFocusNode = FocusNode();
  List<String> selectedCharacterIds;

  void applyValuesFrom(_LocationForm source) {
    imageUrl.text = source.imageUrl.text;
    name.text = source.name.text;
    description.text = source.description.text;
    selectedCharacterIds = source.selectedCharacterIds.toList(growable: true);
  }

  void dispose() {
    imageUrl.dispose();
    name.dispose();
    description.dispose();
    nameFocusNode.dispose();
  }

  bool get hasContent {
    return [
          imageUrl,
          name,
          description,
        ].any((controller) => controller.text.trim().isNotEmpty) ||
        selectedCharacterIds.isNotEmpty;
  }

  void clear() {
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
    required this.focusNode,
    required this.nextFocusNode,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Event $index',
      onDelete: onDelete,
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          CreateTextFieldBlock(
            label: '',
            controller: controller,
            hintText:
                'eg. A national chain scouts a vacant lot, threatening to undercut every local on price.',
            maxLength: 100,
            note: 'A key story beat the AI uses to steer the storyline.',
            minLines: 5,
            maxLines: 5,
            labelSize: 0,
            focusNode: focusNode,
            nextFocusNode: nextFocusNode,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
