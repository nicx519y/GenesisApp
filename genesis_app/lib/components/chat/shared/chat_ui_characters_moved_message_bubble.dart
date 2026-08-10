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
              _ChatCharactersMovedTitle(style: style),
              const SizedBox(height: 7),
              for (var index = 0; index < payload.movements.length; index += 1)
                _ChatCharacterMovementRow(
                  messageLocalId: message.localId,
                  index: index,
                  movement: payload.movements[index],
                  style: style,
                  onLocationTap: onLocationTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatCharactersMovedTitle extends StatelessWidget {
  const _ChatCharactersMovedTitle({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.directions_walk_rounded, size: 15, color: textColor),
        const SizedBox(width: 5),
        Text(
          'Character destinations',
          style: style.systemMessageTextStyle.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
  });

  final String messageLocalId;
  final int index;
  final ChatCharacterMovementVm movement;
  final ChatUiStyleConfig style;
  final ChatCharacterMovementTap? onLocationTap;

  @override
  Widget build(BuildContext context) {
    final textColor = style.systemMessageTextStyle.color ?? Colors.white;
    final metadataStyle = style.systemMessageTextStyle.copyWith(
      color: textColor.withValues(alpha: 0.72),
    );
    final locationName = genesisDisplaySafeText(movement.toLocationName);
    final canOpenLocation =
        onLocationTap != null && movement.toLocationId.trim().isNotEmpty;
    return Padding(
      key: ValueKey<String>('chat-character-movement-$messageLocalId-$index'),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 5,
        runSpacing: 3,
        children: [
          Icon(Icons.directions_walk_rounded, size: 14, color: textColor),
          Text(
            genesisDisplaySafeText(movement.characterName),
            style: style.systemMessageTextStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text('has gone to', style: metadataStyle),
          Semantics(
            button: canOpenLocation,
            label: canOpenLocation ? 'Open $locationName' : locationName,
            child: GestureDetector(
              key: ValueKey<String>(
                'chat-character-movement-location-$messageLocalId-$index',
              ),
              behavior: HitTestBehavior.opaque,
              onTap: canOpenLocation ? () => onLocationTap!(movement) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  locationName,
                  style: style.systemMessageTextStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    decoration: canOpenLocation
                        ? TextDecoration.underline
                        : TextDecoration.none,
                    decorationColor: textColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
