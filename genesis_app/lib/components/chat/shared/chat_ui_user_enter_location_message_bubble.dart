part of 'chat_ui_library.dart';

class ChatUserEnterLocationMessageBubble extends StatelessWidget {
  const ChatUserEnterLocationMessageBubble({
    super.key,
    required this.message,
    required this.style,
    this.onLongPressStart,
  });

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final payload = message.timelinePayload;
    if (payload is! ChatUserEnterLocationPayloadVm) {
      return const SizedBox.shrink();
    }
    if (!style.useScenePlateBubbleGeometry) {
      return ChatSystemMessage(
        text: payload.text,
        fullWidth: false,
        useFullAvailableWidth: true,
        textAlign: TextAlign.center,
        bubbleKey: ValueKey<String>(
          'chat-user-enter-location-message-${message.localId}',
        ),
        style: style,
        onLongPressStart: onLongPressStart,
      );
    }
    final displayParts = _chatEnterLocationDisplayParts(payload.text);
    final mainTextStyle = GenesisTypography.withFallback(
      const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );
    return Center(
      child: GestureDetector(
        onLongPressStart: onLongPressStart,
        child: Container(
          key: ValueKey<String>(
            'chat-user-enter-location-message-${message.localId}',
          ),
          margin: style.systemMessageMargin,
          padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
          decoration: BoxDecoration(
            color: const Color(0x21FFFFFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                key: const ValueKey<String>('chat-user-enter-location-icon'),
                size: const Size.square(12),
                painter: _ChatEnterLocationIconPainter(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: displayParts == null
                    ? _InlineMarkdownText(
                        text: payload.text,
                        textAlign: TextAlign.left,
                        style: mainTextStyle,
                      )
                    : Text.rich(
                        TextSpan(
                          style: mainTextStyle,
                          children: [
                            TextSpan(text: displayParts.characterName),
                            TextSpan(
                              text: ' came to ',
                              style: mainTextStyle.copyWith(
                                color: Colors.white.withValues(alpha: 0.73),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(text: displayParts.locationName),
                          ],
                        ),
                        textAlign: TextAlign.left,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

({String characterName, String locationName})? _chatEnterLocationDisplayParts(
  String text,
) {
  final displayText = genesisDisplaySafeText(text).trim();
  final match = RegExp(
    r'^(.+?)\s+(?:entered|came\s+to)\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(displayText);
  if (match == null) return null;
  return (
    characterName: match.group(1)!.trim(),
    locationName: match.group(2)!.trim(),
  );
}

class _ChatEnterLocationIconPainter extends CustomPainter {
  const _ChatEnterLocationIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final centerY = size.height / 2;
    final arrowEndX = size.width - 4;
    canvas.drawLine(Offset(1.5, centerY), Offset(arrowEndX, centerY), paint);
    canvas.drawPath(
      Path()
        ..moveTo(arrowEndX - 3, centerY - 3)
        ..lineTo(arrowEndX, centerY)
        ..lineTo(arrowEndX - 3, centerY + 3),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - 1.5, 2.5),
      Offset(size.width - 1.5, size.height - 2.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChatEnterLocationIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
