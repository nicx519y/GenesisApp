import 'package:flutter/material.dart';

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
    setState(() {});
  }

  void _addEvent() {
    if (_eventControllers.length >= _maxEvents) {
      return;
    }
    setState(() => _eventControllers.add(TextEditingController()));
  }

  void _removeEvent(int index) {
    if (_eventControllers.length <= 1) {
      return;
    }
    final controller = _eventControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  Future<void> _saveEvents() async {
    setState(() => _isSaving = true);
    final draft = await CreateOriginDraftStore.load();
    final events = _eventControllers
        .map((controller) => StoryEventDraft(event: controller.text.trim()))
        .toList(growable: false);

    await CreateOriginDraftStore.save(
      draft.copyWith(storyEvents: events, storyEventsSaved: true),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    for (final controller in _eventControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double titleSize = 18;
    const double bodySize = 14;
    const double captionSize = 12;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          '📜 Story Events',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Add up to 20 key events for your story.',
                        style: TextStyle(
                          fontSize: bodySize,
                          height: 1.45,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${_eventControllers.length}/$_maxEvents (Added / Max)',
                          style: const TextStyle(
                            fontSize: captionSize,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (
                        int i = 0;
                        i < _eventControllers.length;
                        i++
                      ) ...<Widget>[
                        _StoryEventCard(
                          index: i + 1,
                          controller: _eventControllers[i],
                          onChanged: () => setState(() {}),
                          onDelete: () => _removeEvent(i),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _DashedBorderButton(
                        onTap: _addEvent,
                        child: const Text(
                          '+ Add Event',
                          style: TextStyle(
                            fontSize: bodySize,
                            color: Color(0xFF4B5563),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveEvents,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
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
    const double bodySize = 14;
    const double captionSize = 12;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Event $index',
                style: const TextStyle(
                  fontSize: bodySize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF9CA3AF),
                ),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              minLines: 6,
              maxLines: 8,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Event (any language)',
                hintStyle: TextStyle(
                  fontSize: bodySize,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${controller.text.length}/1000',
              style: const TextStyle(
                fontSize: captionSize,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderButton extends StatelessWidget {
  const _DashedBorderButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: const Color(0xFFD1D5DB),
            radius: 12,
          ),
          child: Container(
            width: double.infinity,
            height: 50,
            alignment: Alignment.center,
            child: child,
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
