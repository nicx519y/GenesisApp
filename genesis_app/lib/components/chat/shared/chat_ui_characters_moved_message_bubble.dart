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
        child: Container(
          key: ValueKey<String>(
            'chat-characters-moved-message-${message.localId}',
          ),
          width: double.infinity,
          padding: style.systemMessagePadding,
          decoration: BoxDecoration(
            color: style.systemMessageBackgroundColor,
            borderRadius: BorderRadius.circular(
              style.systemMessageBorderRadius,
            ),
          ),
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
    final textColor =
        style.systemMessageTextStyle.color ?? context.genesisColors.textInverse;
    final metadataStyle = style.systemMessageTextStyle.copyWith(
      color: textColor.withValues(alpha: 0.72),
    );
    final locationName = genesisDisplaySafeText(movement.toLocationName);
    final canOpenLocation =
        onLocationTap != null &&
        movement.toLocationId.trim().isNotEmpty &&
        !movement.isDestinationCurrentLocation;
    final directionText = usePastTenseDirection
        ? (movement.isDestinationCurrentLocation ? 'came to' : 'went to')
        : (movement.isDestinationCurrentLocation
              ? 'has come to'
              : 'has gone to');
    if (scenePlate) {
      return _ChatTickSceneCharacterMovementRow(
        messageLocalId: messageLocalId,
        index: index,
        movement: movement,
        onLocationTap: onLocationTap,
        canOpenLocation: canOpenLocation,
        locationName: locationName,
        directionText: directionText,
      );
    }
    return Wrap(
      key: ValueKey<String>('chat-character-movement-$messageLocalId-$index'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 3,
      children: [
        SvgPicture.asset(
          routeIconAsset,
          width: 15,
          height: 15,
          colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
        ),
        Text(
          genesisDisplaySafeText(movement.characterName),
          style: style.systemMessageTextStyle.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(directionText, style: metadataStyle),
        Semantics(
          button: canOpenLocation,
          label: canOpenLocation ? 'Open $locationName' : locationName,
          child: GestureDetector(
            key: ValueKey<String>(
              'chat-character-movement-location-$messageLocalId-$index',
            ),
            behavior: HitTestBehavior.opaque,
            onTap: canOpenLocation ? () => onLocationTap!(movement) : null,
            child: Text(
              locationName,
              style: style.systemMessageTextStyle.copyWith(
                fontWeight: FontWeight.w400,
                decoration: canOpenLocation
                    ? TextDecoration.underline
                    : TextDecoration.none,
                decorationColor: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
    final chatTheme = context.genesisChatTheme;
    final mutedColor = chatTheme.tickHeader.withValues(alpha: 0.56);
    return Row(
      key: ValueKey<String>('chat-character-movement-$messageLocalId-$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: _ChatMovementIcon(
            color: chatTheme.tickHeader.withValues(alpha: 0.60),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 5,
            runSpacing: 3,
            children: [
              Text(
                genesisDisplaySafeText(movement.characterName),
                style: TextStyle(
                  color: chatTheme.tickHeader,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                directionText,
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w400,
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
                      Text(
                        locationName,
                        style: TextStyle(
                          // Where you already stand is plain white: nothing to
                          // navigate to, so it gets no accent and no caret.
                          color: canOpenLocation
                              ? chatTheme.tickLocation
                              : chatTheme.tickHeader,
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                          decoration: canOpenLocation
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: chatTheme.tickLocation.withValues(
                            alpha: 0.45,
                          ),
                        ),
                      ),
                      if (canOpenLocation) ...[
                        const SizedBox(width: 3),
                        _ChatLocationCaret(color: chatTheme.tickLocation),
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

/// 1r draws the movement row with two places joined by a short link: a
/// 14-unit glyph at stroke 1.4. The app was drawing the two-way route asset,
/// which is a different symbol.
class _ChatMovementIcon extends StatelessWidget {
  const _ChatMovementIcon({required this.color});

  static const double _size = 13;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
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
      ..drawCircle(Offset(4 * scale, 4 * scale), 2.2 * scale, paint)
      ..drawCircle(Offset(10 * scale, 10 * scale), 2.2 * scale, paint)
      ..drawLine(
        Offset(5.8 * scale, 5.8 * scale),
        Offset(8.2 * scale, 8.2 * scale),
        paint,
      );
  }

  @override
  bool shouldRepaint(_ChatMovementIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// The caret 1r draws next to a tappable place: a 16-unit path at stroke
/// 2.84. The Material chevron was a different shape and much lighter.
class _ChatLocationCaret extends StatelessWidget {
  const _ChatLocationCaret({required this.color});

  static const double _size = 9;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
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
  bool shouldRepaint(_ChatLocationCaretPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
