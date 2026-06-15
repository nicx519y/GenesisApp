part of 'origin_editor_pages.dart';

class OriginStoryEventsEditorPage extends StatefulWidget {
  const OriginStoryEventsEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginStoryEventsEditorPage> createState() =>
      _OriginStoryEventsEditorPageState();
}

class _OriginStoryEventsEditorPageState
    extends State<OriginStoryEventsEditorPage> {
  static const int _maxEvents = 20;
  final List<TextEditingController> _eventControllers =
      <TextEditingController>[];

  bool _isSaving = false;
  bool _isFinalSynced = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final draft = await widget.repository.loadDraft();
    final source = draft.storyEvents.isEmpty
        ? const <StoryEventDraft>[StoryEventDraft()]
        : draft.storyEvents;
    for (final event in source) {
      _eventControllers.add(TextEditingController(text: event.event));
    }
    if (!mounted) return;
    _isFinalSynced = draft.storyEventsSaved;
    setState(() {});
  }

  void _addEvent() {
    if (_eventControllers.length >= _maxEvents) {
      _showError('You can add up to $_maxEvents events.');
      return;
    }
    setState(() => _eventControllers.add(TextEditingController()));
    _onFormChanged();
  }

  Future<void> _requestRemoveEvent(int index) async {
    final controller = _eventControllers[index];
    if (controller.text.trim().isNotEmpty) {
      final confirmed = await confirmCreateFormDelete(
        context,
        itemLabel: 'Event ${index + 1}',
      );
      if (!confirmed || !mounted) return;
    }
    _removeEvent(index);
  }

  void _removeEvent(int index) {
    if (_eventControllers.length <= 1) {
      _eventControllers[index].clear();
    } else {
      final controller = _eventControllers.removeAt(index);
      controller.dispose();
    }
    _onFormChanged();
  }

  void _onFormChanged() {
    setState(() => _isFinalSynced = false);
  }

  List<StoryEventDraft> _snapshotEvents() {
    return _eventControllers
        .map((controller) => StoryEventDraft(event: controller.text.trim()))
        .toList(growable: false);
  }

  Future<void> _saveEvents() async {
    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    final events = _snapshotEvents()
        .where((item) => item.event.trim().isNotEmpty)
        .toList(growable: false);

    await widget.repository.saveFinalDraft(
      draft.copyWith(storyEvents: events, storyEventsSaved: true),
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
    for (final controller in _eventControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: '📜 Story Events'),
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
                        'Optional story beats or scenes. Each event is free text; keep them short and clear for the world runtime.',
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
                          '${_eventControllers.length}/$_maxEvents (Added / Max)',
                          style: const TextStyle(
                            color: createFormText,
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (int i = 0; i < _eventControllers.length; i++) ...[
                        _StoryEventCard(
                          index: i + 1,
                          controller: _eventControllers[i],
                          onChanged: _onFormChanged,
                          onDelete: () {
                            _requestRemoveEvent(i);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      CreateAddButton(label: '+ Add Event', onTap: _addEvent),
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
                  onPressed: (_isSaving || _isFinalSynced) ? null : _saveEvents,
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

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.icon,
    required this.title,
    required this.summary,
    required this.completed,
    required this.onTap,
    this.showDivider = true,
  });

  final String icon;
  final String title;
  final String summary;
  final bool completed;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.left,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final line in _summaryLines)
                                      Text(
                                        line,
                                        textAlign: TextAlign.left,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: const TextStyle(
                                          color: Color(0xFF6F6F6F),
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (completed)
                            const Icon(
                              Icons.check_circle,
                              color: GenesisColors.brand,
                              size: 20,
                            ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF8A8A8A),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showDivider)
            const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8E8)),
        ],
      ),
    );
  }

  List<String> get _summaryLines {
    return summary
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.index,
    required this.form,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final OriginCharacterForm form;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Character $index',
      onDelete: onDelete,
      child: OriginCharacterFormFields(form: form, onChanged: onChanged),
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
                cropSize: const Size(800, 1200),
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
                  borderRadius: BorderRadius.circular(
                    GenesisAvatarRadii.character,
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: createFormFieldFill,
                    child: character.avatarUrl.trim().isEmpty
                        ? GenesisAvatarFallback(
                            name: character.name,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: GenesisAvatarRadii.character,
                          )
                        : GenesisAvatar(
                            url: character.avatarUrl.trim(),
                            name: character.name,
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: GenesisAvatarRadii.character,
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

class _StoryEventCard extends StatelessWidget {
  const _StoryEventCard({
    required this.index,
    required this.controller,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Event $index',
      onDelete: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          CreateTextFieldBlock(
            label: '',
            controller: controller,
            hintText: 'Event (any language)',
            maxLength: 1000,
            minLines: 7,
            labelSize: 0,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}
