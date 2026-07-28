part of 'origin_editor_pages.dart';

enum _LocationsEditorMode { preview, edit }

class OriginLocationsEditorPage extends StatefulWidget {
  const OriginLocationsEditorPage({
    super.key,
    required this.repository,
    this.useLocationTree = false,
  });

  final OriginDraftRepository repository;
  final bool useLocationTree;

  @override
  State<OriginLocationsEditorPage> createState() =>
      _OriginLocationsEditorPageState();
}

class _OriginLocationsEditorPageState extends State<OriginLocationsEditorPage> {
  static const int _maxLocations = 10;
  static const TextStyle _locationCountStyle = TextStyle(
    color: Color(0xFF666666),
    fontSize: 13,
    height: 1.2,
  );

  final List<_LocationForm> _forms = <_LocationForm>[];
  final List<_L1LocationForm> _treeForms = <_L1LocationForm>[];
  String _uid = 'anonymous';
  List<CharacterDraft> _finalCharacters = const <CharacterDraft>[];
  bool _isSaving = false;
  _LocationsEditorMode _mode = _LocationsEditorMode.edit;
  String? _inlineEditingLocationId;
  late final FocusNode _inlineNameFocusNode;

  @override
  void initState() {
    super.initState();
    _inlineNameFocusNode = FocusNode();
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
    if (widget.useLocationTree) {
      _treeForms.addAll(_createLocationTrees(source));
    } else {
      for (final item in source) {
        _forms.add(_LocationForm.fromDraft(item, uid: _uid));
      }
    }
    if (!mounted) return;
    setState(() {});
  }

  List<_L1LocationForm> _createLocationTrees(List<LocationDraft> source) {
    final populated = source
        .where(_locationDraftHasContent)
        .toList(growable: false);
    if (populated.isEmpty) return <_L1LocationForm>[_newL1Location(1)];

    final trees = <_L1LocationForm>[];
    final l1BySourceId = <String, _L1LocationForm>{};
    final l2BySourceId = <String, _L2LocationForm>{};
    _L1LocationForm? fallbackL1;
    _L2LocationForm? fallbackL2;

    _L1LocationForm ensureFallbackL1() {
      final existing = fallbackL1;
      if (existing != null) return existing;
      final created = _L1LocationForm(
        locationId: 'Loc_${trees.length + 1}',
        name: TextEditingController(),
        children: <_L2LocationForm>[],
      );
      trees.add(created);
      fallbackL1 = created;
      return created;
    }

    _L2LocationForm ensureFallbackL2() {
      final existing = fallbackL2;
      if (existing != null) return existing;
      final parent = ensureFallbackL1();
      final created = _L2LocationForm(
        locationId: '${parent.locationId}_${parent.children.length + 1}',
        name: TextEditingController(),
        children: <_LocationForm>[],
      );
      parent.children.add(created);
      fallbackL2 = created;
      return created;
    }

    final l1Drafts = populated.where((item) => item.level == 1);
    for (final l1Draft in l1Drafts) {
      final l1Index = trees.length;
      final l1Id = l1Draft.locationId.trim().isEmpty
          ? 'Loc_${l1Index + 1}'
          : l1Draft.locationId.trim();
      final l1 = _L1LocationForm(
        locationId: l1Id,
        name: TextEditingController(text: l1Draft.name),
        children: <_L2LocationForm>[],
      );
      trees.add(l1);
      final sourceId = l1Draft.locationId.trim();
      if (sourceId.isNotEmpty) l1BySourceId.putIfAbsent(sourceId, () => l1);
    }

    final l2Drafts = populated.where((item) => item.level == 2);
    for (final l2Draft in l2Drafts) {
      final sourceParentId = l2Draft.parentLocationId.trim();
      final parent = l1BySourceId[sourceParentId] ?? ensureFallbackL1();
      final sourceId = l2Draft.locationId.trim();
      final l2 = _L2LocationForm(
        locationId: sourceId.isEmpty
            ? '${parent.locationId}_${parent.children.length + 1}'
            : sourceId,
        name: TextEditingController(text: l2Draft.name),
        children: <_LocationForm>[],
      );
      parent.children.add(l2);
      if (sourceId.isNotEmpty) l2BySourceId.putIfAbsent(sourceId, () => l2);
    }

    final leafDrafts = populated.where(
      (item) => item.level != 1 && item.level != 2,
    );
    for (final leafDraft in leafDrafts) {
      final sourceParentId = leafDraft.parentLocationId.trim();
      final parent = l2BySourceId[sourceParentId] ?? ensureFallbackL2();
      final sourceId = leafDraft.locationId.trim();
      parent.children.add(
        _LocationForm.treeLeaf(
          locationId: sourceId.isEmpty
              ? '${parent.locationId}_${parent.children.length + 1}'
              : sourceId,
          parentLocationId: parent.locationId,
          draft: leafDraft,
        ),
      );
    }

    if (trees.isEmpty) trees.add(_newL1Location(1));
    for (final l1 in trees) {
      if (l1.children.isEmpty) {
        l1.children.add(_newL2Location(l1, 1));
      }
      l1.nextChildOrdinal = l1.children.length + 1;
      for (final l2 in l1.children) {
        if (l2.children.isEmpty) {
          l2.children.add(_newL3Location(l2, 1));
        }
        l2.nextChildOrdinal = l2.children.length + 1;
      }
    }
    return trees;
  }

