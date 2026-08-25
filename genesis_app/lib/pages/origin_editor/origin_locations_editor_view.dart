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
            style: TextStyle(
              color: context.genesisCreateColors.text,
              fontSize: 13,
              height: 1.2,
            ),
          ),
        ),
        SizedBox(height: 12),
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
          SizedBox(height: 24),
        ],
        CreateAddButton(label: '+ Add Location', onTap: _addLocation),
        SizedBox(height: 12),
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
              style: _OriginLocationsEditorPageState._locationCountStyle
                  .copyWith(color: context.genesisColors.textMuted),
            ),
            Text(
              'L2: $_l2LocationCount',
              style: _OriginLocationsEditorPageState._locationCountStyle
                  .copyWith(color: context.genesisColors.textMuted),
            ),
            Text(
              'L3: $_l3LocationCount/'
              '${_OriginLocationsEditorPageState._maxLocations} (Added/Max)',
              style: _OriginLocationsEditorPageState._locationCountStyle
                  .copyWith(color: context.genesisColors.textMuted),
            ),
          ],
        ),
      ),
      SizedBox(height: 12),
      for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) ...[
        _buildL1Branch(_treeForms[l1Index], l1Index),
        if (l1Index + 1 < _treeForms.length) SizedBox(height: 8),
      ],
      if (_treeForms.isNotEmpty) SizedBox(height: 8),
      _LocationTreeAddButton(
        key: const ValueKey<String>('create-add-l1-location'),
        label: '+ L1',
        onTap: _addL1Location,
      ),
      SizedBox(height: 6),
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
                        titleFontSize: 13,
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
                          style: TextStyle(
                            color: context.genesisCreateColors.hint,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      color: context.genesisCreateColors.text,
                      fontSize: 13,
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
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Name',
                style: TextStyle(
                  color: context.genesisCreateColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),
              SizedBox(width: 8),
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
                Icon(
                  Icons.visibility_outlined,
                  size: 13,
                  color: context.genesisColors.accentText,
                )
              else
                SvgPicture.asset(
                  editPencilLineIconAsset,
                  width: 13,
                  height: 13,
                  colorFilter: ColorFilter.mode(
                    context.genesisColors.accentText,
                    BlendMode.srcIn,
                  ),
                ),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: context.genesisColors.accentText,
                  fontSize: 11,
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
    final inputVerticalOffset = level == 0 ? -2.0 : -5.0;
    return KeyedSubtree(
      key: testKey,
      child: WorldLocationTreeGuides(
        level: level,
        padding: EdgeInsets.zero,
        breakAbove: level >= 1,
        child: TextFieldTapRegion(
          // Android renders the selection toolbar in the EditableText tap
          // region. Keep Paste/Copy/Select from cancelling inline editing.
          groupId: EditableText,
          consumeOutsideTaps: false,
          onTapOutside: (_) => onTapOutside(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  SizedBox(width: 8),
                  Transform.translate(
                    offset: Offset(0, level == 0 ? 2.5 : 1.5),
                    child: _InlineLocationSaveButton(
                      key: saveButtonKey,
                      onPressed: onEditingComplete,
                    ),
                  ),
                  SizedBox(width: 4),
                  Transform.translate(
                    offset: Offset(0, level == 0 ? 2.5 : 1.5),
                    child: CreateFormDeleteButton(
                      onPressed: onDelete,
                      enabled: deleteEnabled,
                      onDisabledPressed: onDeleteDisabled,
                      size: 30,
                      iconSize: 14,
                      backgroundColor: context.genesisCreateColors.fieldFill,
                      borderColor: Colors.transparent,
                      borderRadius: 10,
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

  static final RegExp _levelLine = RegExp(
    r'^(L\d)\s*\u00b7\s*(\S+)\s{2,}(.+)$',
  );

  final String text;

  @override
  Widget build(BuildContext context) {
    final value = text.trim();
    if (value.isEmpty) return const SizedBox.shrink();
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final levels = <_LocationEditorNoteLevel>[];
    final rest = <String>[];
    String heading = '';
    for (final line in lines) {
      final match = _levelLine.firstMatch(line);
      if (match != null) {
        levels.add(
          _LocationEditorNoteLevel(
            badge: match.group(1)!,
            name: match.group(2)!,
            description: match.group(3)!.trim(),
          ),
        );
      } else if (heading.isEmpty && levels.isEmpty) {
        heading = line;
      } else {
        rest.add(line);
      }
    }
    if (levels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: CreateFormNote(note: value),
      );
    }
    final colors = context.genesisColors;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // 7% white surface tier.
          color: colors.inputBackground,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (heading.isNotEmpty)
              Text(
                heading,
                style: TextStyle(
                  color: colors.textBody,
                  fontSize: 11,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            for (final (index, level) in levels.indexed) ...[
              SizedBox(height: index == 0 ? 11 : 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 26,
                        height: 19,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surfaceTag,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          level.badge,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 9.5,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          level.name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 11,
                            height: 1,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    // 缩进到徽标(26)+间距(7)之后,和层级名左对齐。
                    padding: const EdgeInsets.only(left: 33),
                    child: Text(
                      level.description,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            for (final line in rest) ...[
              const SizedBox(height: 8),
              Text(
                line,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationEditorNoteLevel {
  const _LocationEditorNoteLevel({
    required this.badge,
    required this.name,
    required this.description,
  });

  final String badge;
  final String name;
  final String description;
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
    final style = _inlineLocationNameStyle(context, level);
    // 与详情页 _NodeHeader(compactSheetStyle) 相同的层级几何。
    return InkWell(
      onTap: onTap,
      child: WorldLocationTreeGuides(
        level: level,
        padding: level <= 0
            ? const EdgeInsets.fromLTRB(0, 9, 0, 2)
            : const EdgeInsets.fromLTRB(0, 0, 0, 2),
        breakAbove: level >= 1,
        child: Row(
          children: [
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

TextStyle _inlineLocationNameStyle(BuildContext context, int level) {
  // 对齐详情页 9g 的地点名样式:L1 15px、L2/L3 13px,统一 w600/1.15。
  final double fontSize = level <= 0 ? 15 : 13;
  return TextStyle(
    color: context.genesisColors.textPrimary,
    fontSize: fontSize,
    height: 1.15,
    fontWeight: FontWeight.w600,
  );
}

class _InlineLocationSaveButton extends StatelessWidget {
  const _InlineLocationSaveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 与其他页面的方形操作按钮同款:30x30、圆角 10、fieldFill、无边框;
    // 对号与方角垃圾桶同 1.6 描边。
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.genesisCreateColors.fieldFill,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          IconButton(
            tooltip: 'Save',
            onPressed: onPressed,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            icon: SvgPicture.asset(
              checkLineIconAsset,
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(
                context.genesisCreateColors.muted,
                BlendMode.srcIn,
              ),
            ),
            splashRadius: 15,
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
          child: ColoredBox(
            color: context.genesisCreateColors.accent.withValues(alpha: 0.6),
          ),
        ),
        if (branchTop != null)
          Positioned(
            left: lineLeft,
            top: branchTop!,
            width: 12,
            height: 1,
            child: ColoredBox(
              color: context.genesisCreateColors.accent.withValues(alpha: 0.6),
            ),
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
    return _LocationTreeGuide(lineLeft: lineLeft, child: SizedBox(height: 8));
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
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: CustomPaint(
            // 与树里 L3 行的图片方块同规格:52x52、圆角 12。
            // 小方块用细虚线,圆角处才有足够的笔画贴合弧线。
            painter: CreateDashedRRectPainter(
              color: context.genesisCreateColors.dash,
              radius: 12,
              strokeWidth: 1.5,
              dashWidth: 5,
              dashSpace: 4,
            ),
            child: SizedBox(
              width: 52,
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: context.genesisColors.accentText,
                    size: 13,
                  ),
                  SizedBox(height: 2),
                  Text(
                    isRequired ? 'L3 *' : 'L3',
                    style: TextStyle(
                      color: context.genesisColors.accentText,
                      fontSize: 11,
                      height: 1,
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
