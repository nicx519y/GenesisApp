import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/page_header.dart';
import '../../ui/genesis_ui.dart';
import 'create_form_widgets.dart';
import 'create_origin_draft_store.dart';
import 'create_origin_id_utils.dart';

class CreateCharactersPage extends StatefulWidget {
  const CreateCharactersPage({super.key});

  @override
  State<CreateCharactersPage> createState() => _CreateCharactersPageState();
}

class _CreateCharactersPageState extends State<CreateCharactersPage> {
  static const int _maxCharacters = 8;

  final List<_CharacterForm> _forms = <_CharacterForm>[];
  Timer? _tempSaveDebounce;
  String _uid = 'anonymous';
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
    _uid = await uidFuture;
    final source = draft.characters.isEmpty
        ? const <CharacterDraft>[CharacterDraft()]
        : draft.characters;
    final missingIds = source.any((item) => item.charId.trim().isEmpty);
    for (final item in source) {
      _forms.add(_CharacterForm.fromDraft(item, uid: _uid));
    }
    if (!mounted) return;
    _isFinalSynced = draft.charactersSaved && !missingIds;
    setState(() {});
  }

  void _addCharacter() {
    if (_forms.length >= _maxCharacters) {
      _showError('You can add up to $_maxCharacters characters.');
      return;
    }
    setState(() {
      _forms.add(
        _CharacterForm.empty(
          charId: createUidTimestampHashId(uid: _uid, prefix: 'char'),
        ),
      );
    });
    _onFormChanged();
  }

  Future<void> _requestRemoveCharacter(int index) async {
    final form = _forms[index];
    if (form.hasContent) {
      final confirmed = await confirmCreateFormDelete(
        context,
        itemLabel: 'Character ${index + 1}',
      );
      if (!confirmed || !mounted) return;
    }
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
    _tempSaveDebounce?.cancel();
    _tempSaveDebounce = Timer(const Duration(seconds: 10), () {
      unawaited(_writeTempDraft());
    });
    setState(() => _isFinalSynced = false);
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

  Future<void> _writeTempDraft() async {
    final characters = _snapshotCharacters();
    final draft = await CreateOriginDraftStore.load();
    final validCharacterIds = characters
        .map((item) => item.charId.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    final updatedDraft = draft
        .copyWith(characters: characters, charactersSaved: false)
        .pruneLocationBindings(validCharacterIds);
    await CreateOriginDraftStore.saveTemp(updatedDraft, syncedToFinal: false);
  }

  Future<void> _saveCharacters() async {
    for (int i = 0; i < _forms.length; i++) {
      final form = _forms[i];
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

    setState(() => _isSaving = true);
    final draft = await CreateOriginDraftStore.load();
    final characters = _snapshotCharacters();
    final validCharacterIds = characters
        .map((item) => item.charId.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    final updatedDraft = draft
        .copyWith(characters: characters, charactersSaved: true)
        .pruneLocationBindings(validCharacterIds);

    _tempSaveDebounce?.cancel();
    await CreateOriginDraftStore.saveFinal(updatedDraft);

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
      appBar: const GenesisBackAppBar(pageName: '👤 Characters'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                  onPressed: (_isSaving || _isFinalSynced)
                      ? null
                      : _saveCharacters,
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

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.index,
    required this.form,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _CharacterForm form;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Character $index',
      onDelete: onDelete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CreateUploadBox(
                controller: form.avatarUrl,
                label: 'AVATAR\n(Optional)',
                width: 104,
                height: 168,
                iconSize: 38,
                cropSize: const Size(416, 672),
                onChanged: onChanged,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    CreateTextFieldBlock(
                      label: 'Name *',
                      controller: form.name,
                      hintText: 'Enter name...',
                      maxLength: 25,
                      labelSize: 14,
                      maxLines: 1,
                      onChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 18),
                    CreateTextFieldBlock(
                      label: 'Identity *',
                      controller: form.identity,
                      hintText: 'Who they are in the world',
                      maxLength: 50,
                      labelSize: 14,
                      maxLines: 1,
                      onChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 18),
                    CreateTextFieldBlock(
                      label: 'Personality *',
                      controller: form.personality,
                      hintText: 'How they speak and behave',
                      maxLength: 50,
                      labelSize: 14,
                      maxLines: 1,
                      onChanged: (_) => onChanged(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          CreateTextFieldBlock(
            label: 'Bio (Optional)',
            controller: form.bio,
            hintText: 'Background and relationships',
            maxLength: 1000,
            minLines: 3,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 22),
          CreateTextFieldBlock(
            label: 'Goal (Optional)',
            controller: form.goal,
            hintText: 'What they want to achieve',
            maxLength: 300,
            minLines: 2,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _CharacterForm {
  _CharacterForm({
    required this.charId,
    required this.avatarUrl,
    required this.name,
    required this.identity,
    required this.personality,
    required this.bio,
    required this.goal,
  });

  factory _CharacterForm.empty({required String charId}) {
    return _CharacterForm(
      charId: charId,
      avatarUrl: TextEditingController(),
      name: TextEditingController(),
      identity: TextEditingController(),
      personality: TextEditingController(),
      bio: TextEditingController(),
      goal: TextEditingController(),
    );
  }

  factory _CharacterForm.fromDraft(
    CharacterDraft draft, {
    required String uid,
  }) {
    return _CharacterForm(
      charId: draft.charId.trim().isEmpty
          ? createUidTimestampHashId(uid: uid, prefix: 'char')
          : draft.charId.trim(),
      avatarUrl: TextEditingController(text: draft.avatarUrl),
      name: TextEditingController(text: draft.name),
      identity: TextEditingController(text: draft.identity),
      personality: TextEditingController(text: draft.personality),
      bio: TextEditingController(text: draft.bio),
      goal: TextEditingController(text: draft.goal),
    );
  }

  final String charId;
  final TextEditingController avatarUrl;
  final TextEditingController name;
  final TextEditingController identity;
  final TextEditingController personality;
  final TextEditingController bio;
  final TextEditingController goal;

  void dispose() {
    avatarUrl.dispose();
    name.dispose();
    identity.dispose();
    personality.dispose();
    bio.dispose();
    goal.dispose();
  }

  bool get hasContent {
    return [
      avatarUrl,
      name,
      identity,
      personality,
      bio,
      goal,
    ].any((controller) => controller.text.trim().isNotEmpty);
  }

  void clear() {
    avatarUrl.clear();
    name.clear();
    identity.clear();
    personality.clear();
    bio.clear();
    goal.clear();
  }
}
