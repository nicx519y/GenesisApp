part of 'chat_ui_library.dart';

class ChatCharactersMovedMessageBubble extends StatelessWidget {
  const ChatCharactersMovedMessageBubble({
    super.key,
    required this.message,
    required this.style,
    this.onLongPressStart,
    this.onLocationTap,
  });

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final GestureLongPressStartCallback? onLongPressStart;
  final ChatCharacterMovementTap? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final payload = message.timelinePayload;
    if (payload is! ChatCharactersMovedPayloadVm || payload.movements.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: style.systemMessageMargin,
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        child: ChatBubbleGeometry(
          child: Container(
            key: ValueKey<String>(
              'chat-characters-moved-message-${message.localId}',
            ),
            width: double.infinity,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(
                style.systemMessageBorderRadius,
              ),
            ),
            child: ChatStreamingBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (
                    var index = 0;
                    index < payload.movements.length;
                    index += 1
                  ) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _ChatCharacterMovementRow(
                      messageLocalId: message.localId,
                      index: index,
                      movement: payload.movements[index],
                      style: style,
                      onLocationTap: onLocationTap,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatCharacterMovementRow extends StatelessWidget {
  const _ChatCharacterMovementRow({
    required this.messageLocalId,
    required this.index,
    required this.movement,
    required this.style,
    required this.onLocationTap,
    this.usePastTenseDirection = false,
    this.scenePlate = false,
  });

  final String messageLocalId;
  final int index;
  final ChatCharacterMovementVm movement;
  final ChatUiStyleConfig style;
  final ChatCharacterMovementTap? onLocationTap;
  final bool usePastTenseDirection;
  final bool scenePlate;

  @override
  Widget build(BuildContext context) {
    final entry = ChatMentionScope.maybeCatalogOf(
      context,
    )?.entryForId(movement.toLocationId);
    final canOpen =
        onLocationTap != null &&
        movement.toLocationId.trim().isNotEmpty &&
        !movement.isDestinationCurrentLocation;
    return Padding(
      // Fill the Tick content column, matching its Global status cards.
      padding: EdgeInsets.zero,
      child: ChatLocationJumpCard(
        key: ValueKey('chat-character-movement-$messageLocalId-$index'),
        names: genesisDisplaySafeText(movement.characterName),
        action: movement.isDestinationCurrentLocation ? 'came to' : 'went to',
        parentPath: entry?.subtitle ?? '',
        locationName: genesisDisplaySafeText(movement.toLocationName),
        imageUrl: entry?.imageUrl ?? '',
        locationKey: ValueKey(
          'chat-character-movement-location-$messageLocalId-$index',
        ),
        onTap: canOpen ? () => onLocationTap!(movement) : null,
      ),
    );
  }
}

// Retained during migration for comparison with the previous inline presentation.
// ignore: unused_element
class _ChatTickSceneCharacterMovementRow extends StatelessWidget {
  const _ChatTickSceneCharacterMovementRow({
    required this.messageLocalId,
    required this.index,
    required this.movement,
    required this.onLocationTap,
    required this.canOpenLocation,
    required this.locationName,
    required this.directionText,
  });

  final String messageLocalId;
  final int index;
  final ChatCharacterMovementVm movement;
  final ChatCharacterMovementTap? onLocationTap;
  final bool canOpenLocation;
  final String locationName;
  final String directionText;

  @override
  Widget build(BuildContext context) {
    const mutedColor = GenesisColors.darkTextSecondary;
    return Row(
      key: ValueKey<String>('chat-character-movement-$messageLocalId-$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChatTickFirstLineIcon(
          textStyle: GenesisTypography.bodyStrong,
          child: _ChatMovementIcon(
            color: _tickMessageHeaderColor.withValues(alpha: 0.60),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            runSpacing: 3,
            children: [
              ChatStreamingText(
                child: Text(
                  genesisDisplaySafeText(movement.characterName),
                  style: GenesisTypography.bodyStrong.copyWith(
                    color: GenesisColors.darkTextPrimary,
                  ),
                ),
              ),
              ChatStreamingText(
                child: Text(
                  directionText,
                  style: GenesisTypography.body.copyWith(color: mutedColor),
                ),
              ),
              Semantics(
                button: canOpenLocation,
                label: canOpenLocation ? 'Open $locationName' : locationName,
                child: GestureDetector(
                  key: ValueKey<String>(
                    'chat-character-movement-location-$messageLocalId-$index',
                  ),
                  behavior: HitTestBehavior.opaque,
                  onTap: canOpenLocation
                      ? () => onLocationTap!(movement)
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChatStreamingText(
                        child: Text(
                          locationName,
                          style: GenesisTypography.bodyStrong.copyWith(
                            color: canOpenLocation
                                ? GenesisColors.redSecondary
                                : _tickMessageHeaderColor,
                            decoration: canOpenLocation
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationColor: GenesisColors.redSecondary
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      if (canOpenLocation) ...[
                        const SizedBox(width: 3),
                        const _ChatLocationCaret(
                          color: GenesisColors.redSecondary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatMovementIcon extends StatelessWidget {
  const _ChatMovementIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 13,
      child: CustomPaint(painter: _ChatMovementIconPainter(color: color)),
    );
  }
}

class _ChatMovementIconPainter extends CustomPainter {
  const _ChatMovementIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 14;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawCircle(Offset(4 * scale, 10 * scale), 2.2 * scale, paint)
      ..drawCircle(Offset(10 * scale, 4 * scale), 2.2 * scale, paint)
      ..drawLine(
        Offset(5.8 * scale, 8.2 * scale),
        Offset(8.2 * scale, 5.8 * scale),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant _ChatMovementIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ChatLocationCaret extends StatelessWidget {
  const _ChatLocationCaret({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 9,
      child: CustomPaint(painter: _ChatLocationCaretPainter(color: color)),
    );
  }
}

class _ChatLocationCaretPainter extends CustomPainter {
  const _ChatLocationCaretPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.84 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(6 * scale, 2.8 * scale)
        ..lineTo(11.4 * scale, 8 * scale)
        ..lineTo(6 * scale, 13.2 * scale),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChatLocationCaretPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
