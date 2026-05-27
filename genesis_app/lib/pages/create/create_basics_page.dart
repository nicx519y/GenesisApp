import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../components/page_header.dart';
import '../../ui/genesis_ui.dart';
import 'create_form_widgets.dart';
import 'create_origin_draft_store.dart';
import 'create_origin_id_utils.dart';

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

  Timer? _tempSaveDebounce;
  bool _isSaving = false;
  bool _isFinalSynced = false;

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
    _isFinalSynced = draft.basicsSaved;
    setState(() {});
  }

  void _onFormChanged() {
    _tempSaveDebounce?.cancel();
    _tempSaveDebounce = Timer(const Duration(seconds: 10), () {
      unawaited(_writeTempDraft());
    });
    setState(() => _isFinalSynced = false);
  }

  Future<CreateOriginDraft> _draftWithCurrentBasics({
    required bool basicsSaved,
    String? originId,
  }) async {
    final originName = _originNameController.text.trim();
    final worldView = _worldViewController.text.trim();
    final worldLogic = _worldLogicController.text.trim();
    final metricJson = _metricController.text.trim();
    final coverImageUrl = _coverImageController.text.trim();
    final draft = await CreateOriginDraftStore.load();
    return draft.copyWith(
      basics: draft.basics.copyWith(
        originId: originId ?? draft.basics.originId,
        originName: originName,
        worldView: worldView,
        worldLogic: worldLogic,
        metricJson: metricJson,
        coverImageUrl: coverImageUrl,
      ),
      basicsSaved: basicsSaved,
    );
  }

  Future<void> _writeTempDraft() async {
    final draft = await _draftWithCurrentBasics(basicsSaved: false);
    await CreateOriginDraftStore.saveTemp(draft, syncedToFinal: false);
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
    final uidFuture = readCreateOriginUid(context);
    final draft = await CreateOriginDraftStore.load();
    final uid = await uidFuture;
    final originId = draft.basics.originId.trim().isEmpty
        ? createUidTimestampHashId(uid: uid, prefix: 'origin')
        : draft.basics.originId.trim();
    final updatedDraft = draft.copyWith(
      basics: draft.basics.copyWith(
        originId: originId,
        originName: originName,
        worldView: worldView,
        worldLogic: _worldLogicController.text.trim(),
        metricJson: metricJson,
        coverImageUrl: coverImage,
      ),
      basicsSaved: true,
    );
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
      appBar: const GenesisBackAppBar(pageName: '🌐 Basics'),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Define the core settings of your new world.',
                        style: TextStyle(
                          color: createFormMuted,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 26),
                      CreateTextFieldBlock(
                        label: 'Origin Name *',
                        controller: _originNameController,
                        hintText: 'Enter world name...',
                        maxLength: 30,
                        maxLines: 1,
                        prefix: const Text(
                          '#',
                          style: TextStyle(
                            color: createFormText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 24),
                      CreateTextFieldBlock(
                        label: 'World View - Public*',
                        controller: _worldViewController,
                        hintText:
                            'Describe what users see at first glance: the grand cities, immediate crises, and well-known legends...',
                        maxLength: 1000,
                        minLines: 4,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 24),
                      CreateTextFieldBlock(
                        label: 'World Logic - Hidden (Optional)',
                        controller: _worldLogicController,
                        hintText:
                            'Define the logic for AI to drive the story: hidden conspiracies, physical laws, undisclosed boss weaknesses, and numerical boundaries...',
                        maxLength: 2000,
                        minLines: 5,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 24),
                      CreateTextFieldBlock(
                        label: 'Metric (Optional)',
                        controller: _metricController,
                        hintText:
                            'Leave blank to use server default. Example: {"mode":"quantitative","label":"Influence","unit":"pts","range":[0,100],"default":50}',
                        minLines: 3,
                        onChanged: (_) => _onFormChanged(),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'Cover Image *',
                        style: TextStyle(
                          color: createFormText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CreateUploadBox(
                            controller: _coverImageController,
                            label: 'Upload World Image',
                            width: 170,
                            height: 230,
                            iconSize: 42,
                            cropSize: const Size(768, 1024),
                            onChanged: _onFormChanged,
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Used for cards and detail pages.\nRecommend ~768×1024 px.\nSupported formats: JPG, PNG, WEBP.',
                              style: TextStyle(
                                color: createFormMuted,
                                fontSize: 12,
                                height: 1.28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  onPressed: (_isSaving || _isFinalSynced) ? null : _onSave,
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