  _L1LocationForm _newL1Location(int ordinal) {
    final l1 = _L1LocationForm(
      locationId: 'Loc_$ordinal',
      name: TextEditingController(),
      children: <_L2LocationForm>[],
    );
    l1.children.add(_newL2Location(l1, 1));
    l1.nextChildOrdinal = 2;
    return l1;
  }

  _L2LocationForm _newL2Location(_L1LocationForm parent, int ordinal) {
    final l2 = _L2LocationForm(
      locationId: '${parent.locationId}_$ordinal',
      name: TextEditingController(),
      children: <_LocationForm>[],
    );
    l2.children.add(_newL3Location(l2, 1));
    l2.nextChildOrdinal = 2;
    return l2;
  }

  _LocationForm _newL3Location(_L2LocationForm parent, int ordinal) {
    return _LocationForm.treeLeaf(
      locationId: '${parent.locationId}_$ordinal',
      parentLocationId: parent.locationId,
    );
  }

  int get _l1LocationCount => _treeForms.length;

  int get _l2LocationCount =>
      _treeForms.fold<int>(0, (count, l1) => count + l1.children.length);

  int get _l3LocationCount => _allL3Forms.length;

  int get _nextL1Ordinal {
    final used = _treeForms
        .map((item) => _trailingLocationOrdinal(item.locationId))
        .whereType<int>();
    return used.isEmpty ? 1 : used.reduce((a, b) => a > b ? a : b) + 1;
  }

  void _addL1Location() {
    if (_l3LocationCount >= _maxLocations) {
      _showError('You can add up to $_maxLocations L3 locations.');
      return;
    }
    setState(() => _treeForms.add(_newL1Location(_nextL1Ordinal)));
    _onFormChanged();
  }

  void _addL2Location(_L1LocationForm parent) {
    if (_l3LocationCount >= _maxLocations) {
      _showError('You can add up to $_maxLocations L3 locations.');
      return;
    }
    setState(() {
      parent.children.add(_newL2Location(parent, parent.nextChildOrdinal++));
    });
    _onFormChanged();
  }

  void _addL3Location(_L2LocationForm parent) {
    if (_l3LocationCount >= _maxLocations) {
      _showError('You can add up to $_maxLocations L3 locations.');
      return;
    }
    setState(() {
      parent.children.add(_newL3Location(parent, parent.nextChildOrdinal++));
    });
    _onFormChanged();
  }

  void _removeL1Location(_L1LocationForm form) {
    if (_treeForms.length == 1) {
      _showError('At least one L1 location is required.');
      return;
    }
    setState(() {
      _treeForms.remove(form);
      form.dispose();
    });
    _onFormChanged();
  }

  void _removeL2Location(_L1LocationForm parent, _L2LocationForm form) {
    if (parent.children.length == 1) {
      _showError('Each L1 location must contain at least one L2 location.');
      return;
    }
    setState(() {
      parent.children.remove(form);
      form.dispose();
    });
    _onFormChanged();
  }

