part of 'chat_ui_library.dart';

/// Shared bubble fill, shape, padding and optional backdrop. Callers own layout
/// and message semantics; a zero sigma preserves flat system/waiting bubbles.
class ChatBubbleSurface extends StatelessWidget {
  const ChatBubbleSurface({
    super.key,
    this.surfaceKey,
    required this.color,
    required this.borderRadius,
    required this.padding,
    required this.child,
    this.margin,
    this.border,
    this.foregroundBorder = false,
    this.blurSigma = 0,
  });

  final Key? surfaceKey;
  final Color color;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;
  final bool foregroundBorder;
  final double blurSigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      key: surfaceKey,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: foregroundBorder ? null : border,
      ),
      foregroundDecoration: foregroundBorder && border != null
          ? BoxDecoration(border: border, borderRadius: borderRadius)
          : null,
      child: child,
    );
    return blurSigma > 0
        ? ChatStableBackdropSurface(
            borderRadius: borderRadius,
            sigma: blurSigma,
            child: surface,
          )
        : surface;
  }
}
