part of 'chat_ui_library.dart';

enum ChatHeaderBackButtonVariant { standard, compactGlass }

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.connecting,
    required this.onBack,
    this.titleSuffix,
    this.titleSuffixStyle,
    this.showTitleIcon = true,
    this.showSubtitle = true,
    this.showSubtitleIcon = true,
    this.showMoreButton = true,
    this.alignContentLeft = false,
    this.subtitleIconAsset,
    this.trailing,
    this.style,
    this.backButtonVariant = ChatHeaderBackButtonVariant.standard,
  });

  final String title;
  final String subtitle;
  final bool connected;
  final bool connecting;
  final VoidCallback onBack;
  final String? titleSuffix;
  final TextStyle? titleSuffixStyle;
  final bool showTitleIcon;
  final bool showSubtitle;
  final bool showSubtitleIcon;
  final bool showMoreButton;
  final bool alignContentLeft;
  final String? subtitleIconAsset;
  final Widget? trailing;
  final ChatUiStyleConfig? style;
  final ChatHeaderBackButtonVariant backButtonVariant;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? context.genesisChatTheme.standard;
    final topInset = GenesisSafeAreaInsets.top(context);
    final compactBackButton =
        backButtonVariant == ChatHeaderBackButtonVariant.compactGlass;
    final leadingContentInset = compactBackButton
        ? 56.0
        : style.headerTrailingPlaceholderWidth;
    final headerSidePadding = trailing == null
        ? style.headerTrailingPlaceholderWidth
        : _chatHeaderTrailingWidth;
    final titleText = _ChatHeaderTitleText(
      title: title,
      suffix: titleSuffix,
      style: style.headerTitleTextStyle,
      suffixStyle: titleSuffixStyle,
    );
    final textColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: alignContentLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Padding(
          padding: alignContentLeft
              ? EdgeInsets.zero
              : EdgeInsets.symmetric(horizontal: headerSidePadding),
          child: Row(
            mainAxisAlignment: alignContentLeft
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            mainAxisSize: alignContentLeft
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              if (showTitleIcon) ...[
                Icon(
                  Icons.place_outlined,
                  size: style.headerTitleIconSize,
                  color: style.headerTitleIconColor,
                ),
                SizedBox(width: style.headerTitleIconGap),
              ],
              if (alignContentLeft)
                Expanded(child: titleText)
              else
                Flexible(child: titleText),
            ],
          ),
        ),
        if (showSubtitle) ...[
          SizedBox(height: style.headerSubtitleTopGap),
          Padding(
            padding: alignContentLeft
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: alignContentLeft
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (showSubtitleIcon) ...[
                  if (subtitleIconAsset != null)
                    _ChatHeaderSubtitleAssetIcon(
                      asset: subtitleIconAsset!,
                      style: style,
                    )
                  else if (connected)
                    _ChatHeaderSubtitleAssetIcon(
                      asset: characterStatIconAsset,
                      style: style,
                    )
                  else
                    Icon(
                      connecting ? Icons.sync : Icons.cloud_off,
                      size: style.headerStatusIconSize,
                      color: style.headerStatusIconColor,
                    ),
                  SizedBox(width: style.headerStatusIconGap),
                ],
                Flexible(
                  child: Text(
                    genesisDisplaySafeText(subtitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: alignContentLeft
                        ? TextAlign.left
                        : TextAlign.center,
                    style: style.headerSubtitleTextStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
    return ClipRect(
      child: _ChatHeaderBackdropFilter(
        sigma: style.headerBackdropBlurSigma,
        child: Container(
          height: topInset + style.headerHeight,
          padding: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: style.headerBackgroundGradient == null
                ? style.headerBackgroundColor
                : null,
            gradient: style.headerBackgroundGradient,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: compactBackButton
                      ? Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _CompactChatHeaderBackButton(
                            onPressed: onBack,
                            color:
                                style.headerTitleTextStyle.color ??
                                style.headerTitleIconColor,
                          ),
                        )
                      : IconButton(
                          onPressed: onBack,
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            size: style.headerBackIconSize,
                            color: style.headerTitleTextStyle.color,
                          ),
                        ),
                ),
                Positioned(
                  left: alignContentLeft ? leadingContentInset : 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: alignContentLeft
                      ? Row(
                          children: [
                            Expanded(child: textColumn),
                            if (trailing != null) ...[
                              const SizedBox(width: 10),
                              trailing!,
                            ] else
                              SizedBox(
                                width: style.headerTrailingPlaceholderWidth,
                              ),
                          ],
                        )
                      : textColumn,
                ),
                if (trailing != null && !alignContentLeft)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: headerSidePadding,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailing,
                      ),
                    ),
                  )
                else if (showMoreButton)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {},
                      icon: Icon(
                        Icons.more_horiz,
                        size: style.headerMoreIconSize,
                        color: style.headerTitleTextStyle.color,
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: style.headerTrailingPlaceholderWidth,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatHeaderTitleText extends StatelessWidget {
  const _ChatHeaderTitleText({
    required this.title,
    required this.style,
    this.suffix,
    this.suffixStyle,
  });

  final String title;
  final String? suffix;
  final TextStyle style;
  final TextStyle? suffixStyle;

  @override
  Widget build(BuildContext context) {
    final visibleSuffix = suffix?.trim() ?? '';
    final visibleTitle = genesisDisplaySafeText(title);
    return Semantics(
      label: visibleSuffix.isEmpty
          ? visibleTitle
          : '$visibleTitle $visibleSuffix',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              visibleTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (visibleSuffix.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              genesisDisplaySafeText(visibleSuffix),
              maxLines: 1,
              style: suffixStyle ?? style,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactChatHeaderBackButton extends StatelessWidget {
  const _CompactChatHeaderBackButton({
    required this.onPressed,
    required this.color,
  });

  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey<String>('chat-header-compact-back-button'),
      dimension: 30,
      child: IconButton(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(30),
          minimumSize: const Size.square(30),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: color.withValues(alpha: 0.13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: onPressed,
        icon: CustomPaint(
          size: const Size.square(14),
          painter: _ChatHeaderBackChevronPainter(color: color),
        ),
      ),
    );
  }
}

class _ChatHeaderBackChevronPainter extends CustomPainter {
  const _ChatHeaderBackChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(10 * scale, 2.8 * scale)
      ..lineTo(4.6 * scale, 8 * scale)
      ..lineTo(10 * scale, 13.2 * scale);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChatHeaderBackChevronPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ChatHeaderBackdropFilter extends StatelessWidget {
  const _ChatHeaderBackdropFilter({required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sigma <= 0) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

class _ChatHeaderSubtitleAssetIcon extends StatelessWidget {
  const _ChatHeaderSubtitleAssetIcon({
    required this.asset,
    required this.style,
  });

  final String asset;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(
        0,
        customCharacterIconVerticalOffset(style.headerStatusIconSize),
      ),
      child: SvgPicture.asset(
        asset,
        width: customCharacterIconRenderSize(style.headerStatusIconSize),
        height: customCharacterIconRenderSize(style.headerStatusIconSize),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}
