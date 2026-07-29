part of 'chat_ui_library.dart';

class ChatImageMessage extends StatelessWidget {
  const ChatImageMessage({
    super.key,
    required this.message,
    required this.style,
    this.imageViewerMessages = const <ChatMessageVm>[],
    this.onLongPressStart,
  });

  static const double maxImageExtent = 250;

  final ChatMessageVm message;
  final ChatUiStyleConfig style;
  final List<ChatMessageVm> imageViewerMessages;
  final GestureLongPressStartCallback? onLongPressStart;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _thumbnailImageUrl(context);
    return Padding(
      padding: EdgeInsets.only(
        left: style.avatarSideSpacerWidth,
        bottom: style.rowBottomPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _rawImageUrl(message).isEmpty
              ? null
              : () => _showImageViewer(context),
          onLongPressStart: onLongPressStart,
          child: ChatThumbnailImage(
            key: ValueKey<String>('chat-image-message-${message.localId}'),
            imageUrl: imageUrl,
            maxExtent: maxImageExtent,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  String _thumbnailImageUrl(BuildContext context) {
    final source = _rawImageUrl(message);
    if (source.isEmpty) return '';
    final devicePixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    final selected = selectGenesisImageUrl(
      source,
      logicalWidth: maxImageExtent,
      logicalHeight: maxImageExtent,
      devicePixelRatio: devicePixelRatio,
    ).trim();
    final candidate = selected.isNotEmpty ? selected : source;
    final resized = resizeGenesisImageUrl(
      candidate,
      logicalWidth: maxImageExtent,
      devicePixelRatio: devicePixelRatio,
    );
    return resized.isNotEmpty ? resized : candidate;
  }

  void _showImageViewer(BuildContext context) {
    final sourceMessages = imageViewerMessages.isEmpty
        ? <ChatMessageVm>[message]
        : imageViewerMessages;
    final indexedMessages =
        <({int index, ChatMessageVm message})>[
          for (var index = 0; index < sourceMessages.length; index += 1)
            if (sourceMessages[index].isImage &&
                _rawImageUrl(sourceMessages[index]).isNotEmpty)
              (index: index, message: sourceMessages[index]),
        ]..sort((left, right) {
          final byTime = left.message.createdAt.compareTo(
            right.message.createdAt,
          );
          return byTime != 0 ? byTime : left.index.compareTo(right.index);
        });
    if (indexedMessages.isEmpty) return;

    final initialIndex = indexedMessages.indexWhere(
      (entry) => entry.message.localId == message.localId,
    );
    showGenesisImageViewer(
      context,
      imageUrls: [
        for (final entry in indexedMessages) _rawImageUrl(entry.message),
      ],
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }
}

class ChatThumbnailImage extends StatefulWidget {
  const ChatThumbnailImage({
    super.key,
    required this.imageUrl,
    this.maxExtent = ChatImageMessage.maxImageExtent,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final String imageUrl;
  final double maxExtent;
  final BorderRadiusGeometry borderRadius;

  @override
  State<ChatThumbnailImage> createState() => _ChatThumbnailImageState();
}

class _ChatThumbnailImageState extends State<ChatThumbnailImage> {
  ImageProvider<Object>? _provider;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  Size? _intrinsicSize;
  bool _failed = false;
  int _resolveGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant ChatThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _intrinsicSize = null;
      _failed = false;
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _detachImageStream();
    super.dispose();
  }

  void _resolveImage() {
    _detachImageStream();
    final source = widget.imageUrl.trim();
    if (source.isEmpty) {
      _provider = null;
      _failed = true;
      return;
    }

    final ImageProvider<Object> provider = source.startsWith('assets/')
        ? AssetImage(source)
        : GenesisStaticNetworkImageProvider(imageUrl: source);
    final generation = ++_resolveGeneration;
    _provider = provider;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, synchronousCall) {
        if (generation != _resolveGeneration) return;
        final nextSize = Size(
          imageInfo.image.width.toDouble(),
          imageInfo.image.height.toDouble(),
        );
        if (synchronousCall) {
          _intrinsicSize = nextSize;
          _failed = false;
          return;
        }
        if (!mounted) return;
        setState(() {
          _intrinsicSize = nextSize;
          _failed = false;
        });
      },
      onError: (error, stackTrace) {
        if (generation != _resolveGeneration || !mounted) return;
        setState(() => _failed = true);
      },
    );
    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _detachImageStream() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
    _resolveGeneration += 1;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final intrinsicSize = _intrinsicSize;
    if (_failed || provider == null || intrinsicSize == null) {
      return _buildPlaceholder();
    }

    final displaySize = _fitWithinMaxExtent(
      intrinsicSize,
      maxExtent: widget.maxExtent,
    );
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: displaySize.width,
        height: displaySize.height,
        child: Image(
          image: provider,
          width: displaySize.width,
          height: displaySize.height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxExtent,
        maxHeight: widget.maxExtent,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Image.asset(genesisDefaultListImageAsset, fit: BoxFit.contain),
      ),
    );
  }
}

Size _fitWithinMaxExtent(Size source, {required double maxExtent}) {
  if (source.width <= 0 ||
      source.height <= 0 ||
      !source.width.isFinite ||
      !source.height.isFinite ||
      !maxExtent.isFinite ||
      maxExtent <= 0) {
    return Size.zero;
  }
  final scale = math.min(
    1,
    math.min(maxExtent / source.width, maxExtent / source.height),
  );
  return Size(source.width * scale, source.height * scale);
}

String _rawImageUrl(ChatMessageVm message) {
  final imageUrl = message.imageUrl.trim();
  return imageUrl.isNotEmpty ? imageUrl : message.text.trim();
}

double _normalBubbleMaxWidth(BuildContext context, ChatUiStyleConfig style) {
  return _normalBubbleMaxWidthForWidth(MediaQuery.sizeOf(context).width, style);
}

double _normalBubbleMaxWidthForWidth(double width, ChatUiStyleConfig style) {
  final rowAvailableWidth =
      width -
      style.avatarSize -
      style.avatarBubbleGap -
      style.avatarSideSpacerWidth;
  return rowAvailableWidth > 0 ? rowAvailableWidth : width;
}

class _ChatAvatarSideSpacer extends StatelessWidget {
  const _ChatAvatarSideSpacer({required this.style});

  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: style.avatarSideSpacerWidth);
  }
}
