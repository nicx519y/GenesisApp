import '../../l10n/genesis_l10n.dart';
import 'package:flutter/material.dart';

import '../../ui/components/genesis_dark_close_button.dart';
import '../../ui/tokens/genesis_colors.dart';
import '../../ui/tokens/genesis_radii.dart';

class GenesisBottomSheetCloseButton extends StatelessWidget {
  const GenesisBottomSheetCloseButton({
    super.key,
    required this.onPressed,
    this.buttonKey,
  });

  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return GenesisDarkCloseButton(key: buttonKey, onPressed: onPressed);
    }
    return SizedBox.square(
      key: buttonKey,
      dimension: 24,
      child: IconButton(
        tooltip: GenesisL10n.current.commonClose,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        style: IconButton.styleFrom(
          minimumSize: const Size.square(24),
          maximumSize: const Size.square(24),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: const Icon(Icons.close, size: 24, color: Color(0xFF111111)),
      ),
    );
  }
}

/// Owns the outer horizontal inset of an interaction/submission sheet body.
/// Inner cards and controls keep their independent internal spacing.
class GenesisActionSheetBody extends StatelessWidget {
  const GenesisActionSheetBody({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = 0,
  });

  static const double horizontalInset = 16;
  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(horizontalInset, top, horizontalInset, bottom),
    child: child,
  );
}

/// Header for user-facing interaction and submission sheets.
/// Its height includes all spacing before the body, independent of actions.
class GenesisActionSheetHeader extends StatelessWidget {
  const GenesisActionSheetHeader({
    super.key,
    required this.title,
    this.titleKey,
    this.titleWidget,
    this.leading,
    this.trailing,
    this.showClose = false,
    this.onClose,
    this.closeButtonKey,
  }) : tabs = null;

  /// Purchase tabs retain their own typography and centered alignment.
  const GenesisActionSheetHeader.tabs({
    super.key,
    required Widget this.tabs,
    this.trailing,
    this.showClose = false,
    this.onClose,
    this.closeButtonKey,
  }) : title = '',
       titleKey = null,
       titleWidget = null,
       leading = null;

  static const double height = 68;
  static const double inset = GenesisActionSheetBody.horizontalInset;
  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: GenesisColors.darkTextPrimary,
  );

  final String title;
  final Key? titleKey;

  /// Replaces [title] when the title brings its own styling, such as a
  /// gradient wordmark that the plain [titleStyle] cannot express.
  final Widget? titleWidget;
  final Widget? leading;
  final Widget? trailing;
  final Widget? tabs;
  final bool showClose;
  final VoidCallback? onClose;
  final Key? closeButtonKey;

  @override
  Widget build(BuildContext context) {
    final action =
        trailing ??
        (showClose
            ? GenesisDarkCloseButton(key: closeButtonKey, onPressed: onClose)
            : null);
    if (tabs != null) {
      return SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              // TabBar reserves 2 px below the label for its indicator.
              padding: const EdgeInsets.fromLTRB(56, 2, 56, 0),
              child: SizedBox(height: 50, child: Center(child: tabs)),
            ),
            if (action != null) Positioned(right: inset, child: action),
          ],
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: inset),
        child: Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.hardEdge,
          children: [
            Padding(
              padding: EdgeInsets.only(right: action == null ? 0 : 64),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    SizedBox(
                      width: 28,
                      height: 24,
                      child: Center(child: leading),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child:
                        titleWidget ??
                        Text(
                          title,
                          key: titleKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: titleStyle,
                        ),
                  ),
                ],
              ),
            ),
            if (action != null) Positioned(right: 0, child: action),
          ],
        ),
      ),
    );
  }
}

class GenesisBottomSheetPanel extends StatelessWidget {
  const GenesisBottomSheetPanel({
    super.key,
    required this.title,
    required this.height,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 14),
    this.titleBottomSpacing = 20,
    this.titleTextStyle,
    this.backgroundColor,
    this.titleWidget,
    this.maintainBottomViewPadding = false,
    this.showHeader = true,
    this.header,
    this.insetBody = true,
    this.shrinkWrap = false,
  });

  static const BorderRadius borderRadius = GenesisRadii.sheet;

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF111111),
  );

  final String title;
  final double height;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  final double titleBottomSpacing;
  final TextStyle? titleTextStyle;
  final Color? backgroundColor;
  final Widget? titleWidget;
  final bool maintainBottomViewPadding;
  final bool showHeader;
  final Widget? header;

  /// Tab/step shells apply GenesisActionSheetBody inside each page instead.
  final bool insetBody;

  /// Treats [height] as a maximum so scrollable content can size the panel.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final actionHeader = showHeader
        ? header ??
              (dark && titleWidget == null
                  ? GenesisActionSheetHeader(title: title, trailing: trailing)
                  : null)
        : null;
    final mainAxisSize = shrinkWrap ? MainAxisSize.min : MainAxisSize.max;
    final bodyFit = shrinkWrap ? FlexFit.loose : FlexFit.tight;
    return Material(
      color:
          backgroundColor ??
          (dark ? GenesisColors.darkRaisedBackground : Colors.white),
      borderRadius: borderRadius,
      child: SafeArea(
        top: false,
        maintainBottomViewPadding: maintainBottomViewPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: double.infinity,
            minHeight: shrinkWrap ? 0 : height,
            maxHeight: height,
          ),
          child: actionHeader != null
              ? Column(
                  mainAxisSize: mainAxisSize,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    actionHeader,
                    Flexible(
                      fit: bodyFit,
                      child: insetBody
                          ? GenesisActionSheetBody(
                              bottom: padding.bottom,
                              child: child,
                            )
                          : Padding(
                              padding: EdgeInsets.only(bottom: padding.bottom),
                              child: child,
                            ),
                    ),
                  ],
                )
              : Padding(
                  padding: padding,
                  child: Column(
                    mainAxisSize: mainAxisSize,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader) ...[
                        Row(
                          children: [
                            Expanded(
                              child:
                                  titleWidget ??
                                  Text(
                                    title,
                                    style:
                                        titleTextStyle ??
                                        (dark
                                            ? titleStyle.copyWith(
                                                color: GenesisColors
                                                    .darkTextPrimary,
                                              )
                                            : titleStyle),
                                  ),
                            ),
                            if (trailing != null) trailing!,
                          ],
                        ),
                        SizedBox(height: titleBottomSpacing),
                      ],
                      Flexible(fit: bodyFit, child: child),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
