part of 'origin_editor_pages.dart';

class OriginCharactersEditorPage extends StatefulWidget {
  const OriginCharactersEditorPage({super.key, required this.repository});

  final OriginDraftRepository repository;

  @override
  State<OriginCharactersEditorPage> createState() =>
      _OriginCharactersEditorPageState();
}

class _OriginCharactersEditorPageState
    extends State<OriginCharactersEditorPage> {
  static const int _maxCharacters = 8;

  final List<OriginCharacterForm> _forms = <OriginCharacterForm>[];
  String _uid = 'anonymous';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final uidFuture = readCreateOriginUid(context);
    final draft = await widget.repository.loadDraft();
    _uid = await uidFuture;
    final source = draft.characters.isEmpty
        ? const <CharacterDraft>[CharacterDraft()]
        : draft.characters;
    for (final item in source) {
      _forms.add(_characterFormFromDraft(item, uid: _uid));
    }
    if (!mounted) return;
    setState(() {});
  }

  void _addCharacter() {
    if (_forms.length >= _maxCharacters) {
      _showError('You can add up to $_maxCharacters characters.');
      return;
    }
    setState(() {
      _forms.add(
        OriginCharacterForm.empty(
          charId: createUidTimestampHashId(uid: _uid, prefix: 'char'),
        ),
      );
    });
    _onFormChanged();
  }

  void _requestRemoveCharacter(int index) {
    _removeCharacter(index);
  }

  void _removeCharacter(int index) {
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

  List<CharacterDraft> _snapshotCharacters() {
    return _forms
        .map(
          (form) => CharacterDraft(
            charId: form.charId,
            avatarUrl: form.avatarUrl.text.trim(),
            name: form.name.text.trim(),
            identity: form.identity.text.trim(),
            personality: form.personality.text.trim(),
            bio: form.bio.text.trim(),
            goal: form.goal.text.trim(),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _saveCharacters() async {
    for (int i = 0; i < _forms.length; i++) {
      final form = _forms[i];
      if (!form.hasContent) continue;
      if (form.name.text.trim().isEmpty) {
        _showError('Character ${i + 1}: Name is required.');
        return;
      }
      if (form.identity.text.trim().isEmpty) {
        _showError('Character ${i + 1}: Identity is required.');
        return;
      }
      if (form.personality.text.trim().isEmpty) {
        _showError('Character ${i + 1}: Personality is required.');
        return;
      }
    }

    final characters = _snapshotCharacters()
        .where(_characterDraftHasContent)
        .toList(growable: false);
    if (characters.isEmpty) {
      _showError('Please create at least one character.');
      return;
    }

    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    final validCharacterIds = characters
        .map((item) => item.charId.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    final updatedDraft = draft
        .copyWith(characters: characters, charactersSaved: true)
        .pruneLocationBindings(validCharacterIds);

    await widget.repository.saveFinalDraft(updatedDraft);

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  bool get _canSaveCurrentCharacters {
    var hasCompleteCharacter = false;
    for (final form in _forms) {
      if (!form.hasContent) continue;
      if (form.name.text.trim().isEmpty ||
          form.identity.text.trim().isEmpty ||
          form.personality.text.trim().isEmpty) {
        return false;
      }
      hasCompleteCharacter = true;
    }
    return hasCompleteCharacter;
  }

  bool get _canUseSaveButton {
    if (_isSaving) return false;
    return _canSaveCurrentCharacters;
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  OriginCharacterForm _characterFormFromDraft(
    CharacterDraft draft, {
    required String uid,
  }) {
    return OriginCharacterForm.fromValues(
      charId: draft.charId.trim().isEmpty
          ? createUidTimestampHashId(uid: uid, prefix: 'char')
          : draft.charId.trim(),
      avatarUrl: draft.avatarUrl,
      name: draft.name,
      identity: draft.identity,
      personality: draft.personality,
      bio: draft.bio,
      goal: draft.goal,
    );
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: const GenesisBackAppBar(pageName: 'Characters'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 28 + keyboardInset),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_forms.length}/$_maxCharacters (Added / Max)',
                          style: const TextStyle(
                            color: createFormText,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (int i = 0; i < _forms.length; i++) ...[
                        _CharacterCard(
                          index: i + 1,
                          form: _forms[i],
                          onChanged: _onFormChanged,
                          onDelete: () {
                            _requestRemoveCharacter(i);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      CreateAddButton(
                        label: '+ Add Character',
                        onTap: _addCharacter,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(24, 8, 24, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  onPressed: _canUseSaveButton ? _saveCharacters : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
