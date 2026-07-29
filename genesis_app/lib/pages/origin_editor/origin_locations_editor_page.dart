part of 'origin_editor_pages.dart';

enum _LocationsEditorMode { preview, edit }

enum _L3EditorSheetAction { save, delete }

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
  static const String _statisticsNote =
      'Add up to 10 L3 locations across your location trees.';
  static const String _l1NameNote =
      'Use a broad area name, such as a city or region.';
  static const String _l2NameNote =
      'Use a smaller area within this L1 location.';
  static const String _completeRequiredLocationMessage =
      'Please complete this location or delete it.';
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
  String? _requiredInlineLocationId;
  String? _requiredFlowL1Id;
  final GlobalKey _rootAddL1VisibilityKey = GlobalKey();
  bool _revealRootAddL1AfterKeyboard = false;
  bool _suppressRequiredActionForCurrentTap = false;
  late FocusNode _inlineNameFocusNode;
  late FocusNode _nextInlineNameFocusNode;
  late TextEditingController _inlineNameController;
  late TextEditingController _nextInlineNameController;

  @override
  void initState() {
    super.initState();
    _inlineNameFocusNode = FocusNode();
    _nextInlineNameFocusNode = FocusNode();
    _inlineNameController = TextEditingController();
    _nextInlineNameController = TextEditingController();
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
      _requiredInlineLocationId = _firstIncompleteParentLocationId();
      _inlineEditingLocationId = _requiredInlineLocationId;
      _inlineNameController.text =
          _inlineLocationNameController(_inlineEditingLocationId)?.text ?? '';
    } else {
      for (final item in source) {
        _forms.add(_LocationForm.fromDraft(item, uid: _uid));
      }
    }
    if (!mounted) return;
    setState(() {});
    if (_requiredInlineLocationId != null) {
      _requestInlineNameFocus();
    }
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
      if (l1.name.text.trim().isNotEmpty && l1.children.isEmpty) {
        l1.children.add(_newL2Location(l1, 1));
      }
      l1.nextChildOrdinal = l1.children.length + 1;
      for (final l2 in l1.children) {
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
    return l1;
  }

  _L2LocationForm _newL2Location(_L1LocationForm parent, int ordinal) {
    final l2 = _L2LocationForm(
      locationId: '${parent.locationId}_$ordinal',
      name: TextEditingController(),
      children: <_LocationForm>[],
    );
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

  String? _firstIncompleteParentLocationId() {
    for (final l1 in _treeForms) {
      if (l1.name.text.trim().isEmpty) return l1.locationId;
      for (final l2 in l1.children) {
        if (l2.name.text.trim().isEmpty) return l2.locationId;
      }
    }
    return null;
  }

  TextEditingController? _inlineLocationNameController(String? locationId) {
    if (locationId == null) return null;
    for (final l1 in _treeForms) {
      if (l1.locationId == locationId) return l1.name;
      for (final l2 in l1.children) {
        if (l2.locationId == locationId) return l2.name;
      }
    }
    return null;
  }

  bool _l2HasSavedL3(_L2LocationForm l2) {
    return l2.children.any((form) => form.name.text.trim().isNotEmpty);
  }

  bool _l1HasCompletePath(_L1LocationForm l1) {
    if (l1.name.text.trim().isEmpty) return false;
    return l1.children.any(
      (l2) => l2.name.text.trim().isNotEmpty && _l2HasSavedL3(l2),
    );
  }

  bool get _hasCompleteTree => _treeForms.any(_l1HasCompletePath);

  String _locationNameLabel(
    TextEditingController controller, {
    required String fallback,
  }) {
    final name = controller.text.trim();
    return name.isEmpty ? fallback : '"$name"';
  }

  String _l1NeedsL2Message(_L1LocationForm l1) {
    return '${_locationNameLabel(l1.name, fallback: 'This L1 location')} '
        'must contain at least one L2 location.';
  }

  String _l2NeedsL3Message(_L2LocationForm l2) {
    return '${_locationNameLabel(l2.name, fallback: 'This L2 location')} '
        'must contain at least one L3 location.';
  }

  int get _nextL1Ordinal {
    final used = _treeForms
        .map((item) => _trailingLocationOrdinal(item.locationId))
        .whereType<int>();
    return used.isEmpty ? 1 : used.reduce((a, b) => a > b ? a : b) + 1;
  }

  void _addL1Location() {
    if (_blockForRequiredLocation()) return;
    if (_l3LocationCount >= _maxLocations) {
      _showError('You can add up to $_maxLocations L3 locations.');
      return;
    }
    final form = _newL1Location(_nextL1Ordinal);
    _inlineNameController.clear();
    setState(() {
      _treeForms.add(form);
      _requiredFlowL1Id = form.locationId;
      _requiredInlineLocationId = form.locationId;
      _inlineEditingLocationId = form.locationId;
    });
    _requestInlineNameFocus();
  }

  void _addL2Location(_L1LocationForm parent) {
    if (_blockForRequiredLocation()) return;
    if (_l3LocationCount >= _maxLocations) {
      _showError('You can add up to $_maxLocations L3 locations.');
      return;
    }
    final form = _newL2Location(parent, parent.nextChildOrdinal++);
    _inlineNameController.clear();
    setState(() {
      parent.children.add(form);
      _requiredFlowL1Id = null;
      _requiredInlineLocationId = form.locationId;
      _inlineEditingLocationId = form.locationId;
    });
    _requestInlineNameFocus();
  }

  void _addL3Location(_L2LocationForm parent) {
    if (_blockForRequiredLocation()) return;
    if (_l3LocationCount >= _maxLocations) {
      _showError('You can add up to $_maxLocations L3 locations.');
      return;
    }
    for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
      final l1 = _treeForms[l1Index];
      final l2Index = l1.children.indexOf(parent);
      if (l2Index < 0) continue;
      final form = _newL3Location(parent, parent.nextChildOrdinal);
      unawaited(
        _showL3EditorSheet(
          _L3LocationTarget(
            parent: parent,
            form: form,
            l1Index: l1Index,
            l2Index: l2Index,
            l3Index: parent.children.length,
          ),
          isNew: true,
        ),
      );
      return;
    }
  }

  void _removeL1Location(_L1LocationForm form) {
    if (_treeForms.length == 1) {
      _showError('At least one L1 location is required.');
      return;
    }
    final restoresRootAdd =
        _requiredFlowL1Id == form.locationId ||
        _requiredInlineLocationId == form.locationId;
    if (restoresRootAdd) _markRootAddL1ForReveal();
    _inlineNameFocusNode.unfocus();
    setState(() {
      if (_requiredInlineLocationId == form.locationId ||
          _requiredFlowL1Id == form.locationId) {
        _requiredInlineLocationId = null;
        _requiredFlowL1Id = null;
        _inlineEditingLocationId = null;
      }
      _treeForms.remove(form);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => form.dispose());
  }

  void _removeL2Location(_L1LocationForm parent, _L2LocationForm form) {
    if (parent.children.length == 1) {
      _showError(_l1NeedsL2Message(parent));
      return;
    }
    _inlineNameFocusNode.unfocus();
    setState(() {
      if (_requiredInlineLocationId == form.locationId) {
        _requiredInlineLocationId = null;
        _requiredFlowL1Id = null;
        _inlineEditingLocationId = null;
      }
      parent.children.remove(form);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => form.dispose());
  }

  void _removeL3Location(_L2LocationForm parent, _LocationForm form) {
    if (parent.children.length == 1) {
      _showError(_l2NeedsL3Message(parent));
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
    if (mode == _LocationsEditorMode.preview && _blockForRequiredLocation()) {
      return;
    }
    _inlineEditingLocationId = null;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _mode = mode);
  }

  void _beginInlineNameEdit(WorldPoint point) {
    if (_mode != _LocationsEditorMode.edit || point.isLeafLocation) return;
    if (_blockForRequiredLocation(targetLocationId: point.id)) return;
    _inlineNameController.text =
        _inlineLocationNameController(point.id)?.text ?? '';
    setState(() => _inlineEditingLocationId = point.id);
    _requestInlineNameFocus();
  }

  void _finishInlineNameEdit() {
    final editingId = _inlineEditingLocationId;
    if (editingId == null) return;
    final name = _inlineNameController.text.trim();
    if (name.isEmpty) {
      _showRequiredLocationMessage();
      _requestInlineNameFocus();
      return;
    }

    for (final l1 in _treeForms) {
      if (l1.locationId == editingId) {
        l1.name.text = name;
        if (_requiredInlineLocationId == editingId) {
          if (l1.children.isEmpty) {
            final l2 = _newL2Location(l1, l1.nextChildOrdinal++);
            l1.children.add(l2);
          }
          _L2LocationForm? requiredL2;
          for (final l2 in l1.children) {
            if (l2.name.text.trim().isEmpty) {
              requiredL2 = l2;
              break;
            }
          }
          if (requiredL2 == null) {
            _inlineNameFocusNode.unfocus();
          } else {
            _transferInlineNameInput(requiredL2.name.text);
          }
          setState(() {
            _requiredInlineLocationId = requiredL2?.locationId;
            _inlineEditingLocationId = requiredL2?.locationId;
            if (requiredL2 == null) _requiredFlowL1Id = null;
          });
          if (requiredL2 == null) {
            _inlineNameFocusNode.unfocus();
          }
          return;
        }
        _inlineNameFocusNode.unfocus();
        setState(() => _inlineEditingLocationId = null);
        return;
      }

      for (final l2 in l1.children) {
        if (l2.locationId != editingId) continue;
        l2.name.text = name;
        _inlineNameFocusNode.unfocus();
        setState(() {
          _requiredInlineLocationId = null;
          _requiredFlowL1Id = null;
          _inlineEditingLocationId = null;
        });
        return;
      }
    }
  }

  void _cancelInlineEditForOutsideTap() {
    final retainRequiredL2 =
        _requiredFlowL1Id != null &&
        _requiredInlineLocationId != _requiredFlowL1Id;
    if (!_inlineNameFocusNode.hasFocus &&
        _requiredInlineLocationId != null &&
        (!_hasCompleteTree || retainRequiredL2)) {
      return;
    }
    _suppressRequiredActionForCurrentTap = true;

    final editingId = _inlineEditingLocationId;
    if (editingId == null) return;
    _inlineNameFocusNode.unfocus();

    final requiredId = _requiredInlineLocationId;
    if (requiredId == null) {
      setState(() => _inlineEditingLocationId = null);
      return;
    }

    // Keep the only, guided L1/L2 input visible until the first tree exists.
    if (!_hasCompleteTree) return;

    for (final l1 in _treeForms) {
      if (l1.locationId == editingId) {
        _markRootAddL1ForReveal();
        setState(() {
          _inlineEditingLocationId = null;
          _requiredInlineLocationId = null;
          _requiredFlowL1Id = null;
          _treeForms.remove(l1);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          l1.dispose();
        });
        return;
      }
      for (final l2 in l1.children) {
        if (l2.locationId != editingId) continue;
        final cancelWholeL1 = _requiredFlowL1Id == l1.locationId;
        if (cancelWholeL1) return;
        setState(() {
          _inlineEditingLocationId = null;
          _requiredInlineLocationId = null;
          _requiredFlowL1Id = null;
          l1.children.remove(l2);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          l2.dispose();
        });
        return;
      }
    }
  }

  void _markRootAddL1ForReveal() {
    _revealRootAddL1AfterKeyboard = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealRootAddL1IfReady();
    });
  }

  void _revealRootAddL1IfReady() {
    if (!mounted || !_revealRootAddL1AfterKeyboard || _hasKeyboardViewInset()) {
      return;
    }
    final targetContext = _rootAddL1VisibilityKey.currentContext;
    if (targetContext == null) return;
    _revealRootAddL1AfterKeyboard = false;
    unawaited(
      Scrollable.ensureVisible(
        targetContext,
        duration: Duration.zero,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ),
    );
  }

  Future<void> _confirmAndRemoveLocationBranch({
    required int level,
    required String name,
    required VoidCallback remove,
  }) async {
    _inlineNameFocusNode.unfocus();
    final displayName = name.trim().isEmpty ? 'location' : name.trim();
    final title = 'Delete L$level $displayName and all locations under it?';
    final confirmed = await showGenesisActionBox<bool>(
      context: context,
      title: '',
      titleWidget: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF111111),
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
      titleHeight: 104,
      actions: const [
        GenesisActionBoxAction<bool>(
          label: 'Delete',
          value: true,
          color: Color(0xFFFF2442),
        ),
      ],
      cancelLabel: 'Cancel',
    );
    if (confirmed != true || !mounted) return;
    remove();
  }

  void _removeLocationBranchFromEditor({
    required bool hasChildren,
    required int level,
    required String name,
    required VoidCallback remove,
  }) {
    if (!hasChildren) {
      remove();
      return;
    }
    unawaited(
      _confirmAndRemoveLocationBranch(level: level, name: name, remove: remove),
    );
  }

  void _releaseInlineOutsideTapSuppression() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressRequiredActionForCurrentTap = false;
    });
  }

  bool _blockForRequiredLocation({String? targetLocationId}) {
    if (_suppressRequiredActionForCurrentTap) {
      _suppressRequiredActionForCurrentTap = false;
      return true;
    }
    final requiredId = _requiredInlineLocationId;
    if (requiredId == null || requiredId == targetLocationId) return false;
    _showRequiredLocationMessage();
    _requestInlineNameFocus();
    return true;
  }

  void _showRequiredLocationMessage() {
    _showError(_completeRequiredLocationMessage);
  }

  void _requestInlineNameFocus() {
    final editingId = _inlineEditingLocationId;
    if (editingId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _inlineEditingLocationId != editingId) return;
      _inlineNameFocusNode.requestFocus();
    });
  }

  void _transferInlineNameInput(String text) {
    final previousFocusNode = _inlineNameFocusNode;
    final nextFocusNode = _nextInlineNameFocusNode;
    final previousController = _inlineNameController;
    final nextController = _nextInlineNameController;
    nextController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    nextFocusNode.requestFocus();
    _inlineNameFocusNode = nextFocusNode;
    _nextInlineNameFocusNode = previousFocusNode;
    _inlineNameController = nextController;
    _nextInlineNameController = previousController;
  }

  Widget? _buildInlineNodeHeader(
    BuildContext context,
    WorldPoint point,
    int level,
  ) {
    if (point.isLeafLocation) return null;
    if (_inlineEditingLocationId != point.id) {
      return _InlineTreeLocationPreviewHeader(
        key: ValueKey<String>('world-location-node-header-${point.id}'),
        name: point.name,
        level: level,
        onTap: () => _beginInlineNameEdit(point),
      );
    }
    for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
      final l1 = _treeForms[l1Index];
      if (l1.locationId == point.id) {
        return _InlineTreeLocationNameEditor(
          key: ValueKey<String>('locations-inline-name-${point.id}'),
          testKey: ValueKey<String>(
            'locations-inline-name-content-${point.id}',
          ),
          fieldKey: ValueKey<String>('locations-inline-name-field-${point.id}'),
          controller: _inlineNameController,
          focusNode: _inlineNameFocusNode,
          level: level,
          hintText: 'L1 Location',
          note: _l1NameNote,
          onChanged: _onFormChanged,
          onEditingComplete: _finishInlineNameEdit,
          onTapOutside: _cancelInlineEditForOutsideTap,
          saveButtonKey: ValueKey<String>('locations-inline-save-${point.id}'),
          onDelete: () => _removeLocationBranchFromEditor(
            hasChildren: l1.children.isNotEmpty,
            level: 1,
            name: _inlineNameController.text,
            remove: () => _removeL1Location(l1),
          ),
          deleteEnabled: _treeForms.length > 1,
          onDeleteDisabled: () =>
              _showError('At least one L1 location is required.'),
        );
      }
      for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
        final l2 = l1.children[l2Index];
        if (l2.locationId != point.id) continue;
        final deleteWholeL1 = l1.children.length == 1;
        return _InlineTreeLocationNameEditor(
          key: ValueKey<String>('locations-inline-name-${point.id}'),
          testKey: ValueKey<String>(
            'locations-inline-name-content-${point.id}',
          ),
          fieldKey: ValueKey<String>('locations-inline-name-field-${point.id}'),
          controller: _inlineNameController,
          focusNode: _inlineNameFocusNode,
          level: level,
          hintText: 'L2 Location',
          note: _l2NameNote,
          onChanged: _onFormChanged,
          onEditingComplete: _finishInlineNameEdit,
          onTapOutside: _cancelInlineEditForOutsideTap,
          saveButtonKey: ValueKey<String>('locations-inline-save-${point.id}'),
          onDelete: () => _removeLocationBranchFromEditor(
            hasChildren: l2.children.isNotEmpty,
            level: deleteWholeL1 ? 1 : 2,
            name: deleteWholeL1 ? l1.name.text : _inlineNameController.text,
            remove: () => deleteWholeL1
                ? _removeL1Location(l1)
                : _removeL2Location(l1, l2),
          ),
          deleteEnabled: !deleteWholeL1 || _treeForms.length > 1,
          onDeleteDisabled: () =>
              _showError('At least one L1 location is required.'),
        );
      }
    }
    return null;
  }

  Widget? _buildNodeFooter(BuildContext context, WorldPoint point, int level) {
    for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
      final l1 = _treeForms[l1Index];
      if (l1.locationId == point.id) {
        final isAddingL2Here = l1.children.any(
          (l2) => l2.locationId == _requiredInlineLocationId,
        );
        if (isAddingL2Here ||
            l1.name.text.trim().isEmpty ||
            !_hasCompleteTree) {
          return null;
        }
        return Padding(
          padding: EdgeInsets.fromLTRB((level + 1) * 15.0, 0, 0, 12),
          child: _LocationTreeAddButton(
            key: ValueKey<String>('create-add-l2-${l1.locationId}'),
            label: '+ L2',
            onTap: () => _addL2Location(l1),
          ),
        );
      }
      for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
        final l2 = l1.children[l2Index];
        if (l2.locationId != point.id) continue;
        if (l1.name.text.trim().isEmpty || l2.name.text.trim().isEmpty) {
          return null;
        }
        return Padding(
          padding: EdgeInsets.fromLTRB((level + 1) * 15.0, 5, 0, 8),
          child: _LocationTreeAddL3Button(
            buttonKey: ValueKey<String>('create-add-l3-${l2.locationId}'),
            isRequired: !_l2HasSavedL3(l2),
            onTap: () => _addL3Location(l2),
          ),
        );
      }
    }
    return null;
  }

  Widget _buildTreeRootFooter() {
    if (_requiredFlowL1Id != null || !_hasCompleteTree) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: _rootAddL1VisibilityKey,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
      child: _LocationTreeAddButton(
        key: const ValueKey<String>('create-add-l1-location'),
        label: '+ L1',
        onTap: _addL1Location,
      ),
    );
  }

  void _openLeafEditor(WorldPoint point) {
    if (_mode != _LocationsEditorMode.edit) return;
    if (_blockForRequiredLocation(targetLocationId: point.id)) return;
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

  Future<void> _showL3EditorSheet(
    _L3LocationTarget target, {
    bool isNew = false,
  }) async {
    if (_inlineEditingLocationId != null) {
      setState(() => _inlineEditingLocationId = null);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    final draftForm = _LocationForm.copyOf(target.form);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.78;
    var draftOwnedBySheet = false;
    try {
      final action = await showGenesisModalBottomSheet<_L3EditorSheetAction>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          draftOwnedBySheet = true;
          return _LocationFormOwner(
            form: draftForm,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                void refreshSheet() => setSheetState(() {});

                final deleteEnabled = target.parent.children.length > 1;
                final selectedCharacterIds = draftForm.selectedCharacterIds
                    .toSet();
                final blockedCharacterIds = _boundCharacterIdsExceptForm(
                  target.form,
                );
                final availableCharacters = _finalCharacters
                    .where((character) {
                      final characterId = character.charId.trim();
                      return characterId.isNotEmpty &&
                          character.name.trim().isNotEmpty &&
                          !selectedCharacterIds.contains(characterId) &&
                          !blockedCharacterIds.contains(characterId);
                    })
                    .toList(growable: false);
                return GenesisBottomSheetPanel(
                  key: const ValueKey<String>('locations-l3-editor-sheet'),
                  title: isNew ? 'Add L3 Location' : 'Edit L3 Location',
                  height: sheetHeight,
                  maintainBottomViewPadding: true,
                  trailing: GenesisBottomSheetCloseButton(
                    buttonKey: const ValueKey<String>(
                      'locations-l3-editor-close',
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: _LocationCard(
                            key: ValueKey<String>(
                              'locations-l3-sheet-${target.form.locationId}',
                            ),
                            index: target.l3Index + 1,
                            showHeader: false,
                            nameFieldLabel: 'Name *',
                            fieldLabelFontWeight: FontWeight.w400,
                            form: draftForm,
                            nextFocusNode: null,
                            characters: _finalCharacters,
                            onChanged: refreshSheet,
                            onPickCharacters: () {
                              // L3 sheets use the inline Available to select
                              // list instead of opening a second sheet.
                            },
                            availableCharacters: availableCharacters,
                            onAddCharacter: (characterId) {
                              if (draftForm.selectedCharacterIds.contains(
                                characterId,
                              )) {
                                return;
                              }
                              draftForm.selectedCharacterIds = [
                                ...draftForm.selectedCharacterIds,
                                characterId,
                              ];
                              setSheetState(() {});
                            },
                            onRemoveCharacter: (charId) {
                              draftForm.selectedCharacterIds = draftForm
                                  .selectedCharacterIds
                                  .where((item) => item != charId)
                                  .toList(growable: true);
                              setSheetState(() {});
                            },
                            onDelete: () {},
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final preferredSaveWidth = _primaryActionButtonWidth(
                            context,
                          );
                          final reservedActionWidth = isNew
                              ? 0.0
                              : GenesisPrimaryButton.defaultHeight + 12;
                          final availableSaveWidth =
                              constraints.maxWidth - reservedActionWidth;
                          final saveWidth =
                              preferredSaveWidth <= availableSaveWidth
                              ? preferredSaveWidth
                              : availableSaveWidth;
                          return Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isNew) ...[
                                  CreateFormDeleteButton(
                                    buttonKey: const ValueKey<String>(
                                      'locations-l3-editor-delete',
                                    ),
                                    size: GenesisPrimaryButton.defaultHeight,
                                    iconSize: 20,
                                    onPressed: () => Navigator.of(
                                      context,
                                    ).pop(_L3EditorSheetAction.delete),
                                    enabled: deleteEnabled,
                                    onDisabledPressed: () => _showError(
                                      _l2NeedsL3Message(target.parent),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                GenesisPrimaryButton(
                                  key: const ValueKey<String>(
                                    'locations-l3-editor-save',
                                  ),
                                  label: 'Save',
                                  width: saveWidth,
                                  onPressed: draftForm.name.text.trim().isEmpty
                                      ? null
                                      : () => Navigator.of(
                                          context,
                                        ).pop(_L3EditorSheetAction.save),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
      if (!mounted) return;
      if (action == _L3EditorSheetAction.delete) {
        _removeL3Location(target.parent, target.form);
        return;
      }
      if (action == _L3EditorSheetAction.save) {
        target.form.applyValuesFrom(draftForm);
        if (isNew) {
          setState(() {
            target.parent.children.add(target.form);
            target.parent.nextChildOrdinal++;
          });
        } else {
          _onFormChanged();
        }
      }
    } finally {
      if (isNew && !target.parent.children.contains(target.form)) {
        target.form.dispose();
      }
      if (!draftOwnedBySheet) {
        draftForm.dispose();
      }
    }
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

  Future<void> _openCharacterPickerForForm(
    _LocationForm form, {
    bool notifyFormChanged = true,
  }) async {
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
    if (notifyFormChanged) _onFormChanged();
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
    if (_blockForRequiredLocation()) return;
    if (widget.useLocationTree) {
      for (int l1Index = 0; l1Index < _treeForms.length; l1Index++) {
        final l1 = _treeForms[l1Index];
        if (l1.name.text.trim().isEmpty) {
          _showError('L1 location name is required.');
          return;
        }
        for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
          final l2 = l1.children[l2Index];
          if (l2.name.text.trim().isEmpty) {
            _showError(
              '${_locationNameLabel(l1.name, fallback: 'This L1 location')} '
              'has an L2 location that needs a name.',
            );
            return;
          }
          for (int l3Index = 0; l3Index < l2.children.length; l3Index++) {
            if (l2.children[l3Index].name.text.trim().isEmpty) {
              _showError(
                '${_locationNameLabel(l2.name, fallback: 'This L2 location')} '
                'has an L3 location that needs a name.',
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
          _showError('Location name is required.');
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
          return 'L1 location name is required.';
        }
        if (l1.children.isEmpty) {
          return _l1NeedsL2Message(l1);
        }
        for (int l2Index = 0; l2Index < l1.children.length; l2Index++) {
          final l2 = l1.children[l2Index];
          if (l2.name.text.trim().isEmpty) {
            return '${_locationNameLabel(l1.name, fallback: 'This L1 location')} '
                'has an L2 location that needs a name.';
          }
          if (l2.children.isEmpty) {
            return _l2NeedsL3Message(l2);
          }
          for (int l3Index = 0; l3Index < l2.children.length; l3Index++) {
            if (l2.children[l3Index].name.text.trim().isEmpty) {
              return '${_locationNameLabel(l2.name, fallback: 'This L2 location')} '
                  'has an L3 location that needs a name.';
            }
          }
        }
      }
    } else {
      for (int index = 0; index < _forms.length; index++) {
        final form = _forms[index];
        if (!form.hasContent) continue;
        if (form.name.text.trim().isEmpty) {
          return 'Location name is required.';
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
                displayId: 'Loc_${l1Index + 1}_${l2Index + 1}',
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
    final list = WorldLocationList(
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
    if (!editable) return list;
    return Theme(
      key: const ValueKey<String>('locations-edit-no-tap-effects'),
      data: Theme.of(context).copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      child: list,
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
        _LocationEditorNote(
          key: const ValueKey<String>('locations-statistics-note'),
          text: _statisticsNote,
        ),
        const SizedBox(height: 16),
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
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(child: _buildLocationsList(editable: true)),
          _buildBottomSaveAction(onShown: _revealRootAddL1IfReady),
        ],
      ),
    );
  }

  Widget _buildBottomSaveAction({VoidCallback? onShown}) {
    return _KeyboardHiddenBottomAction(
      onShown: onShown,
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
    _inlineNameController.dispose();
    _nextInlineNameController.dispose();
    _inlineNameFocusNode.dispose();
    _nextInlineNameFocusNode.dispose();
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
    return Listener(
      onPointerUp: (_) => _releaseInlineOutsideTapSuppression(),
      onPointerCancel: (_) => _releaseInlineOutsideTapSuppression(),
      child: Scaffold(
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

class _LocationFormOwner extends StatefulWidget {
  const _LocationFormOwner({required this.form, required this.child});

  final _LocationForm form;
  final Widget child;

  @override
  State<_LocationFormOwner> createState() => _LocationFormOwnerState();
}

class _LocationFormOwnerState extends State<_LocationFormOwner> {
  @override
  void dispose() {
    widget.form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
