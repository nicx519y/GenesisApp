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
        .where((location) => location.name.trim().isNotEmpty)
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
                        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningLocationField extends StatelessWidget {
  const _OpeningLocationField({
    required this.loading,
    required this.locationName,
    required this.onTap,
  });

  final bool loading;
  final String locationName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Select initial location',
      child: InkWell(
        key: const ValueKey<String>('opening-location-field'),
        borderRadius: BorderRadius.circular(8),
        onTap: loading ? null : onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: createFormFieldFill,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  locationName.isEmpty
                      ? loading
                            ? 'Loading locations...'
                            : 'Select initial location'
                      : locationName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: locationName.isEmpty
                        ? createFormHint
                        : createFormText,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: createFormMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningInitialCharacters extends StatelessWidget {
  const _OpeningInitialCharacters({required this.names});

  final String names;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('opening-initial-characters'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(characterStatIconAsset, width: 14, height: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            names,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: createFormText,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _OpeningDialogueEditor extends StatelessWidget {
  const _OpeningDialogueEditor({
    required this.items,
    required this.characters,
    required this.onAddNarrator,
    required this.onAddCharacter,
    required this.onAddImage,
    required this.onDelete,
    required this.onChanged,
  });

  final List<_OpeningDialogueItem> items;
  final List<CharacterDraft> characters;
  final VoidCallback onAddNarrator;
  final ValueChanged<CharacterDraft> onAddCharacter;
  final VoidCallback onAddImage;
  final ValueChanged<_OpeningDialogueItem> onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final style = kLocationChatStyle;
    final namedCharacters = characters
        .where((character) => character.name.trim().isNotEmpty)
        .toList(growable: false);
    return Container(
      key: const ValueKey<String>('opening-dialogue-editor'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int index = 0; index < items.length; index++) ...[
            _OpeningDialogueContentEditor(
              item: items[index],
              style: style,
              onDelete: () => onDelete(items[index]),
              onChanged: onChanged,
            ),
            const SizedBox(height: 14),
          ],
          Column(
            key: const ValueKey<String>('opening-dialogue-add-buttons'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (namedCharacters.isNotEmpty) ...[
                Wrap(
                  key: const ValueKey<String>(
                    'opening-dialogue-character-buttons',
                  ),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final character in namedCharacters)
                      _OpeningDialogueAddButton(
                        key: ValueKey<String>(
                          'opening-add-character-${character.charId.trim()}',
                        ),
                        label: character.name.trim(),
                        leading: SvgPicture.asset(
                          characterStatIconAsset,
                          width: 14,
                          height: 14,
                        ),
                        onTap: () => onAddCharacter(character),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                key: const ValueKey<String>('opening-dialogue-media-buttons'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  _OpeningDialogueAddButton(
                    key: const ValueKey<String>('opening-add-narrator'),
                    label: 'Narrator',
                    leading: SvgPicture.asset(
                      paragraphIconAsset,
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        createFormText,
                        BlendMode.srcIn,
                      ),
                    ),
                    onTap: onAddNarrator,
                  ),
                  _OpeningDialogueAddButton(
                    key: const ValueKey<String>('opening-add-image'),
                    label: 'Image',
                    leading: const Icon(
                      Icons.image_outlined,
                      color: createFormText,
                      size: 16,
                    ),
                    onTap: onAddImage,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OpeningDialogueContentEditor extends StatelessWidget {
  const _OpeningDialogueContentEditor({
    required this.item,
    required this.style,
    required this.onDelete,
    required this.onChanged,
  });

  final _OpeningDialogueItem item;
  final ChatUiStyleConfig style;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return switch (item.type) {
      _OpeningDialogueType.narrator => _OpeningNarratorEditor(
        item: item,
        style: style,
        onDelete: onDelete,
        onChanged: onChanged,
      ),
      _OpeningDialogueType.character => _OpeningCharacterEditor(
        item: item,
        style: style,
        onDelete: onDelete,
        onChanged: onChanged,
      ),
      _OpeningDialogueType.image => _OpeningImageEditor(
        item: item,
        style: style,
        onDelete: onDelete,
        onChanged: onChanged,
      ),
    };
  }
}

class _OpeningNarratorEditor extends StatelessWidget {
  const _OpeningNarratorEditor({
    required this.item,
    required this.style,
    required this.onDelete,
    required this.onChanged,
  });

  final _OpeningDialogueItem item;
  final ChatUiStyleConfig style;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: style.systemMessageMargin.left,
            right: style.systemMessageMargin.right,
          ),
          child: Container(
            key: ValueKey<String>('${item.id}-narrator'),
            width: double.infinity,
            padding: style.systemMessagePadding,
            decoration: BoxDecoration(
              color: style.systemMessageBackgroundColor,
              borderRadius: BorderRadius.circular(
                style.systemMessageBorderRadius,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: SvgPicture.asset(
                    paragraphIconAsset,
                    width: 14,
                    height: 14,
                    fit: BoxFit.contain,
                    colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _OpeningDialogueTextField(
                    item: item,
                    hintText: 'Enter narrator dialogue',
                    style: style.systemMessageTextStyle,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: -8,
          child: CreateFormDeleteButton(
            buttonKey: ValueKey<String>('${item.id}-delete'),
            decorationKey: ValueKey<String>('${item.id}-delete-container'),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

class _OpeningCharacterEditor extends StatelessWidget {
  const _OpeningCharacterEditor({
    required this.item,
    required this.style,
    required this.onDelete,
    required this.onChanged,
  });

  final _OpeningDialogueItem item;
  final ChatUiStyleConfig style;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final character = item.character!;
    final name = character.name.trim();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          key: ValueKey<String>('${item.id}-character'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChatAvatar(
              label: chatInitials(name),
              imageUrl: character.avatarUrl,
              colors: style.otherAvatarColors,
              seed: name,
              borderColor: createFormBorder,
              style: style,
            ),
            SizedBox(width: style.avatarBubbleGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    key: ValueKey<String>('${item.id}-name-row'),
                    height: 16,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style.senderNameTextStyle.copyWith(
                            color: createFormText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: style.senderNameBottomGap),
                  Container(
                    key: ValueKey<String>('${item.id}-bubble'),
                    width: double.infinity,
                    padding: style.bubblePadding,
                    decoration: BoxDecoration(
                      color: style.otherBubbleColor,
                      border: Border.all(color: createFormBorder),
                      borderRadius: BorderRadius.circular(
                        style.bubbleBorderRadius,
                      ),
                    ),
                    child: _OpeningDialogueTextField(
                      item: item,
                      hintText: 'Enter $name dialogue',
                      style: style.bubbleTextStyle,
                      onChanged: onChanged,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: style.avatarSideSpacerWidth),
          ],
        ),
        Positioned(
          right: 0,
          top: -8,
          child: CreateFormDeleteButton(
            buttonKey: ValueKey<String>('${item.id}-delete'),
            decorationKey: ValueKey<String>('${item.id}-delete-container'),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

class _OpeningDialogueTextField extends StatelessWidget {
  const _OpeningDialogueTextField({
    required this.item,
    required this.hintText,
    required this.style,
    required this.onChanged,
  });

  final _OpeningDialogueItem item;
  final String hintText;
  final TextStyle style;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey<String>('${item.id}-field'),
      controller: item.controller,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      minLines: 3,
      maxLines: 7,
      style: style,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hintText,
        hintStyle: style.copyWith(
          color: (style.color ?? createFormHint).withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _OpeningImageEditor extends StatelessWidget {
  const _OpeningImageEditor({
    required this.item,
    required this.style,
    required this.onDelete,
    required this.onChanged,
  });

  final _OpeningDialogueItem item;
  final ChatUiStyleConfig style;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: style.systemMessageMargin.left,
            right: style.systemMessageMargin.right,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Align(
                alignment: Alignment.centerLeft,
                child: CreateUploadBox(
                  key: ValueKey<String>('${item.id}-image'),
                  controller: item.controller,
                  label: 'UPLOAD IMAGE',
                  width: width,
                  height: width,
                  uploadOriginalImage: true,
                  preserveImageAspectRatio: true,
                  previewAlignment: Alignment.center,
                  showRemoveLinkWhenFilled: false,
                  onChanged: onChanged,
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 0,
          top: -8,
          child: CreateFormDeleteButton(
            buttonKey: ValueKey<String>('${item.id}-delete'),
            decorationKey: ValueKey<String>('${item.id}-delete-container'),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}

class _OpeningDialogueAddButton extends StatelessWidget {
  const _OpeningDialogueAddButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onTap,
  });

  final String label;
  final Widget leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: createFormFieldFill,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: createFormBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: createFormText, size: 17),
              const SizedBox(width: 4),
              leading,
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: createFormText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpeningLocationPickerSheet extends StatefulWidget {
  const _OpeningLocationPickerSheet({
    required this.options,
    required this.initialSelection,
  });

  final List<_OpeningLocationOption> options;
  final _OpeningLocationOption? initialSelection;

  @override
  State<_OpeningLocationPickerSheet> createState() =>
      _OpeningLocationPickerSheetState();
}

class _OpeningLocationPickerSheetState
    extends State<_OpeningLocationPickerSheet> {
  _OpeningLocationOption? _selection;

  @override
  void initState() {
    super.initState();
    _selection = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    return GenesisBottomSheetPanel(
      title: 'Select Location',
      height: MediaQuery.sizeOf(context).height * 0.58,
      trailing: GenesisBottomSheetCloseButton(
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        children: [
          Expanded(
            child: widget.options.isEmpty
                ? const Center(
                    child: Text(
                      'No saved locations',
                      style: TextStyle(color: createFormMuted, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: widget.options.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFEAEAEA),
                    ),
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      final selected = _selection?.id == option.id;
                      return _OpeningLocationOptionRow(
                        option: option,
                        selected: selected,
                        onTap: () => setState(() => _selection = option),
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
                  onPressed: _selection == null
                      ? null
                      : () => Navigator.of(context).pop(_selection),
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

class _OpeningLocationOptionRow extends StatelessWidget {
  const _OpeningLocationOptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _OpeningLocationOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey<String>('opening-location-option-${option.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.place_outlined,
                size: 16,
                color: createFormText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.location.name.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: createFormText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (option.characterNames.isNotEmpty) ...[
                        SvgPicture.asset(
                          characterStatIconAsset,
                          width: 14,
                          height: 14,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          option.characterNames.isEmpty
                              ? 'No initial character'
                              : option.characterNames,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? createFormGreen : Colors.transparent,
                border: Border.all(
                  color: selected ? createFormGreen : createFormBorder,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OpeningLocationOption {
  const _OpeningLocationOption({
    required this.location,
    required this.characters,
  });

  final LocationDraft location;
  final List<CharacterDraft> characters;

  String get id {
    final locationId = location.locationId.trim();
    return locationId.isEmpty ? location.name.trim() : locationId;
  }

  String get characterNames => characters
      .map((character) => character.name.trim())
      .where((name) => name.isNotEmpty)
      .join(', ');
}

enum _OpeningDialogueType { narrator, character, image }

_OpeningDialogueType? _openingDialogueTypeFromDraft(String value) {
  return switch (value.trim()) {
    OpeningDialogueDraft.narratorType => _OpeningDialogueType.narrator,
    OpeningDialogueDraft.characterType => _OpeningDialogueType.character,
    OpeningDialogueDraft.imageType => _OpeningDialogueType.image,
    _ => null,
  };
}

class _OpeningDialogueItem {
  _OpeningDialogueItem({
    required this.id,
    required this.type,
    this.character,
    String initialContent = '',
  }) : controller = TextEditingController(text: initialContent);

  final String id;
  final _OpeningDialogueType type;
  final CharacterDraft? character;
  final TextEditingController controller;

  bool get hasContent => controller.text.trim().isNotEmpty;

  OpeningDialogueDraft toDraft() {
    return OpeningDialogueDraft(
      type: switch (type) {
        _OpeningDialogueType.narrator => OpeningDialogueDraft.narratorType,
        _OpeningDialogueType.character => OpeningDialogueDraft.characterType,
        _OpeningDialogueType.image => OpeningDialogueDraft.imageType,
      },
      content: controller.text.trim(),
      characterId: character?.charId.trim() ?? '',
    );
  }

  void dispose() {
    controller.dispose();
  }
}
