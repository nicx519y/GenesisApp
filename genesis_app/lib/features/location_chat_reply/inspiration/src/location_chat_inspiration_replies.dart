part of '../../../../pages/chat/location_chat_reply_actions.dart';

/// Counts actual text layouts, rather than widget builds, in debug/test runs.
@visibleForTesting
int debugLocationChatInspirationTextLayoutCount = 0;

class LocationChatInspirationReplies extends StatefulWidget {
  const LocationChatInspirationReplies({
    super.key,
    this.identity,
    required this.expanded,
    required this.style,
    required this.maxWidthCap,
    required this.replies,
    required this.initialPage,
    required this.onPageChanged,
    required this.onSend,
    required this.onEdit,
  });

  final Object? identity;
  final bool expanded;
  final ChatUiStyleConfig style;
  final double? maxWidthCap;
  final List<String> replies;
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSend;
  final ValueChanged<String> onEdit;

  @override
  State<LocationChatInspirationReplies> createState() =>
      _InspirationRepliesState();
}

class _InspirationRepliesState extends State<LocationChatInspirationReplies>
    with SingleTickerProviderStateMixin {
  late final AnimationController _expansionController;
  late final CurvedAnimation _expansion;
  PageController? _pageController;
  final _heightCache = _InspirationHeightCache();
  double _viewportFraction = 1;
  int _currentPage = 0;
  List<String> _displayedReplies = const [];
  Object? _displayedIdentity;
  bool get _wantsOpen => widget.expanded && widget.replies.isNotEmpty;
  bool get _acceptsInput => _wantsOpen && widget.identity == _displayedIdentity;

  static const double _editStripWidth = 27;

  void _handleCardTap(int index, {bool edit = false}) {
    final controller = _pageController;
    if (!_acceptsInput || controller == null || !controller.hasClients) return;
    final page = controller.page ?? _currentPage.toDouble();
    if (index != _currentPage || (page - index).abs() > 0.001) {
      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (edit) {
      widget.onEdit(replies[index]);
    } else {
      widget.onSend(replies[index]);
    }
  }

  void _configureCarousel(double viewportWidth, double cardWidth) {
    final fraction = viewportWidth <= 0
        ? 1.0
        : ((cardWidth + 12) / viewportWidth).clamp(0.0, 1.0);
    if (_pageController != null &&
        (_viewportFraction - fraction).abs() < 0.0001) {
      return;
    }
    _pageController?.dispose();
    _viewportFraction = fraction;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: fraction,
    );
  }

  ChatUiStyleConfig get style => widget.style;
  double? get maxWidthCap => widget.maxWidthCap;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      vsync: this,
      duration: LocationChatReplyActions.inspirationAnimationDuration,
    );
    _expansion = CurvedAnimation(
      parent: _expansionController,
      curve: LocationChatReplyActions.inspirationAnimationCurve,
    );
    _expansionController.addStatusListener(_onExpansionStatus);
    _syncExpansion();
  }

  @override
  void didUpdateWidget(covariant LocationChatInspirationReplies oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncExpansion();
  }

  // Every close (manual, source reset, hidden toolbar or loading replacement)
  // keeps its visual snapshot until this same reverse animation completes.
  void _collapse() {
    if (!_expansionController.isDismissed) _expansionController.reverse();
  }

  void _syncExpansion() {
    if (!_wantsOpen) {
      _collapse();
      return;
    }
    if (_displayedIdentity != widget.identity &&
        !_expansionController.isDismissed) {
      _collapse();
      return;
    }
    if (_expansionController.isDismissed) {
      _pageController?.dispose();
      _pageController = null;
      _currentPage = widget.initialPage.clamp(0, widget.replies.length - 1);
    }
    _displayedIdentity = widget.identity;
    _displayedReplies = List<String>.unmodifiable(widget.replies);
    _expansionController.forward();
  }

  void _onExpansionStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted) return;
    // A new source may have been opened while the previous one was closing.
    // Adopt it only after the old source has completely disappeared.
    if (_wantsOpen) {
      setState(_syncExpansion);
    } else if (widget.replies.isEmpty ||
        widget.identity != _displayedIdentity) {
      setState(() => _displayedReplies = const []);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _expansion.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  List<String> get replies => _displayedReplies;

  @override
  Widget build(BuildContext context) => replies.isEmpty
      ? const SizedBox.shrink()
      : AnimatedBuilder(
          animation: _expansionController,
          child: IgnorePointer(
            ignoring: !_acceptsInput,
            child: ExcludeSemantics(
              excluding: !_acceptsInput,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: LocationChatReplyActions.contentBottomGap,
                ),
                child: _buildReplies(context),
              ),
            ),
          ),
          builder: (context, child) => _expansionController.isDismissed
              ? const SizedBox.shrink()
              : SizeTransition(
                  key: const ValueKey('inspiration-replies-transition'),
                  sizeFactor: _expansion,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
        );

  Widget _buildReplies(BuildContext context) {
    final backgroundColor = chatNarratorMessageBackgroundColor(
      style,
    ).withValues(alpha: style.selfBubbleColor.a);
    final bubbleStyle = style.copyWith(
      bubblePadding: style.bubblePadding.copyWith(right: 8 + _editStripWidth),
      selfBubbleColor: backgroundColor,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth -
              style.avatarSize -
              style.avatarBubbleGap -
              style.avatarSideSpacerWidth,
        );
        final width = math.min(
          availableWidth,
          math.min(
            chatNormalBubbleMaxWidth(context, style),
            maxWidthCap ?? double.infinity,
          ),
        );
        // Match text scaling and padding while giving the horizontal viewport
        // enough height for every suggestion, without clipping long replies.
        final carouselHeight = _heightCache.measure(
          replies: replies,
          textWidth: math.max(1, width - bubbleStyle.bubblePadding.horizontal),
          textStyle: GenesisTypography.resolve(context, style.bubbleTextStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          padding: bubbleStyle.bubblePadding,
        );
        // Expand the paging viewport asymmetrically so the active card keeps
        // the original user-bubble position while its neighbors remain visible.
        final rightInset = style.avatarSize + style.avatarBubbleGap;
        final cardCenter = constraints.maxWidth - rightInset - width / 2;
        final centerOffset = cardCenter - constraints.maxWidth / 2;
        final viewportWidth = constraints.maxWidth + 2 * centerOffset.abs();
        final viewportLeft = math.min(0.0, 2 * centerOffset);
        _configureCarousel(viewportWidth, width);
        return Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                key: const ValueKey('inspiration-replies-carousel'),
                width: constraints.maxWidth,
                height: carouselHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: viewportLeft,
                      top: 0,
                      bottom: 0,
                      width: viewportWidth,
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const ClampingScrollPhysics(),
                        itemCount: replies.length,
                        padEnds: true,
                        onPageChanged: (page) {
                          _currentPage = page;
                          if (_acceptsInput) widget.onPageChanged(page);
                        },
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: SizedBox.expand(
                            key: ValueKey('inspiration-reply-card-$index'),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ChatMessageBubble(
                                  onTap: () => _handleCardTap(index),
                                  border: chatNarratorEditorBorder,
                                  borderRadius: BorderRadius.circular(
                                    style.bubbleBorderRadius,
                                  ),
                                  message: ChatMessageVm(
                                    localId: 'inspiration-$index',
                                    senderId: 'inspiration',
                                    senderName: '',
                                    text: replies[index],
                                    isMe: true,
                                    status: 'sent',
                                  ),
                                  style: bubbleStyle,
                                ),
                                Positioned(
                                  top: 0,
                                  bottom: 0,
                                  right: 0,
                                  width: _editStripWidth,
                                  child: Semantics(
                                    button: true,
                                    label: 'Edit inspiration ${index + 1}',
                                    child: GestureDetector(
                                      key: ValueKey('inspiration-edit-$index'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          _handleCardTap(index, edit: true),
                                      child: Center(
                                        child: SvgPicture.asset(
                                          editSquareIconAsset,
                                          width:
                                              LocationChatReplyActions.iconSize,
                                          height:
                                              LocationChatReplyActions.iconSize,
                                          colorFilter: const ColorFilter.mode(
                                            Color(0xFFF4F3F6),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One layout result belongs to the mounted source, including collapsed lists.
class _InspirationHeightCache {
  List<String>? _replies;
  double? _textWidth;
  TextStyle? _textStyle;
  TextDirection? _textDirection;
  TextScaler? _textScaler;
  EdgeInsets? _padding;
  double _height = 0;

  double measure({
    required List<String> replies,
    required double textWidth,
    required TextStyle textStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required EdgeInsets padding,
  }) {
    if (_textWidth == textWidth &&
        _textStyle == textStyle &&
        _textDirection == textDirection &&
        _textScaler == textScaler &&
        _padding == padding &&
        _sameReplies(replies)) {
      return _height;
    }
    var contentHeight = 0.0;
    for (final reply in replies) {
      final painter = TextPainter(
        text: TextSpan(text: reply, style: textStyle),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout(maxWidth: textWidth);
      assert(() {
        debugLocationChatInspirationTextLayoutCount++;
        return true;
      }());
      contentHeight = math.max(contentHeight, painter.height);
      painter.dispose();
    }
    _replies = List<String>.unmodifiable(replies);
    _textWidth = textWidth;
    _textStyle = textStyle;
    _textDirection = textDirection;
    _textScaler = textScaler;
    _padding = padding;
    return _height = contentHeight + padding.vertical + 2;
  }

  bool _sameReplies(List<String> replies) {
    final previous = _replies;
    if (previous == null || previous.length != replies.length) return false;
    for (var index = 0; index < replies.length; index++) {
      if (previous[index] != replies[index]) return false;
    }
    return true;
  }
}
