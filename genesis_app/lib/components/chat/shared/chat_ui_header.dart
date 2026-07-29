part of 'chat_ui_library.dart';

class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.connected,
    required this.connecting,
    required this.onBack,
    this.showTitleIcon = true,
    this.showSubtitle = true,
    this.showMoreButton = true,
    this.alignContentLeft = false,
    this.subtitleIconAsset,
    this.trailing,
    this.style,
  });

  final String title;
  final String subtitle;
  final bool connected;
  final bool connecting;
  final VoidCallback onBack;
  final bool showTitleIcon;
  final bool showSubtitle;
  final bool showMoreButton;
  final bool alignContentLeft;
  final String? subtitleIconAsset;
  final Widget? trailing;
  final ChatUiStyleConfig? style;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? ChatUiStyleConfig.standard;
    final topInset = GenesisSafeAreaInsets.top(context);
    final headerSidePadding = trailing == null
        ? style.headerTrailingPlaceholderWidth
        : _chatHeaderTrailingWidth;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: style.headerBackdropBlurSigma,
          sigmaY: style.headerBackdropBlurSigma,
        ),
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
                  child: IconButton(
                    onPressed: onBack,
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      size: style.headerBackIconSize,
                      color: style.headerTitleTextStyle.color,
                    ),
                  ),
                ),
                Positioned(
                  left: alignContentLeft
                      ? style.headerTrailingPlaceholderWidth
                      : 0,
                  right: alignContentLeft ? headerSidePadding : 0,
                  top: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: alignContentLeft
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: alignContentLeft
                            ? EdgeInsets.zero
                            : EdgeInsets.symmetric(
                                horizontal: headerSidePadding,
                              ),
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
                            Flexible(
                              child: Text(
                                genesisDisplaySafeText(title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style.headerTitleTextStyle,
                              ),
                            ),
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
                  ),
                ),
                if (trailing != null)
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
