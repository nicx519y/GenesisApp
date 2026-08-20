part of 'origin_editor_pages.dart';

class OriginCharactersEditorPage extends StatefulWidget {
  const OriginCharactersEditorPage({
    super.key,
    required this.repository,
    this.createWorldoStyle = false,
  });

  final OriginDraftRepository repository;
  final bool createWorldoStyle;

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

  void _setRecommended(int index, bool recommended) {
    if (index < 0 || index >= _forms.length) return;
    final targetForm = _forms[index];
    setState(() {
      for (final form in _forms) {
        form.isRecommended = recommended && identical(form, targetForm);
      }
    });
  }

  List<CharacterDraft> _snapshotCharacters() {
    return _forms
        .map(
          (form) => CharacterDraft(
            charId: form.charId,
            avatarUrl: form.avatarUrl.text.trim(),
            name: normalizeGenesisUgcTextForDisplay(form.name.text),
            identity: normalizeGenesisUgcTextForDisplay(form.identity.text),
            personality: normalizeGenesisUgcTextForDisplay(
              form.personality.text,
            ),
            bio: normalizeGenesisUgcTextForDisplay(form.bio.text),
            goal: normalizeGenesisUgcTextForDisplay(form.goal.text),
            isRecommend: form.isRecommended ? 1 : 0,
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

  String get _saveDisabledReason {
    if (_isSaving) return 'Saving is already in progress.';
    for (int index = 0; index < _forms.length; index++) {
      final form = _forms[index];
      if (!form.hasContent) continue;
      if (form.name.text.trim().isEmpty) {
        return 'Character ${index + 1}: Name is required.';
      }
      if (form.identity.text.trim().isEmpty) {
        return 'Character ${index + 1}: Identity is required.';
      }
      if (form.personality.text.trim().isEmpty) {
        return 'Character ${index + 1}: Personality is required.';
      }
    }
    return 'Please create at least one character.';
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
      isRecommended: draft.isRecommended,
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
    final createWorldoStyle = widget.createWorldoStyle;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: createWorldoStyle
          ? GenesisPalette.redesignBackground
          : context.genesisColors.pageBackground,
      appBar: createWorldoStyle
          ? _CreateCharactersAppBar(
              characterCount: _forms.length,
              maxCharacters: _maxCharacters,
            )
          : const GenesisBackAppBar(pageName: 'Characters'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: createWorldoStyle
                      ? const EdgeInsets.fromLTRB(20, 4, 20, 0)
                      : const EdgeInsets.fromLTRB(12, 8, 12, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!createWorldoStyle) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_forms.length}/$_maxCharacters (Added / Max)',
                            style: TextStyle(
                              color: context.genesisCreateColors.text,
                              fontSize: 14,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      for (int i = 0; i < _forms.length; i++) ...[
                        _CharacterCard(
                          index: i + 1,
                          form: _forms[i],
                          createWorldoStyle: createWorldoStyle,
                          nextFocusNode: i + 1 < _forms.length
                              ? _forms[i + 1].focusNodes.name
                              : null,
                          onChanged: _onFormChanged,
                          onRecommendationChanged: (recommended) =>
                              _setRecommended(i, recommended),
                          onDelete: () {
                            _requestRemoveCharacter(i);
                          },
                        ),
                        if (i + 1 < _forms.length)
                          SizedBox(height: createWorldoStyle ? 22 : 12),
                      ],
                      if (_forms.isNotEmpty)
                        SizedBox(height: createWorldoStyle ? 22 : 12),
                      if (createWorldoStyle)
                        _CreateCharactersAddButton(onTap: _addCharacter)
                      else
                        CreateInlineAddButton(
                          label: '+ Add Character',
                          onTap: _addCharacter,
                          fontSize: 16,
                          centered: true,
                          contentPadding: const EdgeInsets.fromLTRB(
                            0,
                            11,
                            0,
                            5,
                          ),
                        ),
                      SizedBox(height: createWorldoStyle ? 0 : 12),
                    ],
                  ),
                ),
              ),
              _KeyboardHiddenBottomAction(
                minimum: createWorldoStyle
                    ? const EdgeInsets.fromLTRB(20, 22, 20, 30)
                    : const EdgeInsets.fromLTRB(24, 8, 24, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  width: createWorldoStyle
                      ? double.infinity
                      : _primaryActionButtonWidth(context),
                  height: createWorldoStyle ? 44 : null,
                  borderRadius: createWorldoStyle
                      ? BorderRadius.circular(13)
                      : null,
                  fontSize: createWorldoStyle ? 13 : null,
                  fontWeight: createWorldoStyle ? FontWeight.w700 : null,
                  onPressed: _canUseSaveButton ? _saveCharacters : null,
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
