import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/common/genesis_bottom_sheet_panel.dart';
import '../../components/page_header.dart';
import '../../ui/genesis_ui.dart';
import 'create_form_widgets.dart';
import 'create_origin_draft_store.dart';
import 'create_origin_id_utils.dart';

class CreateLocationsPage extends StatefulWidget {
  const CreateLocationsPage({super.key});

  @override
  State<CreateLocationsPage> createState() => _CreateLocationsPageState();
}

class _CreateLocationsPageState extends State<CreateLocationsPage> {
  static const int _maxLocations = 10;

  final List<_LocationForm> _forms = <_LocationForm>[];
  Timer? _tempSaveDebounce;
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
    final draft = await CreateOriginDraftStore.load();
    _finalCharacters = await CreateOriginDraftStore.loadFinalCharacters();
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
    _tempSaveDebounce?.cancel();
    _tempSaveDebounce = Timer(const Duration(seconds: 10), () {
      unawaited(_writeTempDraft());
    });
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
    final characters = await CreateOriginDraftStore.loadFinalCharacters();
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

  Future<void> _writeTempDraft() async {
    final locations = _snapshotLocations();
    final draft = await CreateOriginDraftStore.load();
    await CreateOriginDraftStore.saveTemp(
      draft.copyWith(locations: locations, locationsSaved: false),
      syncedToFinal: false,
    );
  }

  Future<void> _saveLocations() async {
    for (int i = 0; i < _forms.length; i++) {
      final form = _forms[i];
      if (form.name.text.trim().isEmpty) {
        _showError('Location ${i + 1}: Location Name is required.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final draft = await CreateOriginDraftStore.load();
    _finalCharacters = await CreateOriginDraftStore.loadFinalCharacters();
    final locations = _snapshotLocations();

    _tempSaveDebounce?.cancel();
    await CreateOriginDraftStore.saveFinal(
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _tempSaveDebounce?.cancel();
    if (!_isFinalSynced) {
      unawaited(_writeTempDraft());
    }
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
                          onChanged: _onFormChanged,
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

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.index,
    required this.form,
    required this.characters,
    required this.onChanged,
    required this.onPickCharacters,
    required this.onDelete,
  });

  final int index;
  final _LocationForm form;
  final List<CharacterDraft> characters;
  final VoidCallback onChanged;
  final VoidCallback onPickCharacters;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Location $index',
      onDelete: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreateUploadBox(
                controller: form.imageUrl,
                label: 'IMAGE\n(Optional)',
                width: 96,
                height: 150,
                iconSize: 36,
                cropSize: const Size(384, 600),
                onChanged: onChanged,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CreateTextFieldBlock(
                  label: 'Location Name *',
                  controller: form.name,
                  hintText: 'Enter location name...',
                  maxLength: 25,
                  maxLines: 1,
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          CreateTextFieldBlock(
            label: 'Description (Optional)',
            controller: form.description,
            hintText: 'Show in Origin location list',
            maxLength: 100,
            minLines: 2,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 22),
          _InitialCharactersField(
            form: form,
            characters: characters,
            onPickCharacters: onPickCharacters,
          ),
        ],
      ),
    );
  }
}

class _InitialCharactersField extends StatelessWidget {
  const _InitialCharactersField({
    required this.form,
    required this.characters,
    required this.onPickCharacters,
  });

  final _LocationForm form;
  final List<CharacterDraft> characters;
  final VoidCallback onPickCharacters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Initial Characters (Optional)',
          style: TextStyle(
            color: createFormText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          key: const ValueKey('location-character-picker'),
          behavior: HitTestBehavior.opaque,
          onTap: onPickCharacters,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: createFormFieldFill,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _selectedNames.isEmpty
                          ? createFormHint
                          : createFormText,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onPickCharacters,
                  icon: const Icon(Icons.add, color: createFormGreen, size: 32),
                  splashRadius: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _selectedNames {
    final byId = {
      for (final item in characters) item.charId.trim(): item.name.trim(),
    };
    return form.selectedCharacterIds
        .map((id) => byId[id] ?? '')
        .where((name) => name.isNotEmpty)
        .join(', ');
  }
}

class _CharacterPickerSheet extends StatefulWidget {
  const _CharacterPickerSheet({
    required this.characters,
    required this.initialSelectedIds,
  });

  final List<CharacterDraft> characters;
  final Set<String> initialSelectedIds;

  @override
  State<_CharacterPickerSheet> createState() => _CharacterPickerSheetState();
}

class _CharacterPickerSheetState extends State<_CharacterPickerSheet> {
  late final Set<String> _selectedIds = <String>{...widget.initialSelectedIds};

  @override
  Widget build(BuildContext context) {
    return GenesisBottomSheetPanel(
      title: 'Select Characters',
      height: MediaQuery.sizeOf(context).height * 0.58,
      trailing: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close, size: 30, color: createFormMuted),
        splashRadius: 24,
      ),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 22,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: widget.characters.length,
              itemBuilder: (context, index) {
                final character = widget.characters[index];
                final charId = character.charId.trim();
                final selected = _selectedIds.contains(charId);
                return _CharacterPickerTile(
                  character: character,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedIds.remove(charId);
                      } else {
                        _selectedIds.add(charId);
                      }
                    });
                  },
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
                  onPressed: () =>
                      Navigator.of(context).pop(_selectedIds.toList()),
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

class _CharacterPickerTile extends StatelessWidget {
  const _CharacterPickerTile({
    required this.character,
    required this.selected,
    required this.onTap,
  });

  final CharacterDraft character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('character-picker-tile-${character.charId.trim()}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: createFormFieldFill,
                    child: character.avatarUrl.trim().isEmpty
                        ? const SizedBox.shrink()
                        : Image.network(
                            character.avatarUrl.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected
                          ? createFormGreen
                          : const Color(0xFF9B9B9B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            character.name.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: createFormText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationForm {
  _LocationForm({
    required this.locationId,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.selectedCharacterIds,
  });

  factory _LocationForm.empty({required String locationId}) {
    return _LocationForm(
      locationId: locationId,
      imageUrl: TextEditingController(),
      name: TextEditingController(),
      description: TextEditingController(),
      selectedCharacterIds: <String>[],
    );
  }

  factory _LocationForm.fromDraft(LocationDraft draft, {required String uid}) {
    return _LocationForm(
      locationId: draft.locationId.trim().isEmpty
          ? createUidTimestampHashId(uid: uid, prefix: 'location')
          : draft.locationId.trim(),
      imageUrl: TextEditingController(text: draft.imageUrl),
      name: TextEditingController(text: draft.name),
      description: TextEditingController(text: draft.description),
      selectedCharacterIds: draft.initialCharacterIds,
    );
  }

  final String locationId;
  final TextEditingController imageUrl;
  final TextEditingController name;
  final TextEditingController description;
  List<String> selectedCharacterIds;

  void dispose() {
    imageUrl.dispose();
    name.dispose();
    description.dispose();
  }

  bool get hasContent {
    return [
          imageUrl,
          name,
          description,
        ].any((controller) => controller.text.trim().isNotEmpty) ||
        selectedCharacterIds.isNotEmpty;
  }

  void clear() {
    imageUrl.clear();
    name.clear();
    description.clear();
    selectedCharacterIds = <String>[];
  }
}
