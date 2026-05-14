import 'package:flutter/material.dart';

import 'create_origin_draft_store.dart';

class CreateLocationsPage extends StatefulWidget {
  const CreateLocationsPage({super.key});

  @override
  State<CreateLocationsPage> createState() => _CreateLocationsPageState();
}

class _CreateLocationsPageState extends State<CreateLocationsPage> {
  static const Color _green = Color(0xFF198B64);
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
      return;
    }
    setState(() => _forms.add(_LocationForm.empty()));
  }

  void _removeLocation(int index) {
    if (_forms.length <= 1) {
      return;
    }
    final form = _forms.removeAt(index);
    form.dispose();
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '📍 Locations',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Add up to 10 important places for your story world.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_forms.length}/$_maxLocations (Added / Max)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6F6F6F),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (int i = 0; i < _forms.length; i++) ...<Widget>[
                        _LocationCard(
                          index: i + 1,
                          form: _forms[i],
                          onChanged: () => setState(() {}),
                          onDelete: () => _removeLocation(i),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _DashedAddButton(onTap: _addLocation),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _isSaving ? null : _saveLocations,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(_isSaving ? 'Saving...' : 'Save'),
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
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _LocationForm form;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCDCDC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Location $index',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: Color(0xFF8E8E8E),
                ),
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImagePlaceholder(form: form, onChanged: onChanged),
              const SizedBox(width: 10),
              Expanded(
                child: _TextFieldPlaceholder(form: form, onChanged: onChanged),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DescriptionPlaceholder(form: form, onChanged: onChanged),
          const SizedBox(height: 12),
          _InitialCharactersPlaceholder(form: form, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.form, required this.onChanged});

  final _LocationForm form;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, color: Color(0xFF8E8E8E), size: 22),
          const SizedBox(height: 6),
          const Text(
            'IMAGE\n(Optional)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6F6F6F),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: form.imageUrl,
            onChanged: (_) => onChanged(),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'URL',
            ),
          ),
        ],
      ),
    );
  }
}

class _TextFieldPlaceholder extends StatelessWidget {
  const _TextFieldPlaceholder({required this.form, required this.onChanged});

  final _LocationForm form;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location Name*',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE3E3E3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            controller: form.name,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${form.name.text.length}/25',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
          ),
        ),
      ],
    );
  }
}

class _DescriptionPlaceholder extends StatelessWidget {
  const _DescriptionPlaceholder({required this.form, required this.onChanged});

  final _LocationForm form;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description (Optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE3E3E3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: TextField(
            controller: form.description,
            onChanged: (_) => onChanged(),
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${form.description.text.length}/100',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
          ),
        ),
      ],
    );
  }
}

class _InitialCharactersPlaceholder extends StatelessWidget {
  const _InitialCharactersPlaceholder({
    required this.form,
    required this.onChanged,
  });

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
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE3E3E3)),
          ),
          child: TextField(
            controller: form.initialCharacters,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Character indexes, e.g. 0,1',
              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedAddButton extends StatelessWidget {
  const _DashedAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: const Color(0xFFB7B7B7),
            borderRadius: 14,
          ),
          child: const SizedBox(
            width: double.infinity,
            height: 50,
            child: Center(
              child: Text(
                '+ Add Location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _CreateLocationsPageState._green,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.borderRadius});

  final Color color;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const double dash = 6;
    const double gap = 4;

    final Rect rect = Offset.zero & size;
    final RRect rRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );
    canvas.clipRRect(rRect);

    for (double x = 0; x < size.width; x += dash + gap) {
      final double end = (x + dash).clamp(0, size.width);
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
      canvas.drawLine(Offset(x, size.height), Offset(end, size.height), paint);
    }

    for (double y = 0; y < size.height; y += dash + gap) {
      final double end = (y + dash).clamp(0, size.height);
      canvas.drawLine(Offset(0, y), Offset(0, end), paint);
      canvas.drawLine(Offset(size.width, y), Offset(size.width, end), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color ||
        borderRadius != oldDelegate.borderRadius;
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
}
