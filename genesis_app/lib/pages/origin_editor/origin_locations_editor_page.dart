part of 'origin_editor_pages.dart';

enum _LocationEditorSheetAction { delete }

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

class _OriginLocationsEditorPageState extends State<OriginLocationsEditorPage>
    with TickerProviderStateMixin {
  static const int _maxLocations = 10;

  final List<_LocationForm> _forms = <_LocationForm>[];
  final List<_L1LocationForm> _treeForms = <_L1LocationForm>[];
  String _uid = 'anonymous';
  List<CharacterDraft> _finalCharacters = const <CharacterDraft>[];
  bool _isLoading = true;
  bool _isSaving = false;
  TabController? _l1TabController;
  int _selectedL1Index = 0;

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
      if (!mounted) return;
      _replaceL1TabController(selectedIndex: 0);
    } else {
      for (final item in source) {
        _forms.add(_LocationForm.fromDraft(item, uid: _uid));
      }
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _replaceL1TabController({required int selectedIndex}) {
    final previousController = _l1TabController;
    if (_treeForms.isEmpty) {
      _selectedL1Index = 0;
      _l1TabController = null;
    } else {
      _selectedL1Index = selectedIndex.clamp(0, _treeForms.length - 1);
      _l1TabController = TabController(
        length: _treeForms.length,
        vsync: this,
        initialIndex: _selectedL1Index,
      );
    }
    previousController?.dispose();
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
    setState(() {
      _treeForms.add(_newL1Location(_nextL1Ordinal));
      _replaceL1TabController(selectedIndex: _treeForms.length - 1);
    });
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
      final removedIndex = _treeForms.indexOf(form);
      _treeForms.remove(form);
      form.dispose();
      final nextSelectedIndex = removedIndex < _selectedL1Index
          ? _selectedL1Index - 1
          : _selectedL1Index;
      _replaceL1TabController(selectedIndex: nextSelectedIndex);
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

  List<WorldMapLocationNode> get _treePreviewNodes {
    if (_treeForms.isEmpty) return const <WorldMapLocationNode>[];
    final selectedIndex = _selectedL1Index.clamp(0, _treeForms.length - 1);
    return <WorldMapLocationNode>[
      _previewL1Node(_treeForms[selectedIndex], selectedIndex),
    ];
  }

  WorldMapLocationNode _previewL1Node(_L1LocationForm l1, int l1Index) {
    return WorldMapLocationNode(
      id: 'origin-editor-l1-$l1Index',
      point: _previewPoint(
        id: l1.locationId,
        name: l1.name.text,
        fallbackName: 'Untitled L1 Location',
        depth: 0,
        isLeaf: false,
      ),
      children: <WorldMapLocationNode>[
        for (int l2Index = 0; l2Index < l1.children.length; l2Index++)
          _previewL2Node(l1.children[l2Index], l1Index, l2Index),
      ],
    );
  }

  WorldMapLocationNode _previewL2Node(
    _L2LocationForm l2,
    int l1Index,
    int l2Index,
  ) {
    return WorldMapLocationNode(
      id: 'origin-editor-l2-$l1Index-$l2Index',
      point: _previewPoint(
        id: l2.locationId,
        name: l2.name.text,
        fallbackName: 'Untitled L2 Location',
        depth: 1,
        isLeaf: false,
      ),
      children: <WorldMapLocationNode>[
        for (int l3Index = 0; l3Index < l2.children.length; l3Index++)
          _previewL3Node(l2.children[l3Index], l1Index, l2Index, l3Index),
      ],
    );
  }

  WorldMapLocationNode _previewL3Node(
    _LocationForm l3,
    int l1Index,
    int l2Index,
    int l3Index,
  ) {
    return WorldMapLocationNode(
      id: 'origin-editor-l3-$l1Index-$l2Index-$l3Index',
      point: _previewPoint(
        id: l3.locationId,
        name: l3.name.text,
        fallbackName: 'Untitled L3 Location',
        imageUrl: l3.imageUrl.text,
        users: _previewInitialCharacters(l3),
        depth: 2,
        isLeaf: true,
      ),
    );
  }

  WorldPoint _previewPoint({
    required String id,
    required String name,
    required String fallbackName,
    required int depth,
    required bool isLeaf,
    String imageUrl = '',
    List<UserAvatar> users = const <UserAvatar>[],
  }) {
    final trimmedId = id.trim();
    final trimmedName = name.trim();
    return WorldPoint(
      id: trimmedId,
      sceneId: trimmedId,
      name: trimmedName.isEmpty ? fallbackName : trimmedName,
      type: WorldPointType.castle,
      position: Offset.zero,
      users: users,
      iconUrl: imageUrl.trim(),
      depth: depth,
      isLeafLocation: isLeaf,
    );
  }

  List<UserAvatar> _previewInitialCharacters(_LocationForm form) {
    final charactersById = <String, CharacterDraft>{
      for (final character in _finalCharacters)
        if (character.charId.trim().isNotEmpty)
          character.charId.trim(): character,
    };
    return form.selectedCharacterIds
        .map((id) => charactersById[id.trim()])
        .whereType<CharacterDraft>()
        .map((character) {
          final name = character.name.trim();
          return UserAvatar(
            name.isEmpty ? '?' : name,
            id: character.charId.trim(),
            name: name,
            avatarUrl: character.avatarUrl.trim(),
            showStar: true,
          );
        })
        .toList(growable: false);
  }

  void _openPreviewNode(WorldMapLocationNode node) {
    final parts = node.id.split('-');
    if (parts.length < 4 || parts[0] != 'origin' || parts[1] != 'editor') {
      return;
    }
    final level = parts[2];
    final l1Index = int.tryParse(parts[3]);
    if (l1Index == null || l1Index < 0 || l1Index >= _treeForms.length) {
      return;
    }
    if (level == 'l1') {
      unawaited(_showL1Editor(l1Index));
      return;
    }
    if (parts.length < 5) return;
    final l2Index = int.tryParse(parts[4]);
    if (l2Index == null ||
        l2Index < 0 ||
        l2Index >= _treeForms[l1Index].children.length) {
      return;
    }
    if (level == 'l2') {
      unawaited(_showL2Editor(l1Index, l2Index));
      return;
    }
    if (level != 'l3' || parts.length < 6) return;
    final l3Index = int.tryParse(parts[5]);
    if (l3Index == null ||
        l3Index < 0 ||
        l3Index >= _treeForms[l1Index].children[l2Index].children.length) {
      return;
    }
    unawaited(_showL3Editor(l1Index, l2Index, l3Index));
  }

  Future<void> _addL1AndEdit() async {
    final previousCount = _treeForms.length;
    _addL1Location();
    if (!mounted || _treeForms.length == previousCount) return;
    await _showL1Editor(_treeForms.length - 1, isNew: true);
  }

  Future<void> _addL2AndEdit(int l1Index) async {
    if (l1Index < 0 || l1Index >= _treeForms.length) return;
    final l1 = _treeForms[l1Index];
    final previousCount = l1.children.length;
    _addL2Location(l1);
    if (!mounted || l1.children.length == previousCount) return;
    await _showL2Editor(l1Index, l1.children.length - 1, isNew: true);
  }

  Future<void> _addL3AndEdit(int l1Index, int l2Index) async {
    if (l1Index < 0 || l1Index >= _treeForms.length) return;
    final l1 = _treeForms[l1Index];
    if (l2Index < 0 || l2Index >= l1.children.length) return;
    final l2 = l1.children[l2Index];
    final previousCount = l2.children.length;
    _addL3Location(l2);
    if (!mounted || l2.children.length == previousCount) return;
    await _showL3Editor(l1Index, l2Index, l2.children.length - 1, isNew: true);
  }

  Future<void> _showL1Editor(int l1Index, {bool isNew = false}) async {
    if (l1Index < 0 || l1Index >= _treeForms.length) return;
    final l1 = _treeForms[l1Index];
    final action =
        await showGenesisModalBottomSheet<_LocationEditorSheetAction>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) {
            return GenesisBottomSheetPanel(
              title: isNew ? 'New Location' : 'Edit Location',
              height: MediaQuery.sizeOf(sheetContext).height * 0.52,
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 14),
              trailing: GenesisBottomSheetCloseButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
              child: CreateKeyboardDismissArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTreeLocationNameField(
                              key: ValueKey<String>(
                                'create-location-l1-name-$l1Index',
                              ),
                              title: 'L1 Location',
                              displayId: 'Loc_${l1Index + 1}',
                              controller: l1.name,
                              hintText: 'eg. Downtown',
                              onDelete: () => Navigator.of(
                                sheetContext,
                              ).pop(_LocationEditorSheetAction.delete),
                              deleteEnabled: _treeForms.length > 1,
                              onDeleteDisabled: () => _showError(
                                'At least one L1 location is required.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GenesisPrimaryButton(
                      label: 'Done',
                      width: _primaryActionButtonWidth(sheetContext),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
    if (!mounted) return;
    switch (action) {
      case _LocationEditorSheetAction.delete:
        _removeL1Location(l1);
      case null:
        setState(() {});
    }
  }

  Future<void> _showL2Editor(
    int l1Index,
    int l2Index, {
    bool isNew = false,
  }) async {
    if (l1Index < 0 || l1Index >= _treeForms.length) return;
    final l1 = _treeForms[l1Index];
    if (l2Index < 0 || l2Index >= l1.children.length) return;
    final l2 = l1.children[l2Index];
    final action = await showGenesisModalBottomSheet<_LocationEditorSheetAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return GenesisBottomSheetPanel(
          title: isNew ? 'New Location' : 'Edit Location',
          height: MediaQuery.sizeOf(sheetContext).height * 0.52,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 14),
          trailing: GenesisBottomSheetCloseButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
          child: CreateKeyboardDismissArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTreeLocationNameField(
                          key: ValueKey<String>(
                            'create-location-l2-name-$l1Index-$l2Index',
                          ),
                          title: 'L2 Location',
                          displayId: 'Loc_${l1Index + 1}_${l2Index + 1}',
                          controller: l2.name,
                          hintText: 'eg. Main Street',
                          onDelete: () => Navigator.of(
                            sheetContext,
                          ).pop(_LocationEditorSheetAction.delete),
                          deleteEnabled: l1.children.length > 1,
                          onDeleteDisabled: () => _showError(
                            'Each L1 location must contain at least one L2 location.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GenesisPrimaryButton(
                  label: 'Done',
                  width: _primaryActionButtonWidth(sheetContext),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    switch (action) {
      case _LocationEditorSheetAction.delete:
        _removeL2Location(l1, l2);
      case null:
        setState(() {});
    }
  }

  Future<void> _showL3Editor(
    int l1Index,
    int l2Index,
    int l3Index, {
    bool isNew = false,
  }) async {
    if (l1Index < 0 || l1Index >= _treeForms.length) return;
    final l1 = _treeForms[l1Index];
    if (l2Index < 0 || l2Index >= l1.children.length) return;
    final l2 = l1.children[l2Index];
    if (l3Index < 0 || l3Index >= l2.children.length) return;
    final l3 = l2.children[l3Index];
    final action = await showGenesisModalBottomSheet<_LocationEditorSheetAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return GenesisBottomSheetPanel(
              title: isNew ? 'New Location' : 'Edit Location',
              height: MediaQuery.sizeOf(sheetContext).height * 0.82,
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 14),
              trailing: GenesisBottomSheetCloseButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
              child: CreateKeyboardDismissArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _LocationCard(
                          key: ValueKey<String>(
                            'create-location-l3-${l3.locationId}',
                          ),
                          index: l3Index + 1,
                          title: 'L3 Location',
                          titleSuffix:
                              '(ID: Loc_${l1Index + 1}_${l2Index + 1}_${l3Index + 1})',
                          showBorder: false,
                          titleFontSize: 14,
                          nameFieldLabel: 'Name *',
                          fieldLabelFontWeight: FontWeight.w400,
                          form: l3,
                          nextFocusNode: null,
                          characters: _finalCharacters,
                          onChanged: _onFormChanged,
                          onPickCharacters: () async {
                            await _openCharacterPickerForForm(l3);
                            if (sheetContext.mounted) {
                              setSheetState(() {});
                            }
                          },
                          onRemoveCharacter: (charId) {
                            _removeCharacterFromForm(l3, charId);
                            setSheetState(() {});
                          },
                          onDelete: () => Navigator.of(
                            sheetContext,
                          ).pop(_LocationEditorSheetAction.delete),
                          deleteEnabled: l2.children.length > 1,
                          onDeleteDisabled: () => _showError(
                            'Each L2 location must contain at least one L3 location.',
                          ),
                        ),
                      ),
                    ),
                    GenesisPrimaryButton(
                      label: 'Done',
                      width: _primaryActionButtonWidth(sheetContext),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (action == _LocationEditorSheetAction.delete) {
      _removeL3Location(l2, l3);
    } else {
      setState(() {});
    }
  }

  Widget? _buildPreviewNodeFooter(
    BuildContext context,
    WorldMapLocationNode node,
    int level,
  ) {
    final parts = node.id.split('-');
    if (parts.length < 4 || parts[0] != 'origin' || parts[1] != 'editor') {
      return null;
    }
    final l1Index = int.tryParse(parts[3]);
    if (l1Index == null || l1Index < 0 || l1Index >= _treeForms.length) {
      return null;
    }

    final nodeLevel = parts[2];
    late final Widget addButton;
    if (nodeLevel == 'l1') {
      final l1 = _treeForms[l1Index];
      addButton = _LocationTreeAddButton(
        key: ValueKey<String>('create-add-l2-${l1.locationId}'),
        label: '+ Add L2 Location',
        displayId: 'Loc_${l1Index + 1}_${l1.children.length + 1}',
        onTap: () => unawaited(_addL2AndEdit(l1Index)),
      );
    } else if (nodeLevel == 'l2' && parts.length >= 5) {
      final l2Index = int.tryParse(parts[4]);
      final l1 = _treeForms[l1Index];
      if (l2Index == null || l2Index < 0 || l2Index >= l1.children.length) {
        return null;
      }
      final l2 = l1.children[l2Index];
      addButton = _LocationTreeAddButton(
        key: ValueKey<String>('create-add-l3-${l2.locationId}'),
        label: '+ Add L3 Location',
        displayId:
            'Loc_${l1Index + 1}_${l2Index + 1}_${l2.children.length + 1}',
        onTap: () => unawaited(_addL3AndEdit(l1Index, l2Index)),
      );
    } else {
      return null;
    }

    return Padding(
      padding: EdgeInsets.only(left: (level + 1) * 15.0),
      child: addButton,
    );
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

  Widget _buildL1Tabs() {
    final controller = _l1TabController;
    if (controller == null || _treeForms.isEmpty) {
      return const SizedBox.shrink();
    }
    final labels = <String>[
      for (final l1 in _treeForms)
        l1.name.text.trim().isEmpty
            ? 'Untitled L1 Location'
            : l1.name.text.trim(),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      child: Row(
        children: [
          const Text(
            'L1:',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SecendTabs(
              key: ValueKey<int>(_treeForms.length),
              labels: labels,
              controller: controller,
              horizontalPadding: 0,
              labelFontSize: 16,
              verticalPadding: 0,
              onTap: (index) {
                if (index == _selectedL1Index) {
                  unawaited(_showL1Editor(index));
                  return;
                }
                setState(() => _selectedL1Index = index);
              },
            ),
          ),
          SizedBox(
            width: genesisTabHeight,
            height: genesisTabHeight,
            child: IconButton(
              key: const ValueKey<String>('create-add-l1-location'),
              tooltip: 'Add L1 Location',
              padding: EdgeInsets.zero,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () => unawaited(_addL1AndEdit()),
              icon: const Icon(Icons.add, size: 20, color: createFormGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreePreview() {
    return Column(
      children: [
        _buildL1Tabs(),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(overscroll: false),
            child: WorldLocationList(
              key: const ValueKey<String>('origin-location-tree-preview'),
              points: const <WorldPoint>[],
              locationNodes: _treePreviewNodes,
              rootNodeFontSize: 16,
              leafNodeFontWeight: FontWeight.w400,
              leafNodeLineHeight: 1.2,
              leafMetadataSpacing: 8,
              enableOuterScrollHandoff: false,
              hideRootNodeHeaders: true,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
              onNodeTap: _openPreviewNode,
              nodeFooterBuilder: _buildPreviewNodeFooter,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _l1TabController?.dispose();
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : widget.useLocationTree
                    ? _buildTreePreview()
                    : SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
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
                  onDisabledPressed: () => _showError(_saveDisabledReason),
                ),
              ),
            ],
          ),
        ),
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
