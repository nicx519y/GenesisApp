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
      padding: EdgeInsets.only(
        left: style.avatarSideSpacerWidth,
        right: style.systemMessageMargin.right,
        bottom: style.rowBottomPadding,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _rawImageUrl(message).isEmpty
                  ? null
                  : () => _showImageViewer(context),
              onLongPressStart: onLongPressStart,
              child: ChatThumbnailImage(
                key: ValueKey<String>('chat-image-message-${message.localId}'),
                imageUrl: _rawImageUrl(message),
                maxWidth: maxWidth,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          },
        ),
      ),
    );
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
    required this.maxWidth,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  final String imageUrl;
  final double maxWidth;
  final BorderRadiusGeometry borderRadius;

  @override
  State<ChatThumbnailImage> createState() => _ChatThumbnailImageState();
}

class _ChatThumbnailImageState extends State<ChatThumbnailImage> {
  ImageProvider<Object>? _provider;
  Size? _sourceSize;
  Size? _displaySize;
  bool _failed = false;
  int _generation = 0;
  double _devicePixelRatio = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextDevicePixelRatio =
        MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    if (_provider == null ||
        (nextDevicePixelRatio - _devicePixelRatio).abs() > 0.01) {
      _devicePixelRatio = nextDevicePixelRatio;
      final sourceSize = _sourceSize;
      if (sourceSize == null) {
        _resolveImage();
      } else {
        _configureImage(sourceSize);
      }
    }
  }

  @override
  void didUpdateWidget(covariant ChatThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveImage();
    } else if (oldWidget.maxWidth != widget.maxWidth) {
      final sourceSize = _sourceSize;
      if (sourceSize != null) _configureImage(sourceSize);
    }
  }

  void _resolveImage() {
    final generation = ++_generation;
    final source = widget.imageUrl.trim();
    _provider = null;
    _sourceSize = null;
    _displaySize = null;
    _failed = false;
    if (source.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    if (source.startsWith('assets/')) {
      _resolveAssetImage(source, generation);
      return;
    }
    resolveGenesisMessageImageSourceSize(source).then((sourceSize) {
      if (!mounted || generation != _generation) return;
      if (sourceSize == null) {
        setState(() => _failed = true);
        return;
      }
      _configureImage(sourceSize);
    });
  }

  void _resolveAssetImage(String source, int generation) {
    final provider = AssetImage(source);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (imageInfo, _) {
        stream.removeListener(listener);
        if (!mounted || generation != _generation) return;
        final scale = imageInfo.scale.isFinite && imageInfo.scale > 0
            ? imageInfo.scale
            : 1.0;
        _configureImage(
          Size(imageInfo.image.width / scale, imageInfo.image.height / scale),
        );
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        if (!mounted || generation != _generation) return;
        setState(() => _failed = true);
      },
    );
    stream.addListener(listener);
  }

  void _configureImage(Size sourceSize) {
    final displaySize = fitGenesisMessageImageSize(
      sourceSize: sourceSize,
      maxWidth: widget.maxWidth,
    );
    if (displaySize.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    final source = widget.imageUrl.trim();
    final resolvedSource = resizeGenesisMessageImageUrl(
      source,
      displaySize: displaySize,
      devicePixelRatio: _devicePixelRatio,
    );
    setState(() {
      _sourceSize = sourceSize;
      _displaySize = displaySize;
      _provider = source.startsWith('assets/')
          ? AssetImage(source)
          : GenesisStaticNetworkImageProvider(imageUrl: resolvedSource);
      _failed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    final displaySize = _displaySize;
    if (_failed || provider == null || displaySize == null) {
      return _buildPlaceholder();
    }

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
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return _buildPlaceholder(size: displaySize);
          },
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder({Size? size}) {
    final resolvedSize = size ?? Size(widget.maxWidth, widget.maxWidth);
    return SizedBox(
      width: resolvedSize.width,
      height: resolvedSize.height,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Image.asset(genesisDefaultListImageAsset, fit: BoxFit.contain),
      ),
    );
  }
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
