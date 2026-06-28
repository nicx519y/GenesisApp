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
    }
    if (!mounted) return;
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

  void _requestRemoveEvent(int index) {
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
    setState(() {});
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
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
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
                  width: _primaryActionButtonWidth(context),
                  onPressed: _canUseSaveButton ? _saveEvents : null,
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
    this.modified = false,
    this.summaryWrap = false,
    this.showDivider = true,
  });

  final String icon;
  final String title;
  final String summary;
  final bool completed;
  final VoidCallback onTap;
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
                  width: 24,
                  height: 24,
                  child: SvgPicture.asset(icon, fit: BoxFit.contain),
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
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF666666),
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
      child: OriginCharacterFormFields(
        form: form,
        onChanged: onChanged,
        showFieldNotes: true,
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.index,
    required this.form,
    required this.characters,
    required this.onChanged,
    required this.onPickCharacters,
    required this.onRemoveCharacter,
    required this.onDelete,
  });

  final int index;
  final _LocationForm form;
  final List<CharacterDraft> characters;
  final VoidCallback onChanged;
  final VoidCallback onPickCharacters;
  final ValueChanged<String> onRemoveCharacter;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Location $index',
      onDelete: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreateUploadBox(
                controller: form.imageUrl,
                label: 'IMAGE\n(Optional)',
                width: 96,
                height: 144,
                iconSize: 36,
                cropSize: const Size(800, 1200),
                emptyIconLabelGap: 8,
                onChanged: onChanged,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CreateTextFieldBlock(
                  label: 'Location Name *',
                  controller: form.name,
                  hintText: 'eg. Main Street',
                  maxLength: 25,
                  maxLines: 1,
                  labelInputGap: 8,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CreateTextFieldBlock(
            label: 'Description (Optional)',
            controller: form.description,
            hintText: 'eg. The half-empty main drag where every deal goes down',
            maxLength: 100,
            note: "A short description shown in the worldo's location list.",
            minLines: 3,
            labelInputGap: 8,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          _InitialCharactersField(
            form: form,
            characters: characters,
            onPickCharacters: onPickCharacters,
            onRemoveCharacter: onRemoveCharacter,
          ),
        ],
      ),
    );
  }
}

class _InitialCharactersField extends StatelessWidget {
  const _InitialCharactersField({
    required this.form,
    required this.characters,
    required this.onPickCharacters,
    required this.onRemoveCharacter,
  });

  final _LocationForm form;
  final List<CharacterDraft> characters;
  final VoidCallback onPickCharacters;
  final ValueChanged<String> onRemoveCharacter;

  @override
  Widget build(BuildContext context) {
    final selectedCharacters = _selectedCharacters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Initial Characters (Optional)',
          style: TextStyle(
            color: createFormText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          key: const ValueKey('location-character-picker'),
          behavior: HitTestBehavior.opaque,
          onTap: onPickCharacters,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            decoration: BoxDecoration(
              color: createFormFieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chipAreaWidth = constraints.maxWidth - 58;
                final chipsWrap = _chipsWillWrap(
                  context,
                  selectedCharacters,
                  chipAreaWidth <= 0 ? 0 : chipAreaWidth,
                );
                final contentPadding = chipsWrap
                    ? const EdgeInsets.fromLTRB(12, 12, 4, 12)
                    : const EdgeInsets.fromLTRB(12, 3, 4, 3);
                return Padding(
                  padding: contentPadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: selectedCharacters.isEmpty
                            ? const SizedBox(
                                height: 48,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Select initial characters',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: createFormHint,
                                      fontSize: 14,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              )
                            : ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: chipsWrap ? 30 : 48,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Wrap(
                                    spacing: 3,
                                    runSpacing: 3,
                                    children: [
                                      for (final character
                                          in selectedCharacters)
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
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: onPickCharacters,
                        icon: const Icon(
                          Icons.add,
                          color: createFormGreen,
                          size: 32,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 48,
                        ),
                        splashRadius: 22,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        const CreateFormNote(
          note: 'The characters who start here when the worldo begins.',
        ),
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
            const SizedBox(width: 4),
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
      titleBottomSpacing: 8,
      trailing: Transform.translate(
        offset: const Offset(0, -3),
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, size: 22, color: Color(0xFF666666)),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        ),
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
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.selectedCharacterIds,
  });

  factory _LocationForm.empty({required String locationId}) {
    return _LocationForm(
      locationId: locationId,
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
      imageUrl: TextEditingController(text: draft.imageUrl),
      name: TextEditingController(text: draft.name),
      description: TextEditingController(text: draft.description),
      selectedCharacterIds: draft.initialCharacterIds,
    );
  }

  final String locationId;
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
          const SizedBox(height: 6),
          CreateTextFieldBlock(
            label: '',
            controller: controller,
            hintText:
                'eg. A national chain scouts a vacant lot, threatening to undercut every local on price.',
            maxLength: 100,
            note: 'A key story beat the AI uses to steer the storyline.',
            minLines: 5,
            labelSize: 0,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
