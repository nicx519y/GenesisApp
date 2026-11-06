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
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          _ChatPhotoPreview(
                            key: ValueKey(message.localId),
                            imageUrl: photo.imageUrl,
                            provider: preview,
                            onTap: (source, imageUrl) => _showImageViewer(
                              context,
                              source,
                              displayedPhotoUrl: imageUrl,
                            ),
                          ),
                          if (!photo.terminal)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: GenesisColors.darkOverlayBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      color: GenesisColors.darkTextPrimary,
                                      strokeWidth: 2,
                                      semanticsLabel:
                                          context.l10n.chatPhotoGenerating,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
          if (hasImage && failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                photo.failureMessage.isEmpty
                    ? context.l10n.chatPhotoFailed
                    : photo.failureMessage,
                style: const TextStyle(color: GenesisColors.darkTextSecondary),
              ),
            ),
          if (hasImage && photo.description.isNotEmpty)
            _ChatPhotoDescription(photo.description),
        ],
      ),
    );
  }

  void _showImageViewer(
    BuildContext context,
    GenesisImageViewerSource source, {
    String? displayedPhotoUrl,
  }) {
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
        for (final entry in indexedMessages)
          if (entry.message.localId == message.localId &&
              displayedPhotoUrl != null)
            displayedPhotoUrl
          else
            _rawImageUrl(entry.message),
      ],
      source: source,
      initialIndex: viewerInitialIndex,
    );
  }
}

typedef _ChatPhotoImage = ({String url, ImageProvider<Object> provider});

class _ChatPhotoPreview extends StatefulWidget {
  const _ChatPhotoPreview({
    super.key,
    required this.imageUrl,
    required this.provider,
    required this.onTap,
  });

  final String imageUrl;
  final ImageProvider<Object> provider;
  final void Function(GenesisImageViewerSource, String imageUrl) onTap;

  @override
  State<_ChatPhotoPreview> createState() => _ChatPhotoPreviewState();
}

class _ChatPhotoPreviewState extends State<_ChatPhotoPreview> {
  _ChatPhotoImage? _displayedImage;

  _ChatPhotoImage get _target =>
      (url: widget.imageUrl, provider: widget.provider);

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final displayed = _displayedImage;
    final viewerImage = displayed ?? target;
    return GenesisImageViewerSourceAnchor(
      previewImageProvider: viewerImage.provider,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(8),
      onTap: (source) => widget.onTap(source, viewerImage.url),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (displayed != null) _imageLayer(displayed),
          if (displayed != target) _imageLayer(target, reveal: true),
        ],
      ),
    );
  }

  Widget _imageLayer(_ChatPhotoImage image, {bool reveal = false}) => Image(
    // Keep the decoded Image mounted as the incoming layer becomes the base.
    key: ValueKey(image),
    image: image.provider,
    fit: BoxFit.cover,
    excludeFromSemantics: reveal,
    frameBuilder: (_, child, frame, _) {
      if (!reveal) return child;
      if (frame == null) return const SizedBox.expand();
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        onEnd: () {
          if (_target == image) setState(() => _displayedImage = image);
        },
        builder: (_, opacity, child) => Opacity(opacity: opacity, child: child),
        child: child,
      );
    },
    errorBuilder: (_, _, _) => const SizedBox.expand(),
  );
}

/// The caption under a generated photo: a record of the shot, not narration,
/// so it borrows the narrator's plate without its icon or italics. It is never
/// truncated, because that would cut off the closing bracket.
class _ChatPhotoDescription extends StatelessWidget {
  const _ChatPhotoDescription(this.description);

  static const double _maxWidth = 282;
  static const Map<String, String> _wrappers = <String, String>{
    '"': '"',
    "'": "'",
    '“': '”',
    '‘': '’',
    '「': '」',
    '『': '』',
    '《': '》',
    '(': ')',
    '（': '）',
    '[': ']',
    '【': '】',
  };

  final String description;

  /// The app adds its own brackets, so drop any pair already around the text.
  @visibleForTesting
  static String captionFor(String description) {
    var text = description.trim();
    while (text.characters.length >= 2) {
      final closing = _wrappers[text.characters.first];
      if (closing == null || text.characters.last != closing) break;
      text = text.characters.skipLast(1).skip(1).toString().trim();
    }
    return text.isEmpty ? '' : '「$text」';
  }

  @override
  Widget build(BuildContext context) {
    final caption = captionFor(description);
    if (caption.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: DecoratedBox(
            key: const ValueKey<String>('chat-photo-description'),
            decoration: BoxDecoration(
              color: kChatNarratorBubbleColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: GenesisTypography.body.copyWith(
                  color: GenesisColors.darkTextPrimary,
                  fontSize: 13,
                  height: 18 / 13,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
