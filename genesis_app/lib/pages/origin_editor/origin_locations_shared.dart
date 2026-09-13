part of 'origin_editor_pages.dart';

class _LocationFields extends StatelessWidget {
  const _LocationFields({
    super.key,
    required this.form,
    required this.nextFocusNode,
    required this.characters,
    required this.onChanged,
    required this.onRemoveCharacter,
    this.nameFieldLabel = 'Location Name *',
    this.nameFieldHintText = 'eg. Main Street',
    this.nameFieldNote,
    this.fieldLabelFontWeight = FontWeight.w600,
    required this.availableCharacters,
    required this.onAddCharacter,
  });

  final _LocationForm form;
  final FocusNode? nextFocusNode;
  final List<CharacterDraft> characters;
  final VoidCallback onChanged;
  final ValueChanged<String> onRemoveCharacter;
  final String nameFieldLabel;
  final String nameFieldHintText;
  final String? nameFieldNote;
  final FontWeight fieldLabelFontWeight;
  final List<CharacterDraft> availableCharacters;
  final ValueChanged<String> onAddCharacter;

  @override
  Widget build(BuildContext context) {
    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CreateUploadBox(
              controller: form.imageUrl,
              initialPreviewBytes: form.previewImageBytes,
              onPreviewBytesChanged: (bytes) {
                form.previewImageBytes = bytes;
              },
              label: 'IMAGE\n(Optional)',
              emptyBackgroundColor: GenesisColors.darkFaintFill,
              emptyBorderColor: GenesisColors.darkTextTertiary,
              emptyIconColor: GenesisColors.createAdd,
              emptyLabelColor: GenesisColors.darkTextSecondary,
              borderRadius: 8,
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
                hintText: nameFieldHintText,
                note: nameFieldNote,
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
          onRemoveCharacter: onRemoveCharacter,
          availableCharacters: availableCharacters,
          onAddCharacter: onAddCharacter,
        ),
      ],
    );
    return fields;
  }
}

class _InitialCharactersField extends StatelessWidget {
  const _InitialCharactersField({
    required this.form,
    required this.characters,
    required this.labelFontWeight,
    required this.onRemoveCharacter,
    required this.availableCharacters,
    required this.onAddCharacter,
  });

  final _LocationForm form;
  final List<CharacterDraft> characters;
  final FontWeight labelFontWeight;
  final ValueChanged<String> onRemoveCharacter;
  final List<CharacterDraft> availableCharacters;
  final ValueChanged<String> onAddCharacter;

  @override
  Widget build(BuildContext context) {
    final selectedCharacters = _selectedCharacters;
    final selectionField = Container(
      key: const ValueKey('location-character-selection'),
      constraints: const BoxConstraints(minHeight: 40),
      decoration: BoxDecoration(
        color: GenesisColors.darkFaintFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final leftPadding = selectedCharacters.isEmpty ? 14.0 : 4.0;
          final chipAreaWidth = constraints.maxWidth - leftPadding;
          final chipsWrap = _chipsWillWrap(
            context,
            selectedCharacters,
            chipAreaWidth <= 0 ? 0 : chipAreaWidth,
          );
          final contentPadding = selectedCharacters.isEmpty
              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
              : chipsWrap
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
                          height:
                              MediaQuery.textScalerOf(context).scale(14) * 1.4,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Select from available characters below',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: GenesisColors.darkInputPlaceholder,
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
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
            color: GenesisColors.darkTextPrimary,
            fontSize: 14,
            fontWeight: labelFontWeight,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        selectionField,
        const SizedBox(height: 8),
        const CreateFormNote(
          note: 'The characters who start here when the worldo begins.',
        ),
        const SizedBox(height: 14),
        Align(
          key: const ValueKey('available-initial-characters-label'),
          alignment: Alignment.center,
          child: Text(
            'Available to select',
            style: TextStyle(
              color: GenesisColors.darkTextPrimary,
              fontSize: 14,
              height: 1.2,
              fontWeight: labelFontWeight,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (availableCharacters.isEmpty)
          Text(
            characters.isEmpty
                ? 'No characters yet. Create characters first, then choose '
                      'where they start.'
                : 'No characters available. All characters already have '
                      'an initial location.',
            key: const ValueKey('available-initial-characters-empty'),
            style: const TextStyle(
              color: GenesisColors.darkTextTertiary,
              fontSize: 13,
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
              for (final character in availableCharacters)
                _AvailableInitialCharacterChip(
                  characterId: character.charId.trim(),
                  avatarUrl: character.avatarUrl.trim(),
                  name: character.name.trim(),
                  onAdd: onAddCharacter,
                ),
            ],
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
        style: const TextStyle(
          fontFamily: GenesisTypography.fontFamily,
          fontFamilyFallback: GenesisTypography.fontFamilyFallback,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
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
          color: GenesisColors.darkFaintFill,
          borderRadius: BorderRadius.circular(999),
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
                  color: GenesisColors.darkTextPrimary,
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
          color: GenesisColors.darkFaintFill,
          borderRadius: BorderRadius.circular(999),
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
                  color: GenesisColors.darkTextPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 1),
            const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.close,
                size: 14,
                color: GenesisColors.darkTextTertiary,
              ),
            ),
          ],
        ),
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
    this.previewImageBytes,
  });

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

  factory _LocationForm.copyOf(_LocationForm source) {
    return _LocationForm(
      locationId: source.locationId,
      parentLocationId: source.parentLocationId,
      level: source.level,
      imageUrl: TextEditingController(text: source.imageUrl.text),
      name: TextEditingController(text: source.name.text),
      description: TextEditingController(text: source.description.text),
      selectedCharacterIds: source.selectedCharacterIds.toList(growable: true),
      previewImageBytes: source.previewImageBytes,
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
  Uint8List? previewImageBytes;

  void applyValuesFrom(_LocationForm source) {
    imageUrl.text = source.imageUrl.text;
    name.text = source.name.text;
    description.text = source.description.text;
    selectedCharacterIds = source.selectedCharacterIds.toList(growable: true);
    previewImageBytes = source.previewImageBytes;
  }

  void dispose() {
    imageUrl.dispose();
    name.dispose();
    description.dispose();
    nameFocusNode.dispose();
  }
}
