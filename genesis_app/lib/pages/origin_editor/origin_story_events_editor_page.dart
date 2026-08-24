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
  static const int _maxEvents = 10;
  final List<TextEditingController> _eventControllers =
      <TextEditingController>[];
  final List<FocusNode> _eventFocusNodes = <FocusNode>[];

  bool _isSaving = false;

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
      _eventFocusNodes.add(FocusNode());
    }
    if (!mounted) return;
    setState(() {});
  }

  void _addEvent() {
    if (_eventControllers.length >= _maxEvents) {
      _showError('You can add up to $_maxEvents events.');
      return;
    }
    setState(() {
      _eventControllers.add(TextEditingController());
      _eventFocusNodes.add(FocusNode());
    });
    _onFormChanged();
  }

  void _requestRemoveEvent(int index) {
    _removeEvent(index);
  }

  void _removeEvent(int index) {
    if (_eventControllers.length <= 1) {
      _eventControllers[index].clear();
    } else {
      final controller = _eventControllers.removeAt(index);
      final focusNode = _eventFocusNodes.removeAt(index);
      controller.dispose();
      focusNode.dispose();
    }
    _onFormChanged();
  }

  void _onFormChanged() {
    setState(() {});
  }

  List<StoryEventDraft> _snapshotEvents() {
    return _eventControllers
        .map(
          (controller) => StoryEventDraft(
            event: normalizeGenesisUgcTextForDisplay(controller.text),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _saveEvents() async {
    setState(() => _isSaving = true);
    final draft = await widget.repository.loadDraft();
    final events = _snapshotEvents()
        .where((item) => item.event.trim().isNotEmpty)
        .toList(growable: false);

    await widget.repository.saveFinalDraft(
      draft.copyWith(storyEvents: events, storyEventsSaved: events.isNotEmpty),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  bool get _canUseSaveButton {
    return !_isSaving;
  }

  void _showError(String message) {
    showGenesisToast(context, message);
  }

  @override
  void dispose() {
    for (final controller in _eventControllers) {
      controller.dispose();
    }
    for (final focusNode in _eventFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.genesisColors.pageBackground,
      appBar: _StoryEventsAppBar(eventCount: _eventControllers.length),
      body: CreateKeyboardDismissArea(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < _eventControllers.length; i++) ...[
                        _StoryEventCard(
                          index: i + 1,
                          controller: _eventControllers[i],
                          focusNode: _eventFocusNodes[i],
                          nextFocusNode: i + 1 < _eventFocusNodes.length
                              ? _eventFocusNodes[i + 1]
                              : null,
                          onChanged: _onFormChanged,
                          onDelete: () {
                            _requestRemoveEvent(i);
                          },
                        ),
                        if (i + 1 < _eventControllers.length)
                          SizedBox(height: 12),
                      ],
                      if (_eventControllers.isNotEmpty)
                        const SizedBox(height: 20),
                      _StoryEventAddButton(onTap: _addEvent),
                    ],
                  ),
                ),
              ),
              _KeyboardHiddenBottomAction(
                minimum: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                child: GenesisPrimaryButton(
                  label: _isSaving ? 'Saving...' : 'Save',
                  height: 44,
                  borderRadius: BorderRadius.circular(13),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  onPressed: _canUseSaveButton ? _saveEvents : null,
                  onDisabledPressed: () =>
                      _showError('Saving is already in progress.'),
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
    required this.focusNode,
    required this.nextFocusNode,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return CreateFormCard(
      title: 'Event $index',
      onDelete: onDelete,
      showBorder: false,
      padding: EdgeInsets.zero,
      titleFontSize: 15,
      titleFontWeight: FontWeight.w800,
      headerBottomSpacing: 12,
      deleteButtonSize: 30,
      deleteIconSize: 14,
      deleteBackgroundColor: context.genesisCreateColors.fieldFill,
      deleteBorderColor: Colors.transparent,
      deleteBorderRadius: 10,
      deleteIconColor: context.genesisColors.foregroundStrong.withValues(
        alpha: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreateTextFieldBlock(
            label: '',
            controller: controller,
            hintText:
                'eg. A national chain scouts a vacant lot, threatening to undercut every local on price.',
            maxLength: 100,
            note: 'A key story beat the AI uses to steer the storyline.',
            minLines: 3,
            maxLines: 5,
            labelSize: 0,
            fieldBorderRadius: 13,
            fieldPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            minimumHeight: 88,
            inputFontSize: 13,
            hintFontSize: 13,
            inputLineHeight: 1.55,
            supportIconSize: 12,
            supportIconGap: 7,
            supportTextStyle: const TextStyle(fontSize: 11, height: 1.5),
            supportTextColor: context.genesisColors.foregroundStrong.withValues(
              alpha: 0.62,
            ),
            supportIconColor: context.genesisColors.foregroundStrong.withValues(
              alpha: 0.45,
            ),
            counterTextStyle: TextStyle(
              color: context.genesisColors.foregroundStrong.withValues(
                alpha: 0.5,
              ),
              fontSize: 9.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
            focusNode: focusNode,
            nextFocusNode: nextFocusNode,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _StoryEventsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _StoryEventsAppBar({required this.eventCount});

  final int eventCount;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return GenesisAppBar(
      title: 'Story Events',
      variant: GenesisAppBarVariant.leadingTitle,
      backgroundColor: context.genesisColors.surface,
      backButtonKey: const ValueKey<String>('story-events-back-button'),
      backForegroundColor: context.genesisCreateColors.text,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Center(
            child: Text(
              '$eventCount/${_OriginStoryEventsEditorPageState._maxEvents} '
              '(Added / Max)',
              key: const ValueKey<String>('story-events-count'),
              maxLines: 1,
              style: TextStyle(
                color: context.genesisColors.foregroundStrong.withValues(
                  alpha: 0.5,
                ),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StoryEventAddButton extends StatelessWidget {
  const _StoryEventAddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.genesisCreateColors.successText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('story-events-add-button'),
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: CustomPaint(
          key: const ValueKey<String>('story-events-add-button-border'),
          painter: CreateDashedRRectPainter(
            color: context.genesisColors.foregroundStrong.withValues(
              alpha: 0.24,
            ),
            radius: 13,
            strokeWidth: 1.5,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 14, color: accent),
                const SizedBox(width: 8),
                Text(
                  'Add Event',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
