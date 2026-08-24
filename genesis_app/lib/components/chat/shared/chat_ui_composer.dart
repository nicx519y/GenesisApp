part of 'chat_ui_library.dart';

enum ChatComposerSendIcon { send, arrowUp }

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.inputEnabled,
    required this.sendEnabled,
    required this.sending,
    required this.onSend,
    this.onHeightChanged,
    this.sendLabel,
    this.hintText,
    this.style,
    this.bottomSafeAreaInset,
    this.focusNode,
    this.onInputTap,
    this.leadingShortcutLabel,
    this.onLeadingShortcutPressed,
    this.sendIcon = ChatComposerSendIcon.arrowUp,
  });

  final TextEditingController controller;
  final bool inputEnabled;
  final bool sendEnabled;
  final bool sending;
  final Future<void> Function() onSend;
  final ValueChanged<double>? onHeightChanged;
  final String? sendLabel;
  final String? hintText;
  final ChatUiStyleConfig? style;
  final double? bottomSafeAreaInset;
  final FocusNode? focusNode;
  final VoidCallback? onInputTap;
  final String? leadingShortcutLabel;
  final VoidCallback? onLeadingShortcutPressed;
  final ChatComposerSendIcon sendIcon;

  @override
  Widget build(BuildContext context) {
    final style = this.style ?? context.genesisChatTheme.standard;
    final submitFromKeyboard = !style.showComposerSendButton;
    final bottomInset =
        bottomSafeAreaInset ?? GenesisSafeAreaInsets.bottom(context);
    return _ChatComposerHeightObserver(
      onHeightChanged: onHeightChanged,
      child: ClipRect(
        child: _ChatComposerBackdropFilter(
          sigma: style.composerBackdropBlurSigma,
          child: Container(
            padding: style.composerPadding.copyWith(
              bottom: style.composerPadding.bottom + bottomInset,
            ),
            decoration: BoxDecoration(
              color: style.composerBackgroundGradient == null
                  ? style.composerBackgroundColor
                  : null,
              gradient: style.composerBackgroundGradient,
            ),
            child: TextFieldTapRegion(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (style.showComposerVoiceButton) ...[
                    _ComposerIconButton(
                      icon: MyFlutterApp.voice,
                      onPressed: inputEnabled ? () {} : null,
                      style: style,
                    ),
                    SizedBox(width: style.composerLeadingGap),
                  ],
                  Expanded(
                    child: Container(
                      key: const ValueKey<String>('chat-composer-input'),
                      constraints: BoxConstraints(
                        minHeight: style.inputMinHeight,
                        maxHeight: style.inputMaxHeight,
                      ),
                      decoration: BoxDecoration(
                        color: style.inputBackgroundColor,
                        borderRadius: BorderRadius.circular(
                          style.inputBorderRadius,
                        ),
                        border: style.inputBorderWidth > 0
                            ? Border.all(
                                color: style.inputBorderColor,
                                width: style.inputBorderWidth,
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          if (leadingShortcutLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _ComposerShortcutButton(
                                label: leadingShortcutLabel!,
                                onPressed: onLeadingShortcutPressed,
                                style: style,
                              ),
                            ),
                          Expanded(
                            child: _ComposerSelectionScope(
                              color: style.composerCursorColor,
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                enabled: inputEnabled,
                                minLines: style.inputMinLines,
                                maxLines: style.inputMaxLines,
                                keyboardType: submitFromKeyboard
                                    ? TextInputType.text
                                    : TextInputType.multiline,
                                textInputAction: submitFromKeyboard
                                    ? TextInputAction.send
                                    : TextInputAction.newline,
                                onTapOutside: (_) => FocusManager
                                    .instance
                                    .primaryFocus
                                    ?.unfocus(),
                                onTap: onInputTap,
                                cursorColor: style.composerCursorColor,
                                onSubmitted: submitFromKeyboard
                                    ? (_) {
                                        if (sendEnabled) unawaited(onSend());
                                      }
                                    : null,
                                style: GenesisTypography.withFallback(
                                  style.inputTextStyle,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: hintText,
                                  contentPadding: EdgeInsets.fromLTRB(
                                    leadingShortcutLabel == null
                                        ? style.inputHorizontalPadding
                                        : 9,
                                    style.inputVerticalPadding,
                                    style.inputHorizontalPadding,
                                    style.inputVerticalPadding,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (style.showComposerStickerButton) ...[
                    SizedBox(width: style.composerActionGap),
                    _ComposerIconButton(
                      icon: MyFlutterApp.sticker,
                      onPressed: inputEnabled ? () {} : null,
                      style: style,
                    ),
                  ],
                  if (style.showComposerAddButton) ...[
                    SizedBox(width: style.composerActionGap),
                    _ComposerIconButton(
                      icon: MyFlutterApp.add2,
                      onPressed: inputEnabled ? () {} : null,
                      style: style,
                    ),
                  ],
                  if (style.showComposerSendButton) ...[
                    SizedBox(width: style.composerActionGap),
                    _ComposerSendButton(
                      sending: sending,
                      onPressed: sendEnabled ? onSend : null,
                      label: sendLabel,
                      icon: sendIcon,
                      style: style,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerShortcutButton extends StatelessWidget {
  const _ComposerShortcutButton({
    required this.label,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    final baseColor = style.inputTextStyle.color ?? style.composerIconColor;
    final iconColor = baseColor.withValues(
      alpha: onPressed == null ? 0.35 : 0.72,
    );
    return SizedBox.square(
      key: const ValueKey<String>('chat-composer-leading-shortcut'),
      dimension: 26,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: iconColor,
          backgroundColor: baseColor.withValues(alpha: 0.13),
          disabledForegroundColor: iconColor,
          disabledBackgroundColor: baseColor.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: label == '*'
            ? CustomPaint(
                size: const Size.square(12),
                painter: _ComposerAsteriskPainter(color: iconColor),
              )
            : Text(label),
      ),
    );
  }
}

class _ComposerAsteriskPainter extends CustomPainter {
  const _ComposerAsteriskPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.13 * scale
      ..strokeCap = StrokeCap.round;

    Offset point(double x, double y) => Offset(x * scale, y * scale);
    canvas
      ..drawLine(point(8, 2.9), point(8, 13.1), paint)
      ..drawLine(point(3.6, 5.4), point(12.4, 10.6), paint)
      ..drawLine(point(3.6, 10.6), point(12.4, 5.4), paint);
  }

  @override
  bool shouldRepaint(covariant _ComposerAsteriskPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ChatComposerBackdropFilter extends StatelessWidget {
  const _ChatComposerBackdropFilter({required this.sigma, required this.child});

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

class _ChatComposerHeightObserver extends StatefulWidget {
  const _ChatComposerHeightObserver({
    required this.child,
    required this.onHeightChanged,
  });

  final Widget child;
  final ValueChanged<double>? onHeightChanged;

  @override
  State<_ChatComposerHeightObserver> createState() =>
      _ChatComposerHeightObserverState();
}

class _ChatComposerHeightObserverState
    extends State<_ChatComposerHeightObserver> {
  double? _lastHeight;

  @override
  void initState() {
    super.initState();
    _scheduleReportHeight();
  }

  @override
  void didUpdateWidget(covariant _ChatComposerHeightObserver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleReportHeight();
  }

  void _scheduleReportHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = context.size?.height;
      if (height == null || height == _lastHeight) return;
      _lastHeight = height;
      widget.onHeightChanged?.call(height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReportHeight();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleReportHeight();
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.onPressed,
    required this.style,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final ChatUiStyleConfig style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: style.composerIconButtonSize,
      height: style.composerIconButtonSize,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: style.composerIconColor,
          size: style.composerIconSize,
        ),
      ),
    );
  }
}

class _ComposerSendButton extends StatelessWidget {
  const _ComposerSendButton({
    required this.sending,
    required this.onPressed,
    required this.style,
    required this.icon,
    this.label,
  });

  final bool sending;
  final VoidCallback? onPressed;
  final ChatUiStyleConfig style;
  final ChatComposerSendIcon icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !sending;
    final background = enabled || sending
        ? style.composerSendButtonColor
        : style.composerSendButtonDisabledColor;
    return SizedBox(
      key: const ValueKey('chat-composer-send-button'),
      width: style.composerSendButtonWidth,
      height: style.composerSendButtonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(
            style.composerSendButtonBorderRadius,
          ),
          border: style.composerSendButtonBorderWidth > 0
              ? Border.all(
                  color: style.composerSendButtonBorderColor,
                  width: style.composerSendButtonBorderWidth,
                )
              : null,
        ),
        child: TextButton(
          style: TextButton.styleFrom(
            fixedSize: Size(
              style.composerSendButtonWidth,
              style.composerSendButtonHeight,
            ),
            minimumSize: Size(
              style.composerSendButtonWidth,
              style.composerSendButtonHeight,
            ),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: style.composerSendButtonIconColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                style.composerSendButtonBorderRadius,
              ),
            ),
          ),
          onPressed: enabled ? onPressed : null,
          child: sending
              ? SizedBox(
                  width: style.composerSendButtonLoadingSize,
                  height: style.composerSendButtonLoadingSize,
                  child: CircularProgressIndicator(
                    strokeWidth: style.composerSendButtonLoadingStrokeWidth,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      style.composerSendButtonIconColor,
                    ),
                  ),
                )
              : label == null
              ? icon == ChatComposerSendIcon.arrowUp
                    ? CustomPaint(
                        size: Size.square(style.composerSendButtonIconSize),
                        painter: _ComposerUpArrowPainter(
                          color: style.composerSendButtonIconColor,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: style.composerSendButtonIconColor,
                        size: style.composerSendButtonIconSize,
                      )
              : Text(
                  genesisDisplaySafeText(label!),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: style.composerSendButtonIconColor,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ComposerUpArrowPainter extends CustomPainter {
  const _ComposerUpArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.51 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset point(double x, double y) => Offset(x * scale, y * scale);
    canvas
      ..drawLine(point(8, 13.2), point(8, 3.2), paint)
      ..drawPath(
        Path()
          ..moveTo(3.9 * scale, 7.3 * scale)
          ..lineTo(8 * scale, 3.2 * scale)
          ..lineTo(12.1 * scale, 7.3 * scale),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant _ComposerUpArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Paints the composer's caret, drag handles and selection highlight in
/// [color]. The app theme puts all three on the accent, which is a stray red
/// mark over scene artwork. A null [color] leaves the theme alone.
class _ComposerSelectionScope extends StatelessWidget {
  const _ComposerSelectionScope({required this.color, required this.child});

  /// Matches the app theme's own accent-to-highlight ratio.
  static const double _selectionOpacity = 0.32;

  final Color? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    if (color == null) return child;
    return TextSelectionTheme(
      data: TextSelectionThemeData(
        cursorColor: color,
        selectionColor: color.withValues(alpha: _selectionOpacity),
        selectionHandleColor: color,
      ),
      child: child,
    );
  }
}
