part of 'origin_editor_pages.dart';

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

  final List<_LocationForm> _forms = <_LocationForm>[];
  final List<_L1LocationForm> _treeForms = <_L1LocationForm>[];
  String _uid = 'anonymous';
  List<CharacterDraft> _finalCharacters = const <CharacterDraft>[];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
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
    final hasHierarchy = populated.any(
      (item) => item.level >= 1 && item.level <= 3,
    );
    if (!hasHierarchy) {
      final root = _newL1Location(1);
      if (populated.isNotEmpty) {
        final l2 = root.children.single;
        for (final leaf in l2.children) {
          leaf.dispose();
        }
        l2.children
          ..clear()
          ..addAll([
            for (int index = 0; index < populated.length; index++)
              _LocationForm.treeLeaf(
                locationId: '${l2.locationId}_${index + 1}',
                parentLocationId: l2.locationId,
                draft: populated[index],
              ),
          ]);
        l2.nextChildOrdinal = populated.length + 1;
      }
      return <_L1LocationForm>[root];
    }

    final l1Drafts = populated
        .where((item) => item.level == 1)
        .toList(growable: false);
    final trees = <_L1LocationForm>[];
    for (int l1Index = 0; l1Index < l1Drafts.length; l1Index++) {
      final l1Draft = l1Drafts[l1Index];
      final l1Id = l1Draft.locationId.trim().isEmpty
          ? 'Loc_${l1Index + 1}'
          : l1Draft.locationId.trim();
      final l1 = _L1LocationForm(
        locationId: l1Id,
        name: TextEditingController(text: l1Draft.name),
        children: <_L2LocationForm>[],
      );
      final l2Drafts = populated
          .where(
            (item) =>
                item.level == 2 &&
                item.parentLocationId.trim() == l1Draft.locationId.trim(),
          )
          .toList(growable: false);
      for (int l2Index = 0; l2Index < l2Drafts.length; l2Index++) {
        final l2Draft = l2Drafts[l2Index];
        final l2Id = l2Draft.locationId.trim().isEmpty
            ? '${l1.locationId}_${l2Index + 1}'
            : l2Draft.locationId.trim();
        final l2 = _L2LocationForm(
          locationId: l2Id,
          name: TextEditingController(text: l2Draft.name),
          children: <_LocationForm>[],
        );
        final l3Drafts = populated
            .where(
              (item) =>
                  item.level == 3 &&
                  item.parentLocationId.trim() == l2Draft.locationId.trim(),
            )
            .toList(growable: false);
        for (int l3Index = 0; l3Index < l3Drafts.length; l3Index++) {
          final l3Draft = l3Drafts[l3Index];
          l2.children.add(
            _LocationForm.treeLeaf(
              locationId: l3Draft.locationId.trim().isEmpty
                  ? '${l2.locationId}_${l3Index + 1}'
                  : l3Draft.locationId.trim(),
              parentLocationId: l2.locationId,
              draft: l3Draft,
            ),
          );
        }
        if (l2.children.isEmpty) {
          l2.children.add(_newL3Location(l2, 1));
        }
        l2.nextChildOrdinal = l2.children.length + 1;
        l1.children.add(l2);
      }
      if (l1.children.isEmpty) {
        l1.children.add(_newL2Location(l1, 1));
      }
      l1.nextChildOrdinal = l1.children.length + 1;
      trees.add(l1);
    }
    return trees.isEmpty ? <_L1LocationForm>[_newL1Location(1)] : trees;
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
    setState(() {
      if (_treeForms.length == 1) {
        form.name.clear();
        for (final child in form.children) {
          child.dispose();
        }
        form.children
          ..clear()
          ..add(_newL2Location(form, 1));
        form.nextChildOrdinal = 2;
      } else {
        _treeForms.remove(form);
        form.dispose();
      }
    });
    _onFormChanged();
  }

  void _removeL2Location(_L1LocationForm parent, _L2LocationForm form) {
    setState(() {
      if (parent.children.length == 1) {
        form.name.clear();
        for (final child in form.children) {
          child.dispose();
        }
        form.children
          ..clear()
          ..add(_newL3Location(form, 1));
        form.nextChildOrdinal = 2;
      } else {
        parent.children.remove(form);
        form.dispose();
      }
    });
    _onFormChanged();
  }

  void _removeL3Location(_L2LocationForm parent, _LocationForm form) {
    setState(() {
      if (parent.children.length == 1) {
        form.clear();
      } else {
        parent.children.remove(form);
        form.dispose();
      }
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
            name: form.name.text.trim(),
            description: form.description.text.trim(),
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
        alignment: Alignment.centerRight,
        child: Text(
          '$_l3LocationCount/$_maxLocations (L3 Added / Max)',
          key: const ValueKey<String>('create-location-l3-count'),
          style: const TextStyle(
            color: createFormText,
            fontSize: 14,
            height: 1.2,
          ),
        ),
      ),
      const SizedBox(height: 12),
      for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) ...[
        _buildL1Branch(_treeForms[l1Index], l1Index),
        const SizedBox(height: 24),
      ],
      CreateAddButton(
        key: const ValueKey<String>('create-add-l1-location'),
        label: '+ Add L1 Location',
        onTap: _addL1Location,
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _buildL1Branch(_L1LocationForm l1, int l1Index) {
    return Container(
      key: ValueKey<String>('create-location-l1-${l1.locationId}'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: createFormBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CreateTextFieldBlock(
                  key: ValueKey<String>('create-location-l1-name-$l1Index'),
                  label: 'L1 Location name *',
                  controller: l1.name,
                  hintText: 'eg. Downtown',
                  maxLength: 25,
                  maxLines: 1,
                  labelInputGap: 8,
                  onChanged: (_) => _onFormChanged(),
                ),
              ),
              const SizedBox(width: 10),
              CreateFormDeleteButton(onPressed: () => _removeL1Location(l1)),
            ],
          ),
          const SizedBox(height: 18),
          for (int l2Index = 0; l2Index < l1.children.length; l2Index++) ...[
            _buildL2Branch(l1, l1.children[l2Index], l1Index, l2Index),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: CreateAddButton(
              key: ValueKey<String>('create-add-l2-${l1.locationId}'),
              label: '+ Add L2 Location',
              onTap: () => _addL2Location(l1),
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
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Container(
        key: ValueKey<String>('create-location-l2-${l2.locationId}'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: createFormBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CreateTextFieldBlock(
                    key: ValueKey<String>(
                      'create-location-l2-name-$l1Index-$l2Index',
                    ),
                    label: 'L2 Location name *',
                    controller: l2.name,
                    hintText: 'eg. Main Street',
                    maxLength: 25,
                    maxLines: 1,
                    labelInputGap: 8,
                    onChanged: (_) => _onFormChanged(),
                  ),
                ),
                const SizedBox(width: 10),
                CreateFormDeleteButton(
                  onPressed: () => _removeL2Location(l1, l2),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (int l3Index = 0; l3Index < l2.children.length; l3Index++) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _LocationCard(
                  key: ValueKey<String>(
                    'create-location-l3-${l2.children[l3Index].locationId}',
                  ),
                  index: l3Index + 1,
                  title: 'L3 Location (ID: ${l2.children[l3Index].locationId})',
                  form: l2.children[l3Index],
                  nextFocusNode: null,
                  characters: _finalCharacters,
                  onChanged: _onFormChanged,
                  onPickCharacters: () =>
                      _openCharacterPickerForForm(l2.children[l3Index]),
                  onRemoveCharacter: (charId) =>
                      _removeCharacterFromForm(l2.children[l3Index], charId),
                  onDelete: () => _removeL3Location(l2, l2.children[l3Index]),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: CreateAddButton(
                key: ValueKey<String>('create-add-l3-${l2.locationId}'),
                label: '+ Add L3 Location',
                onTap: () => _addL3Location(l2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
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
      appBar: const GenesisBackAppBar(pageName: 'Locations'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _editorChildren(),
                  ),
                ),
              ),
              _KeyboardHiddenBottomAction(
                minimum: const EdgeInsets.fromLTRB(28, 8, 28, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  width: _primaryActionButtonWidth(context),
                  onPressed: _canUseSaveButton ? _saveLocations : null,
                ),
              ),
            ],
          ),
        ),
      ),
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
