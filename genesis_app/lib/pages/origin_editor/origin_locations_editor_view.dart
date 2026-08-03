part of 'origin_editor_pages.dart';

extension _OriginLocationsEditorView on _OriginLocationsEditorPageState {
  List<Widget> _editorChildren() {
    if (!widget.useLocationTree) {
      return <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_forms.length}/'
            '${_OriginLocationsEditorPageState._maxLocations} (Added / Max)',
            style: const TextStyle(
              color: createFormText,
              fontSize: 14,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _forms.length; i++) ...[
          _LocationCard(
            index: i + 1,
            form: _forms[i],
            nextFocusNode: i + 1 < _forms.length
                ? _forms[i + 1].nameFocusNode
                : null,
            characters: _finalCharacters,
            onChanged: _onFormChanged,
            onPickCharacters: () => _openCharacterPicker(i),
            onRemoveCharacter: (charId) =>
                _removeCharacterFromLocation(i, charId),
            onDelete: () => _requestRemoveLocation(i),
          ),
          const SizedBox(height: 24),
        ],
        CreateAddButton(label: '+ Add Location', onTap: _addLocation),
        const SizedBox(height: 12),
      ];
    }

    return <Widget>[
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          key: const ValueKey<String>('create-location-l3-count'),
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              'L1: $_l1LocationCount',
              style: _OriginLocationsEditorPageState._locationCountStyle,
            ),
            Text(
              'L2: $_l2LocationCount',
              style: _OriginLocationsEditorPageState._locationCountStyle,
            ),
            Text(
              'L3: $_l3LocationCount/'
              '${_OriginLocationsEditorPageState._maxLocations} (Added/Max)',
              style: _OriginLocationsEditorPageState._locationCountStyle,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) ...[
        _buildL1Branch(_treeForms[l1Index], l1Index),
        if (l1Index + 1 < _treeForms.length) const SizedBox(height: 8),
      ],
      if (_treeForms.isNotEmpty) const SizedBox(height: 8),
      _LocationTreeAddButton(
        key: const ValueKey<String>('create-add-l1-location'),
        label: '+ L1',
        onTap: _addL1Location,
      ),
      const SizedBox(height: 6),
    ];
  }

  Widget _buildL1Branch(_L1LocationForm l1, int l1Index) {
    return KeyedSubtree(
      key: ValueKey<String>('create-location-l1-${l1.locationId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTreeLocationNameField(
            key: ValueKey<String>('create-location-l1-name-$l1Index'),
            title: 'L1 Location',
            displayId: '${l1Index + 1}',
            controller: l1.name,
            hintText: 'eg. Downtown',
            onDelete: () => _removeL1Location(l1),
            deleteEnabled: _treeForms.length > 1,
            onDeleteDisabled: () =>
                _showError('At least one L1 location is required.'),
          ),
          for (int l2Index = 0; l2Index < l1.children.length; l2Index++) ...[
            _buildL2Branch(l1, l1.children[l2Index], l1Index, l2Index),
            if (l2Index + 1 < l1.children.length)
              const _LocationTreeVerticalGap(lineLeft: 0),
          ],
          if (l1.children.isNotEmpty)
            const _LocationTreeVerticalGap(lineLeft: 0),
          _LocationTreeGuide(
            lineLeft: 0,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _LocationTreeAddButton(
                key: ValueKey<String>('create-add-l2-${l1.locationId}'),
                label: '+ L2',
                onTap: () => _addL2Location(l1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildL2Branch(
    _L1LocationForm l1,
    _L2LocationForm l2,
    int l1Index,
    int l2Index,
  ) {
    return KeyedSubtree(
      key: ValueKey<String>('create-location-l2-${l2.locationId}'),
      child: _LocationTreeGuide(
        lineLeft: 0,
        branchTop: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _buildTreeLocationNameField(
                key: ValueKey<String>(
                  'create-location-l2-name-$l1Index-$l2Index',
                ),
                title: 'L2 Location',
                displayId: '${l1Index + 1}.${l2Index + 1}',
                controller: l2.name,
                hintText: 'eg. Main Street',
                onDelete: () => _removeL2Location(l1, l2),
                deleteEnabled: l1.children.length > 1,
                onDeleteDisabled: () => _showError(_l1NeedsL2Message(l1)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    int l3Index = 0;
                    l3Index < l2.children.length;
                    l3Index++
                  ) ...[
                    _LocationTreeGuide(
                      lineLeft: -12,
                      branchTop: 20,
                      child: _LocationCard(
                        key: ValueKey<String>(
                          'create-location-l3-${l2.children[l3Index].locationId}',
                        ),
                        index: l3Index + 1,
                        title: 'L3 Location',
                        titleSuffix:
                            '(No. ${l1Index + 1}.${l2Index + 1}.${l3Index + 1})',
                        showBorder: false,
                        titleFontSize: 14,
                        nameFieldLabel: 'Name *',
                        fieldLabelFontWeight: FontWeight.w400,
                        form: l2.children[l3Index],
                        nextFocusNode: null,
                        characters: _finalCharacters,
                        onChanged: _onFormChanged,
                        onPickCharacters: () =>
                            _openCharacterPickerForForm(l2.children[l3Index]),
                        onRemoveCharacter: (charId) => _removeCharacterFromForm(
                          l2.children[l3Index],
                          charId,
                        ),
                        onDelete: () =>
                            _removeL3Location(l2, l2.children[l3Index]),
                        deleteEnabled: l2.children.length > 1,
                        onDeleteDisabled: () =>
                            _showError(_l2NeedsL3Message(l2)),
                      ),
                    ),
                    if (l3Index + 1 < l2.children.length)
                      const _LocationTreeVerticalGap(lineLeft: -12),
                  ],
                  _LocationTreeGuide(
                    lineLeft: -12,
                    child: _LocationTreeAddL3Button(
                      buttonKey: ValueKey<String>(
                        'create-add-l3-${l2.locationId}',
                      ),
                      isRequired: !_l2HasSavedL3(l2),
                      onTap: () => _addL3Location(l2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreeLocationNameField({
    required Key key,
    required String title,
    required String displayId,
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onDelete,
    required bool deleteEnabled,
    required VoidCallback onDeleteDisabled,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: Text.rich(
                    TextSpan(
                      text: title,
                      children: [
                        TextSpan(
                          text: ' (No. $displayId)',
                          style: const TextStyle(
                            color: Color(0xFFA8A8AD),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      color: createFormText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: 0,
                  child: CreateFormDeleteButton(
                    onPressed: onDelete,
                    enabled: deleteEnabled,
                    onDisabledPressed: onDeleteDisabled,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Name',
                style: TextStyle(
                  color: createFormText,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CreateTextFieldBlock(
                  key: key,
                  label: '',
                  controller: controller,
                  hintText: hintText,
                  maxLength: 25,
                  maxLines: 1,
                  counterInside: true,
                  onChanged: (_) => _onFormChanged(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocationsModeSwitch extends StatelessWidget {
  const _LocationsModeSwitch({required this.mode, required this.onChanged});

  final _LocationsEditorMode mode;
  final ValueChanged<_LocationsEditorMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final nextMode = mode == _LocationsEditorMode.edit
        ? _LocationsEditorMode.preview
        : _LocationsEditorMode.edit;
    final label = nextMode == _LocationsEditorMode.preview ? 'Preview' : 'Edit';
    final switchingToPreview = nextMode == _LocationsEditorMode.preview;
    return Semantics(
      key: const ValueKey<String>('locations-mode-switch'),
      button: true,
      label: 'Switch to $label mode',
      child: GestureDetector(
        key: ValueKey<String>(
          nextMode == _LocationsEditorMode.preview
              ? 'locations-mode-preview'
              : 'locations-mode-edit',
        ),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () => onChanged(nextMode),
        onLongPress: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (switchingToPreview)
                const Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: Color(0xFF4B6192),
                )
              else
                SvgPicture.asset(
                  editPencilLineIconAsset,
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF4B6192),
                    BlendMode.srcIn,
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF4B6192),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineTreeLocationNameEditor extends StatelessWidget {
  const _InlineTreeLocationNameEditor({
    super.key,
    required this.testKey,
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.level,
    required this.hintText,
    required this.note,
    required this.onChanged,
    required this.onEditingComplete,
    required this.onTapOutside,
    required this.saveButtonKey,
    required this.onDelete,
    required this.deleteEnabled,
    required this.onDeleteDisabled,
  });

  final Key testKey;
  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int level;
  final String hintText;
  final String note;
  final VoidCallback onChanged;
  final VoidCallback onEditingComplete;
  final VoidCallback onTapOutside;
  final Key saveButtonKey;
  final VoidCallback onDelete;
  final bool deleteEnabled;
  final VoidCallback onDeleteDisabled;

  @override
  Widget build(BuildContext context) {
    final prefixStyle = _inlineLocationNameStyle(level);
    final inputVerticalOffset = level == 0 ? -2.0 : -5.0;
    return KeyedSubtree(
      key: testKey,
      child: Padding(
        padding: EdgeInsets.only(left: level * 15.0),
        child: TextFieldTapRegion(
          groupId: createFormTextFieldTapRegionGroup,
          consumeOutsideTaps: false,
          onTapOutside: (_) => onTapOutside(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 5),
                    child: Text('- ', style: prefixStyle),
                  ),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(0, inputVerticalOffset),
                      child: CreateTextFieldBlock(
                        key: fieldKey,
                        controller: controller,
                        focusNode: focusNode,
                        label: '',
                        hintText: hintText,
                        maxLength: 25,
                        maxLines: 1,
                        counterInside: true,
                        inputLineHeight: 1.2,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: onEditingComplete,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.translate(
                    offset: Offset(0, level == 0 ? 2.5 : 1.5),
                    child: _InlineLocationSaveButton(
                      key: saveButtonKey,
                      onPressed: onEditingComplete,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.translate(
                    offset: Offset(0, level == 0 ? 2.5 : 1.5),
                    child: CreateFormDeleteButton(
                      onPressed: onDelete,
                      enabled: deleteEnabled,
                      onDisabledPressed: onDeleteDisabled,
                    ),
                  ),
                ],
              ),
              if (note.trim().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    left: 14,
                    top: 4,
                    bottom: 8 + inputVerticalOffset,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, inputVerticalOffset),
                    child: CreateFormNote(note: note.trim()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationEditorNote extends StatelessWidget {
  const _LocationEditorNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final value = text.trim();
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: CreateFormNote(note: value),
    );
  }
}

class _InlineTreeLocationPreviewHeader extends StatelessWidget {
  const _InlineTreeLocationPreviewHeader({
    super.key,
    required this.name,
    required this.level,
    required this.onTap,
  });

  final String name;
  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _inlineLocationNameStyle(level);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(level * 15.0, 5, 0, 5),
        child: Row(
          children: [
            Text('- ', style: style),
            Flexible(
              fit: FlexFit.loose,
              child: Text(
                name,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _inlineLocationNameStyle(int level) {
  if (level <= 0) {
    return const TextStyle(
      color: Colors.black,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );
  }
  return const TextStyle(
    color: Colors.black,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );
}

class _InlineLocationSaveButton extends StatelessWidget {
  const _InlineLocationSaveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xE6F4F4F6),
              border: Border.all(color: const Color(0xFFD8D8DE)),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: onPressed,
            padding: const EdgeInsets.all(5),
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            icon: SvgPicture.asset(
              saveLineIconAsset,
              width: 14,
              height: 14,
              colorFilter: const ColorFilter.mode(
                createFormGreen,
                BlendMode.srcIn,
              ),
            ),
            splashRadius: 12,
          ),
        ],
      ),
    );
  }
}

class _LocationTreeGuide extends StatelessWidget {
  const _LocationTreeGuide({
    required this.lineLeft,
    required this.child,
    this.branchTop,
  });

  final double lineLeft;
  final double? branchTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: lineLeft,
          top: 0,
          bottom: 0,
          width: 1,
          child: const ColoredBox(color: Color(0x99338960)),
        ),
        if (branchTop != null)
          Positioned(
            left: lineLeft,
            top: branchTop!,
            width: 12,
            height: 1,
            child: const ColoredBox(color: Color(0x99338960)),
          ),
        child,
      ],
    );
  }
}

class _LocationTreeVerticalGap extends StatelessWidget {
  const _LocationTreeVerticalGap({required this.lineLeft});

  final double lineLeft;

  @override
  Widget build(BuildContext context) {
    return _LocationTreeGuide(
      lineLeft: lineLeft,
      child: const SizedBox(height: 8),
    );
  }
}

class _LocationTreeAddButton extends StatelessWidget {
  const _LocationTreeAddButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CreateInlineAddButton(
      label: label,
      onTap: onTap,
      verticalPadding: 5,
    );
  }
}

class _LocationTreeAddL3Button extends StatelessWidget {
  const _LocationTreeAddL3Button({
    required this.buttonKey,
    required this.isRequired,
    required this.onTap,
  });

  final Key buttonKey;
  final bool isRequired;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        key: buttonKey,
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          child: CustomPaint(
            painter: CreateDashedRRectPainter(
              color: createFormDash,
              radius: 4,
              strokeWidth: 1.2,
            ),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, color: createFormGreen, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    isRequired ? 'L3 *' : 'L3',
                    style: const TextStyle(
                      color: createFormGreen,
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
