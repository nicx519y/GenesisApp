import 'package:flutter/material.dart';

import '../../components/page_header.dart';
import '../../ui/genesis_ui.dart';
import 'create_form_widgets.dart';
import 'create_origin_draft_store.dart';

class CreateLocationsPage extends StatefulWidget {
  const CreateLocationsPage({super.key});

  @override
  State<CreateLocationsPage> createState() => _CreateLocationsPageState();
}

class _CreateLocationsPageState extends State<CreateLocationsPage> {
  static const int _maxLocations = 10;

  final List<_LocationForm> _forms = <_LocationForm>[];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final draft = await CreateOriginDraftStore.load();
    final source = draft.locations.isEmpty
        ? const <LocationDraft>[LocationDraft()]
        : draft.locations;
    for (final item in source) {
      _forms.add(_LocationForm.fromDraft(item));
    }
    if (!mounted) return;
    setState(() {});
  }

  void _addLocation() {
    if (_forms.length >= _maxLocations) {
      _showError('You can add up to $_maxLocations locations.');
      return;
    }
    setState(() => _forms.add(_LocationForm.empty()));
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
    setState(() {});
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
    final locations = _forms
        .map(
          (form) => LocationDraft(
            imageUrl: form.imageUrl.text.trim(),
            name: form.name.text.trim(),
            description: form.description.text.trim(),
            initialCharacterIndexes: _parseInitialCharacterIndexes(
              form.initialCharacters.text,
            ),
          ),
        )
        .toList(growable: false);

    await CreateOriginDraftStore.save(
      draft.copyWith(locations: locations, locationsSaved: true),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  List<int> _parseInitialCharacterIndexes(String raw) {
    return raw
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>()
        .toList(growable: false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
                    onChanged: () => setState(() {}),
                    onDelete: () {
                      _requestRemoveLocation(i);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                CreateAddButton(label: '+ Add Location', onTap: _addLocation),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CreateKeyboardAwareSaveBar(
        minimum: const EdgeInsets.fromLTRB(28, 8, 28, 14),
        child: GenesisPrimaryButton(
          label: _isSaving ? 'Saving...' : 'Save',
          onPressed: _isSaving ? null : _saveLocations,
          backgroundColor: createFormGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFBFD8CD),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.index,
    required this.form,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _LocationForm form;
  final VoidCallback onChanged;
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
          _InitialCharactersField(form: form, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _InitialCharactersField extends StatelessWidget {
  const _InitialCharactersField({required this.form, required this.onChanged});

  final _LocationForm form;
  final VoidCallback onChanged;

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
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: createFormFieldFill,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: form.initialCharacters,
                  onChanged: (_) => onChanged(),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14, color: createFormText),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '',
                    counterText: '',
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add, color: createFormGreen, size: 32),
                splashRadius: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationForm {
  _LocationForm({
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.initialCharacters,
  });

  factory _LocationForm.empty() {
    return _LocationForm(
      imageUrl: TextEditingController(),
      name: TextEditingController(),
      description: TextEditingController(),
      initialCharacters: TextEditingController(),
    );
  }

  factory _LocationForm.fromDraft(LocationDraft draft) {
    return _LocationForm(
      imageUrl: TextEditingController(text: draft.imageUrl),
      name: TextEditingController(text: draft.name),
      description: TextEditingController(text: draft.description),
      initialCharacters: TextEditingController(
        text: draft.initialCharacterIndexes.join(','),
      ),
    );
  }

  final TextEditingController imageUrl;
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController initialCharacters;

  void dispose() {
    imageUrl.dispose();
    name.dispose();
    description.dispose();
    initialCharacters.dispose();
  }

  bool get hasContent {
    return [
      imageUrl,
      name,
      description,
      initialCharacters,
    ].any((controller) => controller.text.trim().isNotEmpty);
  }

  void clear() {
    imageUrl.clear();
    name.clear();
    description.clear();
    initialCharacters.clear();
  }
}
