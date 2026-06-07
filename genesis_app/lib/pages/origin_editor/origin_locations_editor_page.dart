part of 'origin_editor_pages.dart';

class OriginLocationsEditorPage extends StatefulWidget {
  const OriginLocationsEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginLocationsEditorPage> createState() =>
      _OriginLocationsEditorPageState();
}

class _OriginLocationsEditorPageState extends State<OriginLocationsEditorPage> {
  static const int _maxLocations = 10;

  final List<_LocationForm> _forms = <_LocationForm>[];
  String _uid = 'anonymous';
  List<CharacterDraft> _finalCharacters = const <CharacterDraft>[];
  bool _isSaving = false;
  bool _isFinalSynced = false;

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
    final missingIds = source.any((item) => item.locationId.trim().isEmpty);
    for (final item in source) {
      _forms.add(_LocationForm.fromDraft(item, uid: _uid));
    }
    if (!mounted) return;
    _isFinalSynced = draft.locationsSaved && !missingIds;
    setState(() {});
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

  Future<void> _requestRemoveLocation(int index) async {
    final form = _forms[index];
    if (form.hasContent) {
      final confirmed = await confirmCreateFormDelete(
        context,
        itemLabel: 'Location ${index + 1}',
      );
      if (!confirmed || !mounted) return;
    }
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
    setState(() => _isFinalSynced = false);
  }

  List<LocationDraft> _snapshotLocations() {
    final validCharacterIds = _finalCharacters
        .map((item) => item.charId.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    return _forms
        .map(
          (form) => LocationDraft(
            locationId: form.locationId,
            parentLocationId: form.parentLocationId,
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

  Future<void> _openParentLocationPicker(int locationIndex) async {
    final form = _forms[locationIndex];
    final options = _parentLocationOptions(locationIndex);
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ParentLocationPickerSheet(
          options: options,
          initialSelectedId: form.parentLocationId,
        );
      },
    );
    if (selectedId == null || !mounted) return;
    setState(() {
      form.parentLocationId = selectedId;
    });
    _onFormChanged();
  }

  Future<void> _openCharacterPicker(int locationIndex) async {
    final characters = await widget.repository.loadSavedCharacters();
    if (!mounted) return;
    setState(() => _finalCharacters = characters);
    if (characters.isEmpty) {
      _showError('There are no characters yet.');
      return;
    }

    final blockedIds = _boundCharacterIdsExcept(locationIndex);
    final currentIds = _forms[locationIndex].selectedCharacterIds.toSet();
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

    final selectedIds = await showModalBottomSheet<List<String>>(
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
      _forms[locationIndex].selectedCharacterIds = selectedIds;
    });
    _onFormChanged();
  }

  Set<String> _boundCharacterIdsExcept(int excludedIndex) {
    final ids = <String>{};
    for (int i = 0; i < _forms.length; i++) {
      if (i == excludedIndex) continue;
      ids.addAll(_forms[i].selectedCharacterIds);
    }
    return ids;
  }

  List<_ParentLocationOption> _parentLocationOptions(int locationIndex) {
    final options = <_ParentLocationOption>[
      const _ParentLocationOption(id: '', label: 'World Root'),
    ];
    final childId = _forms[locationIndex].locationId.trim();
    for (int i = 0; i < _forms.length; i++) {
      if (i == locationIndex) continue;
      final form = _forms[i];
      final locationId = form.locationId.trim();
      if (locationId.isEmpty) continue;
      if (_wouldCreateParentCycle(childId: childId, parentId: locationId)) {
        continue;
      }
      final name = form.name.text.trim();
      options.add(
        _ParentLocationOption(
          id: locationId,
          label: name.isEmpty ? 'Location ${i + 1}' : name,
        ),
      );
    }
    return options;
  }

  bool _wouldCreateParentCycle({
    required String childId,
    required String parentId,
  }) {
    if (childId.isEmpty || parentId.isEmpty) return false;
    if (childId == parentId) return true;
    final parentsById = <String, String>{
      for (final form in _forms)
        if (form.locationId.trim().isNotEmpty)
          form.locationId.trim(): form.parentLocationId.trim(),
    };
    var current = parentId;
    final seen = <String>{childId};
    while (current.isNotEmpty) {
      if (!seen.add(current)) return true;
      current = parentsById[current] ?? '';
    }
    return false;
  }

  Future<void> _saveLocations() async {
    for (int i = 0; i < _forms.length; i++) {
      final form = _forms[i];
      if (!form.hasContent) continue;
      if (form.name.text.trim().isEmpty) {
        _showError('Location ${i + 1}: Location Name is required.');
        return;
      }
      final parentId = form.parentLocationId.trim();
      if (parentId.isNotEmpty &&
          !_forms.any((item) => item.locationId.trim() == parentId)) {
        _showError('Location ${i + 1}: Parent Location is invalid.');
        return;
      }
      if (_wouldCreateParentCycle(
        childId: form.locationId.trim(),
        parentId: parentId,
      )) {
        _showError('Location ${i + 1}: Parent Location creates a cycle.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    _finalCharacters = await widget.repository.loadSavedCharacters();
    final locations = _snapshotLocations()
        .where(_locationDraftHasContent)
        .toList(growable: false);

    await widget.repository.saveFinalDraft(
      draft.copyWith(locations: locations, locationsSaved: true),
    );

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isFinalSynced = true;
    });
    Navigator.of(context).pop(true);
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  @override
  void dispose() {
    for (final form in _forms) {
      form.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: '📍 Locations'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Place your world on the map. Add a location image and name, then link characters who start there.',
                        style: TextStyle(
                          color: createFormMuted,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_forms.length}/$_maxLocations (Added / Max)',
                          style: const TextStyle(
                            color: createFormText,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (int i = 0; i < _forms.length; i++) ...[
                        _LocationCard(
                          index: i + 1,
                          form: _forms[i],
                          characters: _finalCharacters,
                          parentOptions: _parentLocationOptions(i),
                          onChanged: _onFormChanged,
                          onPickParentLocation: () =>
                              _openParentLocationPicker(i),
                          onPickCharacters: () => _openCharacterPicker(i),
                          onDelete: () {
                            _requestRemoveLocation(i);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      CreateAddButton(
                        label: '+ Add Location',
                        onTap: _addLocation,
                      ),
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
                  onPressed: (_isSaving || _isFinalSynced)
                      ? null
                      : _saveLocations,
                  backgroundColor: createFormGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFBFD8CD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
