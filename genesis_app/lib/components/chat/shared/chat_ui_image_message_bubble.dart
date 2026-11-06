part of 'chat_ui_library.dart';

class ChatImageMessage extends StatelessWidget {
  const ChatImageMessage({
    super.key,
    required this.message,
    required this.style,
    this.imageViewerMessages = const <ChatMessageVm>[],
    this.onLongPressStart,
  });

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final List<ChatMessageVm> imageViewerMessages;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: style.rowBottomPadding),
      child: Align(
        alignment: Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            return ChatBubbleGeometry(
              child: message.photo != null
                  ? GestureDetector(
                      onLongPressStart:
                          message.photo!.status == ChatPhotoStatus.succeeded &&
                              message.photo!.imageUrl.isNotEmpty
                          ? onLongPressStart
                          : null,
                      child: _photoCard(context, maxWidth),
                    )
                  : ChatThumbnailImage(
                      key: ValueKey<String>(
                        'chat-image-message-${message.localId}',
                      ),
                      imageUrl: _rawImageUrl(message),
                      maxWidth: maxWidth,
                      placeholderColor: chatNarratorMessageBackgroundColor(
                        style,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      onTap: _rawImageUrl(message).isEmpty
                          ? null
                          : (source) => _showImageViewer(context, source),
                      onLongPressStart: onLongPressStart,
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _photoCard(BuildContext context, double maxWidth) {
    final photo = message.photo!;
    final hasImage = photo.imageUrl.isNotEmpty;
    final succeeded = photo.status == ChatPhotoStatus.succeeded;
    final failed = photo.status == ChatPhotoStatus.failed;
    final width = maxWidth;
    // Quantize the responsive card width at DPR=2 using the same CDN tiers as
    // the full-screen viewer, so nearby layout widths reuse a URL/cache entry.
    late final ImageProvider<Object> preview =
        photo.imageUrl.startsWith('assets/')
        ? AssetImage(photo.imageUrl)
        : GenesisStaticNetworkImageProvider(
            imageUrl: resizeGenesisImageUrl(
              photo.imageUrl,
              logicalWidth: width,
              devicePixelRatio: 2,
            ),
          );
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: ColoredBox(
                color: chatNarratorMessageBackgroundColor(style),
                child: hasImage
                    ? GenesisImageViewerSourceAnchor(
                        previewImageProvider: preview,
                        fit: BoxFit.cover,
                        borderRadius: BorderRadius.circular(8),
                        onTap: (source) => _showImageViewer(context, source),
                        child: Image(
                          image: preview,
                          fit: BoxFit.cover,
                          frameBuilder: (_, child, frame, synchronous) =>
                              synchronous || frame != null
                              ? child
                              : const SizedBox.expand(),
                          errorBuilder: (_, _, _) => const SizedBox.expand(),
                        ),
                      )
                    : Semantics(
                        liveRegion: true,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  failed
                                      ? Icons.broken_image_outlined
                                      : Icons.photo_camera_outlined,
                                  color: GenesisColors.darkTextSecondary,
                                  size: 28,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  failed
                                      ? (photo.failureMessage.isEmpty
                                            ? context.l10n.chatPhotoFailed
                                            : photo.failureMessage)
                                      : context.l10n.chatPhotoGenerating,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: GenesisColors.darkTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          if (hasImage && !succeeded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                failed
                    ? (photo.failureMessage.isEmpty
                          ? context.l10n.chatPhotoFailed
                          : photo.failureMessage)
                    : context.l10n.chatPhotoGenerating,
                style: const TextStyle(color: GenesisColors.darkTextSecondary),
              ),
            ),
          if (hasImage && photo.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                photo.description,
                style: const TextStyle(
                  color: GenesisColors.darkTextSecondary,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showImageViewer(BuildContext context, GenesisImageViewerSource source) {
    final sourceMessages = imageViewerMessages.isEmpty
        ? <ChatMessageVm>[message]
        : imageViewerMessages;
    final indexedMessages =
        <({int index, ChatMessageVm message})>[
          for (var index = 0; index < sourceMessages.length; index += 1)
            if ((sourceMessages[index].photo == null ||
                    sourceMessages[index].photo!.status ==
                        ChatPhotoStatus.succeeded) &&
                sourceMessages[index].isImage &&
                _rawImageUrl(sourceMessages[index]).isNotEmpty)
              (index: index, message: sourceMessages[index]),
        ]..sort((left, right) {
          final byTime = left.message.createdAt.compareTo(
            right.message.createdAt,
          );
          return byTime != 0 ? byTime : left.index.compareTo(right.index);
        });
    if (indexedMessages.isEmpty) {
      source.previewImage.dispose();
      return;
    }

    final initialIndex = indexedMessages.indexWhere(
      (entry) => entry.message.localId == message.localId,
    );
    final viewerInitialIndex = initialIndex < 0 ? 0 : initialIndex;
    showGenesisImageViewer(
      context,
      imageUrls: [
        for (final entry in indexedMessages) _rawImageUrl(entry.message),
      ],
      source: source,
      initialIndex: viewerInitialIndex,
    );
  }
}
