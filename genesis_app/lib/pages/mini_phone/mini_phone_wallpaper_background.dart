import 'package:flutter/material.dart';

/// Keeps the old decoded frame visible until the replacement is ready, then
/// crossfades without fading through a placeholder or changing layout.
class MiniPhoneWallpaperBackground extends StatefulWidget {
  const MiniPhoneWallpaperBackground({super.key, required this.image});
  final ImageProvider image;

  @override
  State<MiniPhoneWallpaperBackground> createState() =>
      _MiniPhoneWallpaperBackgroundState();
}

class _MiniPhoneWallpaperBackgroundState
    extends State<MiniPhoneWallpaperBackground> {
  ImageProvider? _visible;
  ImageProvider? _requested;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepare();
  }

  @override
  void didUpdateWidget(MiniPhoneWallpaperBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepare();
  }

  Future<void> _prepare() async {
    // Home stays mounted under app pages with its tickers disabled. Defer
    // replacements until Home is visible so the fade cannot elapse offstage.
    if (_visible != null && !TickerMode.valuesOf(context).enabled) return;
    final image = widget.image;
    if (_requested == image) return;
    _requested = image;
    final generation = ++_generation;
    var failed = false;
    await precacheImage(image, context, onError: (_, _) => failed = true);
    if (!mounted || generation != _generation) return;
    if (failed) {
      _requested = null;
      return;
    }
    if (_visible != null && !TickerMode.valuesOf(context).enabled) {
      _requested = null;
      return;
    }
    setState(() {
      _visible = image;
    });
  }

  @override
  Widget build(BuildContext context) => _visible == null
      ? const SizedBox.expand()
      : AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: Image(
            key: ValueKey(_visible),
            image: _visible!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
}
