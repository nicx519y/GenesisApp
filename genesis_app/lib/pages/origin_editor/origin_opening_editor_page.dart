part of 'origin_editor_pages.dart';

class OriginOpeningEditorPage extends StatefulWidget {
  const OriginOpeningEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginOpeningEditorPage> createState() =>
      _OriginOpeningEditorPageState();
}

class _OriginOpeningEditorPageState extends State<OriginOpeningEditorPage> {
  List<_OpeningLocationOption> _options = const <_OpeningLocationOption>[];
  final List<_OpeningDialogueItem> _dialogueItems = <_OpeningDialogueItem>[];
  _OpeningLocationOption? _selectedOption;
  int _nextDialogueItemId = 0;
  bool _loading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final draft = await widget.repository.loadDraft();
    final charactersById = <String, CharacterDraft>{
      for (final character in draft.characters)
        if (character.charId.trim().isNotEmpty)
          character.charId.trim(): character,
    };
    final options = draft.locations
        .where(
          (location) => location.name.trim().isNotEmpty && location.level == 3,
        )
        .map(
          (location) => _OpeningLocationOption(
            location: location,
            characters: location.initialCharacterIds
                .map((characterId) => charactersById[characterId.trim()])
                .whereType<CharacterDraft>()
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
    _OpeningLocationOption? selectedOption;
    final savedLocationId = draft.opening.locationId.trim();
    if (draft.openingSaved && savedLocationId.isNotEmpty) {
      for (final option in options) {
        if (option.id == savedLocationId) {
          selectedOption = option;
          break;
        }
      }
    }
    final restoredItems = <_OpeningDialogueItem>[];
    if (selectedOption != null) {
      for (final savedItem in draft.opening.dialogue) {
        final type = _openingDialogueTypeFromDraft(savedItem.type);
        if (type == null) continue;
        final character = type == _OpeningDialogueType.character
            ? charactersById[savedItem.characterId.trim()]
            : null;
        if (type == _OpeningDialogueType.character && character == null) {
          continue;
        }
        restoredItems.add(
          _OpeningDialogueItem(
            id: 'opening-dialogue-${_nextDialogueItemId++}',
            type: type,
            character: character,
            initialContent: savedItem.content,
          ),
        );
      }
    }
    if (!mounted) {
      for (final item in restoredItems) {
        item.dispose();
      }
      return;
    }
    setState(() {
      _options = options;
      _selectedOption = selectedOption;
      _dialogueItems.addAll(restoredItems);
      _loading = false;
    });
  }

  Future<void> _selectLocation() async {
    if (_loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_dialogueItems.any((item) => item.hasContent)) {
      final shouldContinue = await showGenesisActionBox<bool>(
        context: context,
        title: 'Switching locations will clear the dialogue content.',
        actions: const [
          GenesisActionBoxAction<bool>(label: 'Continue', value: true),
        ],
        cancelLabel: 'Cancel',
      );
      if (!mounted || shouldContinue != true) return;
    }
    final selected = await showGenesisModalBottomSheet<_OpeningLocationOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OpeningLocationPickerSheet(
        options: _options,
        initialSelection: _selectedOption,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (_selectedOption?.id != selected.id) {
        _clearDialogueItems();
      }
      _selectedOption = selected;
    });
  }

  void _addNarrator() {
    _addDialogueItem(_OpeningDialogueType.narrator);
  }

  void _addCharacter(CharacterDraft character) {
    _addDialogueItem(_OpeningDialogueType.character, character: character);
  }

  void _addImage() {
    _addDialogueItem(_OpeningDialogueType.image);
  }

  void _addDialogueItem(
    _OpeningDialogueType type, {
    CharacterDraft? character,
  }) {
    setState(() {
      _dialogueItems.add(
        _OpeningDialogueItem(
          id: 'opening-dialogue-${_nextDialogueItemId++}',
          type: type,
          character: character,
        ),
      );
    });
  }

  void _clearDialogueItems() {
    for (final item in _dialogueItems) {
      item.dispose();
    }
    _dialogueItems.clear();
  }

  void _removeDialogueItem(_OpeningDialogueItem item) {
    setState(() {
      if (_dialogueItems.remove(item)) {
        item.dispose();
      }
    });
  }

  bool get _canSave {
    if (_selectedOption == null || _dialogueItems.isEmpty) return false;
    return _dialogueItems.every((item) => item.hasContent);
  }

  String get _saveDisabledReason {
    if (_isSaving) return 'Saving is already in progress.';
    if (_selectedOption == null) {
      return 'Select an initial location before saving.';
    }
    if (_dialogueItems.isEmpty) {
      return 'Add at least one dialogue item before saving.';
    }
    if (_dialogueItems.any((item) => !item.hasContent)) {
      return 'Complete every dialogue item before saving.';
    }
    return 'Complete all required fields before saving.';
  }

  Future<void> _save() async {
    if (!_canSave || _isSaving) return;
    final selected = _selectedOption!;
    setState(() => _isSaving = true);
    try {
      final draft = await widget.repository.loadDraft();
      final opening = OpeningDraft(
        locationId: selected.id,
        locationName: selected.location.name.trim(),
        dialogue: _dialogueItems
            .map((item) => item.toDraft())
            .toList(growable: false),
      );
      await widget.repository.saveFinalDraft(
        draft.copyWith(opening: opening, openingSaved: true),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showGenesisToast(context, 'Unable to save Opening.');
    }
  }

  @override
  void dispose() {
    _clearDialogueItems();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedOption;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'Opening'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    10,
                    _fieldLabelInputGap,
                    10,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select initial location',
                              key: ValueKey<String>('opening-location-title'),
                              style: TextStyle(
                                color: createFormText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: _fieldLabelInputGap),
                            _OpeningLocationField(
                              loading: _loading,
                              locationName:
                                  selected?.location.name.trim() ?? '',
                              onTap: _selectLocation,
                            ),
                            if (selected != null &&
                                selected.characterNames.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _OpeningInitialCharacters(
                                names: selected.characterNames,
                              ),
                            ],
                            const SizedBox(height: _fieldGroupGap),
                            const Text(
                              'Opening dialogue',
                              key: ValueKey<String>('opening-dialogue-title'),
                              style: TextStyle(
                                color: createFormText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(
                              height: selected == null
                                  ? _fieldLabelInputGap
                                  : 20,
                            ),
                            if (selected == null)
                              const CreateFormNote(
                                key: ValueKey<String>('opening-location-note'),
                                note:
                                    'Select a location first, then edit the dialogue.',
                              ),
                          ],
                        ),
                      ),
                      if (selected != null)
                        _OpeningDialogueEditor(
                          items: _dialogueItems,
                          characters: selected.characters,
                          onAddNarrator: _addNarrator,
                          onAddCharacter: _addCharacter,
                          onAddImage: _addImage,
                          onDelete: _removeDialogueItem,
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  ),
                ),
              ),
              _KeyboardHiddenBottomAction(
                minimum: const EdgeInsets.fromLTRB(28, 8, 28, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  width: _primaryActionButtonWidth(context),
                  onPressed: _canSave && !_isSaving ? _save : null,
                  onDisabledPressed: () =>
                      showGenesisToast(context, _saveDisabledReason),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
