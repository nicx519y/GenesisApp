import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/page_header.dart';
import '../../ui/genesis_ui.dart';
import 'create_form_widgets.dart';
import 'create_origin_draft_store.dart';

class CreateStoryEventsPage extends StatefulWidget {
  const CreateStoryEventsPage({super.key});

  @override
  State<CreateStoryEventsPage> createState() => _CreateStoryEventsPageState();
}

class _CreateStoryEventsPageState extends State<CreateStoryEventsPage> {
  static const int _maxEvents = 20;
  final List<TextEditingController> _eventControllers =
      <TextEditingController>[];

  bool _isSaving = false;
  bool _isFinalSynced = false;
  Timer? _tempSaveDebounce;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final draft = await CreateOriginDraftStore.load();
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
    _tempSaveDebounce?.cancel();
    _tempSaveDebounce = Timer(const Duration(seconds: 10), () {
      unawaited(_writeTempDraft());
    });
    setState(() => _isFinalSynced = false);
  }

  List<StoryEventDraft> _snapshotEvents() {
    return _eventControllers
        .map((controller) => StoryEventDraft(event: controller.text.trim()))
        .toList(growable: false);
  }

  Future<void> _writeTempDraft() async {
    final events = _snapshotEvents();
    final draft = await CreateOriginDraftStore.load();
    await CreateOriginDraftStore.saveTemp(
      draft.copyWith(storyEvents: events, storyEventsSaved: false),
      syncedToFinal: false,
    );
  }

  Future<void> _saveEvents() async {
    setState(() => _isSaving = true);
    final draft = await CreateOriginDraftStore.load();
    final events = _snapshotEvents();

    _tempSaveDebounce?.cancel();
    await CreateOriginDraftStore.saveFinal(
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