  void _removeL3Location(_L2LocationForm parent, _LocationForm form) {
    if (parent.children.length == 1) {
      _showError('Each L2 location must contain at least one L3 location.');
      return;
    }
    setState(() {
      parent.children.remove(form);
      form.dispose();
    });
    _onFormChanged();
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

  void _requestRemoveLocation(int index) {
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
    setState(() {});
  }

  void _setMode(_LocationsEditorMode mode) {
    if (_mode == mode) return;
    _inlineEditingLocationId = null;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _mode = mode);
  }

  void _beginInlineNameEdit(WorldPoint point) {
    if (_mode != _LocationsEditorMode.edit || point.isLeafLocation) return;
    setState(() => _inlineEditingLocationId = point.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _inlineEditingLocationId != point.id) return;
      _inlineNameFocusNode.requestFocus();
    });
  }

  void _finishInlineNameEdit() {
    _inlineNameFocusNode.unfocus();
    if (_inlineEditingLocationId == null) return;
    setState(() => _inlineEditingLocationId = null);
  }

  void _dismissInlineEditor() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_inlineEditingLocationId == null) return;
    setState(() => _inlineEditingLocationId = null);
  }

  Widget? _buildInlineNodeHeader(
    BuildContext context,
    WorldPoint point,
    int level,
  ) {
    if (_inlineEditingLocationId != point.id) return null;
    for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
      final l1 = _treeForms[l1Index];
      if (l1.locationId == point.id) {
        return _InlineTreeLocationNameEditor(
          key: ValueKey<String>('locations-inline-name-${point.id}'),
          controller: l1.name,
          focusNode: _inlineNameFocusNode,
          level: level,
          hintText: 'eg. Downtown',
          onChanged: _onFormChanged,
          onEditingComplete: _finishInlineNameEdit,
          saveButtonKey: ValueKey<String>('locations-inline-save-${point.id}'),
          onDelete: () => _removeInlineEditorThen(() => _removeL1Location(l1)),
          deleteEnabled: _treeForms.length > 1,
          onDeleteDisabled: () =>
              _showError('At least one L1 location is required.'),
        );
      }
      for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
        final l2 = l1.children[l2Index];
        if (l2.locationId != point.id) continue;
        return _InlineTreeLocationNameEditor(
          key: ValueKey<String>('locations-inline-name-${point.id}'),
          controller: l2.name,
          focusNode: _inlineNameFocusNode,
          level: level,
          hintText: 'eg. Main Street',
          onChanged: _onFormChanged,
          onEditingComplete: _finishInlineNameEdit,
          saveButtonKey: ValueKey<String>('locations-inline-save-${point.id}'),
          onDelete: () =>
              _removeInlineEditorThen(() => _removeL2Location(l1, l2)),
          deleteEnabled: l1.children.length > 1,
          onDeleteDisabled: () => _showError(
            'Each L1 location must contain at least one L2 location.',
          ),
        );
      }
    }
    return null;
  }

  Widget? _buildNodeFooter(BuildContext context, WorldPoint point, int level) {
    for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
      final l1 = _treeForms[l1Index];
      if (l1.locationId == point.id) {
        return Padding(
          padding: EdgeInsets.fromLTRB((level + 1) * 15.0, 4, 0, 8),
          child: _LocationTreeAddButton(
            key: ValueKey<String>('create-add-l2-${l1.locationId}'),
            label: '+ Add L2 Location',
            displayId: 'Loc_${l1Index + 1}_${l1.children.length + 1}',
            onTap: () => _addL2Location(l1),
          ),
        );
      }
      for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
        final l2 = l1.children[l2Index];
        if (l2.locationId != point.id) continue;
        return Padding(
          padding: EdgeInsets.fromLTRB((level + 1) * 15.0, 4, 0, 8),
          child: _LocationTreeAddButton(
            key: ValueKey<String>('create-add-l3-${l2.locationId}'),
            label: '+ Add L3 Location',
            displayId:
                'Loc_${l1Index + 1}_${l2Index + 1}_${l2.children.length + 1}',
            onTap: () => _addL3Location(l2),
          ),
        );
      }
    }
    return null;
  }

  Widget _buildTreeRootFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
      child: _LocationTreeAddButton(
        key: const ValueKey<String>('create-add-l1-location'),
        label: '+ Add L1 Location',
        displayId: 'Loc_${_treeForms.length + 1}',
        onTap: _addL1Location,
      ),
    );
  }

  void _removeInlineEditorThen(VoidCallback remove) {
    _inlineEditingLocationId = null;
    _inlineNameFocusNode.unfocus();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      remove();
    });
  }

  void _openLeafEditor(WorldPoint point) {
    if (_mode != _LocationsEditorMode.edit) return;
    for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
      final l1 = _treeForms[l1Index];
      for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
        final l2 = l1.children[l2Index];
        for (int l3Index = 0; l3Index < l2.children.length; l3Index++) {
          final form = l2.children[l3Index];
          if (form.locationId != point.id) continue;
          unawaited(
            _showL3EditorSheet(
              _L3LocationTarget(
                parent: l2,
                form: form,
                l1Index: l1Index,
                l2Index: l2Index,
                l3Index: l3Index,
              ),
            ),
          );
          return;
        }
      }
    }
  }

  Future<void> _showL3EditorSheet(_L3LocationTarget target) async {
    if (_inlineEditingLocationId != null) {
      setState(() => _inlineEditingLocationId = null);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final deleteRequested = await showGenesisModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refreshSheet() {
              _onFormChanged();
              setSheetState(() {});
            }

            return GenesisBottomSheetPanel(
              key: const ValueKey<String>('locations-l3-editor-sheet'),
              title: 'Edit L3 Location',
              height: MediaQuery.sizeOf(context).height * 0.78,
              trailing: GenesisBottomSheetCloseButton(
                buttonKey: const ValueKey<String>('locations-l3-editor-close'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: _LocationCard(
                  key: ValueKey<String>(
                    'locations-l3-sheet-${target.form.locationId}',
                  ),
                  index: target.l3Index + 1,
                  title: 'L3 Location',
                  titleSuffix:
                      '(ID: Loc_${target.l1Index + 1}_${target.l2Index + 1}_${target.l3Index + 1})',
                  showBorder: false,
                  titleFontSize: 14,
                  nameFieldLabel: 'Name *',
                  fieldLabelFontWeight: FontWeight.w400,
                  form: target.form,
                  nextFocusNode: null,
                  characters: _finalCharacters,
                  onChanged: refreshSheet,
                  onPickCharacters: () async {
                    await _openCharacterPickerForForm(target.form);
                    if (!context.mounted) return;
                    setSheetState(() {});
                  },
                  onRemoveCharacter: (charId) {
                    _removeCharacterFromForm(target.form, charId);
                    setSheetState(() {});
                  },
                  onDelete: () => Navigator.of(context).pop(true),
                  deleteEnabled: target.parent.children.length > 1,
                  onDeleteDisabled: () => _showError(
                    'Each L2 location must contain at least one L3 location.',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (deleteRequested == true) {
      _removeL3Location(target.parent, target.form);
      return;
    }
    setState(() {});
  }

  Iterable<_LocationForm> get _allL3Forms sync* {
    if (!widget.useLocationTree) {
      yield* _forms;
      return;
    }
    for (final l1 in _treeForms) {
      for (final l2 in l1.children) {
        yield* l2.children;
      }
    }
  }

  void _removeCharacterFromLocation(int locationIndex, String charId) {
    _removeCharacterFromForm(_forms[locationIndex], charId);
  }

  void _removeCharacterFromForm(_LocationForm form, String charId) {
    setState(() {
      form.selectedCharacterIds = form.selectedCharacterIds
          .where((item) => item != charId)
          .toList(growable: true);
    });
    _onFormChanged();
  }

  List<LocationDraft> _snapshotLocations() {
    final validCharacterIds = _finalCharacters
        .map((item) => item.charId.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (widget.useLocationTree) {
      return [
        for (final l1 in _treeForms) ...[
          LocationDraft(
            locationId: l1.locationId,
            level: 1,
            name: l1.name.text.trim(),
          ),
          for (final l2 in l1.children) ...[
            LocationDraft(
              locationId: l2.locationId,
              parentLocationId: l1.locationId,
              level: 2,
              name: l2.name.text.trim(),
            ),
            for (final form in l2.children)
              LocationDraft(
                locationId: form.locationId,
                parentLocationId: l2.locationId,
                level: 3,
                imageUrl: form.imageUrl.text.trim(),
                name: form.name.text.trim(),
                description: form.description.text.trim(),
                initialCharacterIds: form.selectedCharacterIds
                    .where(validCharacterIds.contains)
                    .toList(growable: false),
              ),
          ],
        ],
      ];
    }
    return _forms
        .map(
          (form) => LocationDraft(
            locationId: form.locationId,
            parentLocationId: form.parentLocationId,
            level: form.level,
            imageUrl: form.imageUrl.text.trim(),
            name: normalizeGenesisUgcTextForDisplay(form.name.text),
            description: normalizeGenesisUgcTextForDisplay(
              form.description.text,
            ),
            initialCharacterIds: form.selectedCharacterIds
                .where(validCharacterIds.contains)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _openCharacterPicker(int locationIndex) async {
    await _openCharacterPickerForForm(_forms[locationIndex]);
  }

  Future<void> _openCharacterPickerForForm(_LocationForm form) async {
    final characters = await widget.repository.loadSavedCharacters();
    if (!mounted) return;
    setState(() => _finalCharacters = characters);
    if (characters.isEmpty) {
      _showError('There are no characters yet.');
      return;
    }

    final blockedIds = _boundCharacterIdsExceptForm(form);
    final currentIds = form.selectedCharacterIds.toSet();
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

    final selectedIds = await showGenesisModalBottomSheet<List<String>>(
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
      form.selectedCharacterIds = selectedIds;
    });
    _onFormChanged();
  }

  Set<String> _boundCharacterIdsExceptForm(_LocationForm excludedForm) {
    final ids = <String>{};
    for (final form in _allL3Forms) {
      if (identical(form, excludedForm)) continue;
      ids.addAll(form.selectedCharacterIds);
    }
    return ids;
  }

  Future<void> _saveLocations() async {
    if (widget.useLocationTree) {
      for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
        final l1 = _treeForms[l1Index];
        if (l1.name.text.trim().isEmpty) {
          _showError('L1 ${l1Index + 1}: Location Name is required.');
          return;
        }
        for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
          final l2 = l1.children[l2Index];
          if (l2.name.text.trim().isEmpty) {
            _showError(
              'L2 ${l1Index + 1}.${l2Index + 1}: Location Name is required.',
            );
            return;
          }
          for (int l3Index = 0; l3Index < l2.children.length; l3Index++) {
            if (l2.children[l3Index].name.text.trim().isEmpty) {
              _showError(
                'L3 ${l1Index + 1}.${l2Index + 1}.${l3Index + 1}: Location Name is required.',
              );
              return;
            }
          }
        }
      }
    } else {
      for (int i = 0; i < _forms.length; i++) {
        final form = _forms[i];
        if (!form.hasContent) continue;
        if (form.name.text.trim().isEmpty) {
          _showError('Location ${i + 1}: Location Name is required.');
          return;
        }
      }
    }

    final currentLocations = _snapshotLocations()
        .where(_locationDraftHasContent)
        .toList(growable: false);
    if (currentLocations.isEmpty) {
      _showError('Please create at least one location.');
      return;
    }

    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    _finalCharacters = await widget.repository.loadSavedCharacters();
    final locations = _snapshotLocations()
        .where(_locationDraftHasContent)
        .toList(growable: false);

    await widget.repository.saveFinalDraft(
      draft.copyWith(
        locations: locations,
        locationsSaved: locations.isNotEmpty,
      ),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  bool get _canSaveCurrentLocations {
    if (widget.useLocationTree) {
      if (_treeForms.isEmpty || _l3LocationCount == 0) return false;
      for (final l1 in _treeForms) {
        if (l1.name.text.trim().isEmpty || l1.children.isEmpty) return false;
        for (final l2 in l1.children) {
          if (l2.name.text.trim().isEmpty || l2.children.isEmpty) return false;
          if (l2.children.any((item) => item.name.text.trim().isEmpty)) {
            return false;
          }
        }
      }
      return true;
    }
    var hasCompleteLocation = false;
    for (final form in _forms) {
      if (!form.hasContent) continue;
      if (form.name.text.trim().isEmpty) return false;
      hasCompleteLocation = true;
    }
    return hasCompleteLocation;
  }

  bool get _canUseSaveButton {
    if (_isSaving) return false;
    return _canSaveCurrentLocations;
  }

  String get _saveDisabledReason {
    if (_isSaving) return 'Saving is already in progress.';
    if (widget.useLocationTree) {
      if (_treeForms.isEmpty) return 'Add at least one L1 location.';
      for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
        final l1 = _treeForms[l1Index];
        if (l1.name.text.trim().isEmpty) {
          return 'L1 ${l1Index + 1}: Location Name is required.';
        }
        if (l1.children.isEmpty) {
          return 'L1 ${l1Index + 1} must contain at least one L2 location.';
        }
        for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
          final l2 = l1.children[l2Index];
          if (l2.name.text.trim().isEmpty) {
            return 'L2 ${l1Index + 1}.${l2Index + 1}: Location Name is required.';
          }
          if (l2.children.isEmpty) {
            return 'L2 ${l1Index + 1}.${l2Index + 1} must contain at least one L3 location.';
          }
          for (int l3Index = 0; l3Index < l2.children.length; l3Index++) {
            if (l2.children[l3Index].name.text.trim().isEmpty) {
              return 'L3 ${l1Index + 1}.${l2Index + 1}.${l3Index + 1}: Location Name is required.';
            }
          }
        }
      }
    } else {
      for (int index = 0; index < _forms.length; index++) {
        final form = _forms[index];
        if (!form.hasContent) continue;
        if (form.name.text.trim().isEmpty) {
          return 'Location ${index + 1}: Location Name is required.';
        }
      }
      if (!_forms.any((form) => form.hasContent)) {
        return 'Please create at least one location.';
      }
    }
    return 'Complete all required location fields before saving.';
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  List<Widget> _editorChildren() {
    if (!widget.useLocationTree) {
      return <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_forms.length}/$_maxLocations (Added / Max)',
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
            Text('L1: $_l1LocationCount', style: _locationCountStyle),
            Text('L2: $_l2LocationCount', style: _locationCountStyle),
            Text(
              'L3: $_l3LocationCount/$_maxLocations (Added/Max)',
              style: _locationCountStyle,
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
        label: '+ Add L1 Location',
        displayId: 'Loc_${_treeForms.length + 1}',
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
            displayId: 'Loc_${l1Index + 1}',
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
                label: '+ Add L2 Location',
                displayId: 'Loc_${l1Index + 1}_${l1.children.length + 1}',
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
                displayId: 'Loc_${l1Index + 1}_${l2Index + 1}',
                controller: l2.name,
                hintText: 'eg. Main Street',
                onDelete: () => _removeL2Location(l1, l2),
                deleteEnabled: l1.children.length > 1,
                onDeleteDisabled: () => _showError(
                  'Each L1 location must contain at least one L2 location.',
                ),
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
                            '(ID: Loc_${l1Index + 1}_${l2Index + 1}_${l3Index + 1})',
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
                        onDeleteDisabled: () => _showError(
                          'Each L2 location must contain at least one L3 location.',
                        ),
                      ),
                    ),
                    if (l3Index + 1 < l2.children.length)
                      const _LocationTreeVerticalGap(lineLeft: -12),
                  ],
                  _LocationTreeGuide(
                    lineLeft: -12,
                    child: _LocationTreeAddButton(
                      key: ValueKey<String>('create-add-l3-${l2.locationId}'),
                      label: '+ Add L3 Location',
                      displayId:
                          'Loc_${l1Index + 1}_${l2Index + 1}_${l2.children.length + 1}',
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
                          text: ' (ID: $displayId)',
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

  List<WorldMapLocationNode> _previewLocationNodes() {
    if (!widget.useLocationTree) return const <WorldMapLocationNode>[];
    final charactersById = <String, CharacterDraft>{
      for (final character in _finalCharacters)
        if (character.charId.trim().isNotEmpty)
          character.charId.trim(): character,
    };
    return <WorldMapLocationNode>[
      for (final l1 in _treeForms)
        WorldMapLocationNode(
          id: l1.locationId,
          point: _previewPoint(
            id: l1.locationId,
            name: _previewName(l1.name, 'L1 Location'),
            depth: 0,
            isLeaf: false,
          ),
          children: <WorldMapLocationNode>[
            for (final l2 in l1.children)
              WorldMapLocationNode(
                id: l2.locationId,
                point: _previewPoint(
                  id: l2.locationId,
                  name: _previewName(l2.name, 'L2 Location'),
                  depth: 1,
                  isLeaf: false,
                ),
                children: <WorldMapLocationNode>[
                  for (final l3 in l2.children)
                    WorldMapLocationNode(
                      id: l3.locationId,
                      point: _previewPoint(
                        id: l3.locationId,
                        name: _previewName(l3.name, 'L3 Location'),
                        depth: 2,
                        imageUrl: l3.imageUrl.text.trim(),
                        description: l3.description.text.trim(),
                        users: _previewUsers(l3, charactersById),
                      ),
                    ),
                ],
              ),
          ],
        ),
    ];
  }

  List<WorldPoint> _previewFlatPoints() {
    if (widget.useLocationTree) return const <WorldPoint>[];
    final charactersById = <String, CharacterDraft>{
      for (final character in _finalCharacters)
        if (character.charId.trim().isNotEmpty)
          character.charId.trim(): character,
    };
    return <WorldPoint>[
      for (final form in _forms)
        _previewPoint(
          id: form.locationId,
          name: _previewName(form.name, 'Location'),
          depth: form.level > 0 ? form.level - 1 : 0,
          imageUrl: form.imageUrl.text.trim(),
          description: form.description.text.trim(),
          users: _previewUsers(form, charactersById),
        ),
    ];
  }

  WorldPoint _previewPoint({
    required String id,
    required String name,
    required int depth,
    String imageUrl = '',
    String description = '',
    List<UserAvatar> users = const <UserAvatar>[],
    bool isLeaf = true,
  }) {
    return WorldPoint(
      id: id,
      sceneId: id,
      pointId: id,
      name: name,
      type: WorldPointType.portal,
      position: Offset.zero,
      users: users,
      iconUrl: imageUrl,
      description: description,
      locationDescription: description,
      depth: depth,
      isLeafLocation: isLeaf,
    );
  }

  List<UserAvatar> _previewUsers(
    _LocationForm form,
    Map<String, CharacterDraft> charactersById,
  ) {
    return form.selectedCharacterIds
        .map((id) => charactersById[id.trim()])
        .whereType<CharacterDraft>()
        .map((character) {
          final name = character.name.trim();
          return UserAvatar(
            name,
            id: character.charId.trim(),
            name: name,
            avatarUrl: character.avatarUrl.trim(),
            showStar: true,
          );
        })
        .toList(growable: false);
  }

  String _previewName(TextEditingController controller, String fallback) {
    final name = controller.text.trim();
    return name.isEmpty ? fallback : name;
  }

  Widget _buildLocationsList({required bool editable}) {
    return WorldLocationList(
      key: ValueKey<String>(
        editable ? 'locations-edit-list' : 'locations-preview-list',
      ),
      points: _previewFlatPoints(),
      locationNodes: _previewLocationNodes(),
      enableOuterScrollHandoff: false,
      physics: const ClampingScrollPhysics(),
      padding: editable
          ? const EdgeInsets.fromLTRB(12, 8, 12, 32)
          : const EdgeInsets.fromLTRB(12, 14, 12, 32),
      onNodeHeaderTap: editable ? _beginInlineNameEdit : null,
      nodeHeaderBuilder: editable ? _buildInlineNodeHeader : null,
      nodeFooterBuilder: editable ? _buildNodeFooter : null,
      onPointTap: editable ? _openLeafEditor : null,
      header: editable ? _buildEditTreeHeader() : null,
      footer: editable ? _buildTreeRootFooter() : null,
    );
  }

  Widget _buildEditTreeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            key: const ValueKey<String>('create-location-l3-count'),
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('L1: $_l1LocationCount', style: _locationCountStyle),
              Text('L2: $_l2LocationCount', style: _locationCountStyle),
              Text(
                'L3: $_l3LocationCount/$_maxLocations (Added/Max)',
                style: _locationCountStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPreviewBody() {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(child: _buildLocationsList(editable: false)),
          _buildBottomSaveAction(),
        ],
      ),
    );
  }

  Widget _buildEditBody() {
    if (!widget.useLocationTree) {
      return CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _editorChildren(),
                  ),
                ),
              ),
              _buildBottomSaveAction(),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissInlineEditor,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildLocationsList(editable: true)),
            _buildBottomSaveAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSaveAction() {
    return _KeyboardHiddenBottomAction(
      minimum: const EdgeInsets.fromLTRB(28, 8, 28, 14),
      child: GenesisPrimaryButton(
        label: _isSaving ? 'Saving...' : 'Save',
        width: _primaryActionButtonWidth(context),
        onPressed: _canUseSaveButton ? _saveLocations : null,
        onDisabledPressed: () => _showError(_saveDisabledReason),
      ),
    );
  }

  @override
  void dispose() {
    _inlineNameFocusNode.dispose();
    for (final form in _forms) {
      form.dispose();
    }
    for (final form in _treeForms) {
      form.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: GenesisBackAppBar(
        pageName: 'Locations',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Transform.translate(
              offset: const Offset(0, 1.2),
              child: _LocationsModeSwitch(mode: _mode, onChanged: _setMode),
            ),
          ),
        ],
      ),
      body: _mode == _LocationsEditorMode.preview
          ? _buildPreviewBody()
          : _buildEditBody(),
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
      child: InkWell(
        key: ValueKey<String>(
          nextMode == _LocationsEditorMode.preview
              ? 'locations-mode-preview'
              : 'locations-mode-edit',
        ),
        onTap: () => onChanged(nextMode),
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
    required this.controller,
    required this.focusNode,
    required this.level,
    required this.hintText,
    required this.onChanged,
    required this.onEditingComplete,
    required this.saveButtonKey,
    required this.onDelete,
    required this.deleteEnabled,
    required this.onDeleteDisabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int level;
  final String hintText;
  final VoidCallback onChanged;
  final VoidCallback onEditingComplete;
  final Key saveButtonKey;
  final VoidCallback onDelete;
  final bool deleteEnabled;
  final VoidCallback onDeleteDisabled;

  @override
  Widget build(BuildContext context) {
    final prefixStyle = level == 0
        ? const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          )
        : const TextStyle(
            color: Colors.black,
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w600,
          );
    return Padding(
      padding: EdgeInsets.only(left: level * 15.0),
      child: TextFieldTapRegion(
        groupId: createFormTextFieldTapRegionGroup,
        consumeOutsideTaps: true,
        onTapOutside: (_) => onEditingComplete(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.translate(
              offset: const Offset(0, 5),
              child: Text('-', style: prefixStyle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Transform.translate(
                offset: Offset(0, level == 0 ? -3 : -6.5),
                child: CreateTextFieldBlock(
                  controller: controller,
                  focusNode: focusNode,
                  label: '',
                  hintText: hintText,
                  maxLength: 25,
                  maxLines: 1,
                  counterInside: true,
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
      ),
    );
  }
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

class _L3LocationTarget {
  const _L3LocationTarget({
    required this.parent,
    required this.form,
    required this.l1Index,
    required this.l2Index,
    required this.l3Index,
  });

  final _L2LocationForm parent;
  final _LocationForm form;
  final int l1Index;
  final int l2Index;
  final int l3Index;
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
    required this.displayId,
    required this.onTap,
  });

  final String label;
  final String displayId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CreateInlineAddButton(
      label: label,
      supportingText: '(ID: $displayId)',
      onTap: onTap,
    );
  }
}

class _L1LocationForm {
  _L1LocationForm({
    required this.locationId,
    required this.name,
    required this.children,
  });

  final String locationId;
  final TextEditingController name;
  final List<_L2LocationForm> children;
  int nextChildOrdinal = 1;

  void dispose() {
    name.dispose();
    for (final child in children) {
      child.dispose();
    }
  }
}

class _L2LocationForm {
  _L2LocationForm({
    required this.locationId,
    required this.name,
    required this.children,
  });

  final String locationId;
  final TextEditingController name;
  final List<_LocationForm> children;
  int nextChildOrdinal = 1;

  void dispose() {
    name.dispose();
    for (final child in children) {
      child.dispose();
    }
  }
}

int? _trailingLocationOrdinal(String locationId) {
  final match = RegExp(r'(\d+)$').firstMatch(locationId.trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}
