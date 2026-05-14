import 'package:flutter/material.dart';

import 'create_origin_draft_store.dart';

class CreateCharactersPage extends StatefulWidget {
  const CreateCharactersPage({super.key});

  @override
  State<CreateCharactersPage> createState() => _CreateCharactersPageState();
}

class _CreateCharactersPageState extends State<CreateCharactersPage> {
  static const int _maxCharacters = 8;

  final List<_CharacterForm> _forms = <_CharacterForm>[];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final draft = await CreateOriginDraftStore.load();
    final source = draft.characters.isEmpty
        ? const <CharacterDraft>[CharacterDraft()]
        : draft.characters;
    for (final item in source) {
      _forms.add(_CharacterForm.fromDraft(item));
    }
    if (!mounted) return;
    setState(() {});
  }

  void _addCharacter() {
    if (_forms.length >= _maxCharacters) {
      return;
    }
    setState(() => _forms.add(_CharacterForm.empty()));
  }

  void _removeCharacter(int index) {
    if (_forms.length <= 1) return;
    final form = _forms.removeAt(index);
    form.dispose();
    setState(() {});
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
    final characters = _forms
        .map(
          (form) => CharacterDraft(
            avatarUrl: form.avatarUrl.text.trim(),
            name: form.name.text.trim(),
            identity: form.identity.text.trim(),
            personality: form.personality.text.trim(),
            bio: form.bio.text.trim(),
            goal: form.goal.text.trim(),
          ),
        )
        .toList(growable: false);

    await CreateOriginDraftStore.save(
      draft.copyWith(characters: characters, charactersSaved: true),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
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
    const double titleSize = 18;
    const double bodySize = 14;
    const double hintSize = 12;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          '👤 Characters',
          style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Create vivid companions for your story. Fill in key traits to make each character feel alive.',
                      style: TextStyle(fontSize: bodySize, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_forms.length}/$_maxCharacters (Added / Max)',
                        style: const TextStyle(
                          fontSize: hintSize,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (int i = 0; i < _forms.length; i++) ...<Widget>[
                      _CharacterCard(
                        index: i + 1,
                        form: _forms[i],
                        onChanged: () => setState(() {}),
                        onDelete: () => _removeCharacter(i),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _DashedAddButton(
                      onTap: _addCharacter,
                      label: '+ Add Character',
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEAEAEA))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCharacters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22A652),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: bodySize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(_isSaving ? 'Saving...' : 'Save'),
                ),
              ),
            ),
          ],
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
    const double bodySize = 14;
    const double hintSize = 12;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Character $index',
                  style: const TextStyle(
                    fontSize: bodySize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 100,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF8F8F8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 28,
                      color: Color(0xFF7C7C7C),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AVATAR\n(Optional)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: hintSize,
                        height: 1.3,
                        color: Color(0xFF7C7C7C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: form.avatarUrl,
                      onChanged: (_) => onChanged(),
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: 'Image URL',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: <Widget>[
                    _LabeledInput(
                      label: 'Name*',
                      counter: '${form.name.text.length}/25',
                      controller: form.name,
                      onChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 10),
                    _LabeledInput(
                      label: 'Identity*',
                      counter: '${form.identity.text.length}/50',
                      controller: form.identity,
                      onChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 10),
                    _LabeledInput(
                      label: 'Personality*',
                      counter: '${form.personality.text.length}/50',
                      controller: form.personality,
                      onChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 10),
                    _LabeledInput(
                      label: 'Bio optional',
                      counter: '${form.bio.text.length}/1000',
                      controller: form.bio,
                      onChanged: (_) => onChanged(),
                      minLines: 3,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 10),
                    _LabeledInput(
                      label: 'Goal optional',
                      counter: '${form.goal.text.length}/300',
                      controller: form.goal,
                      onChanged: (_) => onChanged(),
                      minLines: 2,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({
    required this.label,
    required this.counter,
    required this.controller,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final String counter;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              counter,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C7C7C)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: maxLines,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: const Color(0xFFB7B7B7),
            radius: 12,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF22A652),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 6;
    const double dashSpace = 4;

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = (distance + dashWidth)
            .clamp(0.0, metric.length)
            .toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _CharacterForm {
  _CharacterForm({
    required this.avatarUrl,
    required this.name,
    required this.identity,
    required this.personality,
    required this.bio,
    required this.goal,
  });

  factory _CharacterForm.empty() {
    return _CharacterForm(
      avatarUrl: TextEditingController(),
      name: TextEditingController(),
      identity: TextEditingController(),
      personality: TextEditingController(),
      bio: TextEditingController(),
      goal: TextEditingController(),
    );
  }

  factory _CharacterForm.fromDraft(CharacterDraft draft) {
    return _CharacterForm(
      avatarUrl: TextEditingController(text: draft.avatarUrl),
      name: TextEditingController(text: draft.name),
      identity: TextEditingController(text: draft.identity),
      personality: TextEditingController(text: draft.personality),
      bio: TextEditingController(text: draft.bio),
      goal: TextEditingController(text: draft.goal),
    );
  }

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
}
