import 'dart:convert';

import 'package:flutter/material.dart';

import 'create_origin_draft_store.dart';

class CreateBasicsPage extends StatefulWidget {
  const CreateBasicsPage({super.key});

  @override
  State<CreateBasicsPage> createState() => _CreateBasicsPageState();
}

class _CreateBasicsPageState extends State<CreateBasicsPage> {
  final TextEditingController _originNameController = TextEditingController();
  final TextEditingController _worldViewController = TextEditingController();
  final TextEditingController _worldLogicController = TextEditingController();
  final TextEditingController _metricController = TextEditingController();
  final TextEditingController _coverImageController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final draft = await CreateOriginDraftStore.load();
    if (!mounted) return;
    _originNameController.text = draft.basics.originName;
    _worldViewController.text = draft.basics.worldView;
    _worldLogicController.text = draft.basics.worldLogic;
    _metricController.text = draft.basics.metricJson;
    _coverImageController.text = draft.basics.coverImageUrl;
    setState(() {});
  }

  Future<void> _onSave() async {
    final originName = _originNameController.text.trim();
    final worldView = _worldViewController.text.trim();
    final metricJson = _metricController.text.trim();
    final coverImage = _coverImageController.text.trim();

    if (originName.isEmpty) {
      _showError('Origin Name is required.');
      return;
    }
    if (worldView.isEmpty) {
      _showError('World View is required.');
      return;
    }
    if (coverImage.isEmpty) {
      _showError('Cover Image is required.');
      return;
    }
    if (metricJson.isNotEmpty) {
      try {
        jsonDecode(metricJson);
      } catch (_) {
        _showError('Metric must be valid JSON.');
        return;
      }
    }

    setState(() => _isSaving = true);
    final draft = await CreateOriginDraftStore.load();
    final updated = draft.copyWith(
      basics: draft.basics.copyWith(
        originName: originName,
        worldView: worldView,
        worldLogic: _worldLogicController.text.trim(),
        metricJson: metricJson,
        coverImageUrl: coverImage,
      ),
      basicsSaved: true,
    );
    await CreateOriginDraftStore.save(updated);
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
    _originNameController.dispose();
    _worldViewController.dispose();
    _worldLogicController.dispose();
    _metricController.dispose();
    _coverImageController.dispose();
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
          '🌐 Basics',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Build the core setting details for your origin world.',
                style: TextStyle(
                  color: Color(0xFF6F6F6F),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _FieldSection(
                label: 'Origin Name *',
                counter: '${_originNameController.text.length}/30',
                placeholder: 'Type origin name',
                minLines: 1,
                maxLines: 1,
                controller: _originNameController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              _FieldSection(
                label: 'World View - Public*',
                counter: '${_worldViewController.text.length}/1000',
                placeholder: 'Describe the public worldview of this origin...',
                minLines: 5,
                maxLines: 5,
                controller: _worldViewController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              _FieldSection(
                label: 'World Logic - Hidden (Optional)',
                counter: '${_worldLogicController.text.length}/2000',
                placeholder: 'Describe hidden rules, truths, or mechanisms...',
                minLines: 6,
                maxLines: 6,
                controller: _worldLogicController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              _FieldSection(
                label: 'Metric (optional JSON)',
                helperText:
                    'Use optional JSON metrics to define measurable world parameters.',
                placeholder:
                    '{\n  "power_scale": 0,\n  "civilization_level": ""\n}',
                minLines: 7,
                maxLines: 7,
                controller: _metricController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              _FieldSection(
                label: 'Cover Image *',
                placeholder: 'Paste image URL or uploaded path',
                minLines: 1,
                maxLines: 1,
                controller: _coverImageController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 30),
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
            onPressed: _isSaving ? null : _onSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF198B64),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFBFD8CD),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
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

class _FieldSection extends StatelessWidget {
  const _FieldSection({
    required this.label,
    required this.placeholder,
    required this.minLines,
    required this.maxLines,
    required this.controller,
    required this.onChanged,
    this.counter,
    this.helperText,
  });

  final String label;
  final String placeholder;
  final int minLines;
  final int maxLines;
  final String? counter;
  final String? helperText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (counter != null)
              Text(
                counter!,
                style: const TextStyle(color: Color(0xFF9C9C9C), fontSize: 12),
              ),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: const TextStyle(
              color: Color(0xFF8D8D8D),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6E6E8)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: minLines,
            maxLines: maxLines,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              height: 1.35,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: placeholder,
              hintStyle: const TextStyle(
                color: Color(0xFFA0A0A0),
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
