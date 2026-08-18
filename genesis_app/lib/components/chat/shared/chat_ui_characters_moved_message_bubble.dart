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
  });

  final String messageLocalId;
  final int index;
  final ChatCharacterMovementVm movement;
  final ChatUiStyleConfig style;
  final ChatCharacterMovementTap? onLocationTap;
  final bool usePastTenseDirection;

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
