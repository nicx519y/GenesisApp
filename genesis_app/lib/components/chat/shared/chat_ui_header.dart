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
    this.titleSuffixSemanticsLabel,
    this.titleSuffixStyle,
    this.titleOverline,
    this.titleOverlineStyle,
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

  /// Either a [String] rendered with [titleSuffixStyle], or a [Widget] that is
  /// placed after the title as-is (used for the location-chat occupant pill).
  final Object? titleSuffix;

  /// Spoken text for a [Widget] [titleSuffix]; ignored for the [String] path,
  /// which reads out the suffix itself.
  final String? titleSuffixSemanticsLabel;
  final TextStyle? titleSuffixStyle;

  /// Small line above the title - the parent location in the room header,
  /// rendered with a trailing chevron. Hidden when blank.
  final String? titleOverline;
  final TextStyle? titleOverlineStyle;
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
      suffixSemanticsLabel: titleSuffixSemanticsLabel,
      style: style.headerTitleTextStyle,
      suffixStyle: titleSuffixStyle,
    );
    final overline = titleOverline?.trim() ?? '';
    final overlineStyle =
        titleOverlineStyle ??
        style.headerTitleTextStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          height: 1,
          color: (style.headerTitleTextStyle.color ?? const Color(0xFFFFFFFF))
              .withValues(alpha: 0.45),
        );
    final textColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: alignContentLeft
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (overline.isNotEmpty) ...[
          Padding(
            padding: alignContentLeft
                ? EdgeInsets.zero
                : EdgeInsets.symmetric(horizontal: headerSidePadding),
            child: Row(
              mainAxisAlignment: alignContentLeft
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    overline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: overlineStyle,
                  ),
                ),
                const SizedBox(width: 4),
                Opacity(
                  opacity: 0.5,
                  child: GenesisChevronRightIcon(
                    color: overlineStyle.color ?? style.headerTitleIconColor,
                    size: 7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
        ],
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
                      : GenesisBackButton(
                          onPressed: onBack,
                          foregroundColor:
                              style.headerTitleTextStyle.color ??
                              style.headerTitleIconColor,
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
                      icon: GenesisMoreIcon(
                        size: style.headerMoreIconSize,
                        color:
                            style.headerTitleTextStyle.color ??
                            style.headerTitleIconColor,
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
    this.suffixSemanticsLabel,
    this.suffixStyle,
  });

  final String title;
  final Object? suffix;
  final String? suffixSemanticsLabel;
  final TextStyle style;
  final TextStyle? suffixStyle;

  @override
  Widget build(BuildContext context) {
    final suffix = this.suffix;
    final suffixWidget = suffix is Widget ? suffix : null;
    final visibleSuffix = suffix is String ? suffix.trim() : '';
    final spokenSuffix = suffixWidget != null
        ? (suffixSemanticsLabel?.trim() ?? '')
        : visibleSuffix;
    final visibleTitle = genesisDisplaySafeText(title);
    return Semantics(
      label: spokenSuffix.isEmpty
          ? visibleTitle
          : '$visibleTitle $spokenSuffix',
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
          if (suffixWidget != null) ...[
            const SizedBox(width: 4),
            suffixWidget,
          ] else if (visibleSuffix.isNotEmpty) ...[
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
    // 1r/1s/1t/1u: the glass back tile is 30x30 / radius 10 on white 13%.
    // The 34 / 11 / white 10% defaults stay in place for the standard variant.
    return GenesisBackButton(
      key: const ValueKey<String>('chat-header-compact-back-button'),
      onPressed: onPressed,
      foregroundColor: color,
      dimension: 30,
      borderRadius: 10,
      backgroundColor: context.genesisColors.foregroundStrong.withValues(
        alpha: 0.13,
      ),
    );
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
