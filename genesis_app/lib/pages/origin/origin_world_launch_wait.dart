part of 'origin_world_page.dart';

class _OriginPendingLaunchWaitOverlay extends StatefulWidget {
  const _OriginPendingLaunchWaitOverlay({required this.onBackPressed});

  final VoidCallback onBackPressed;

  @override
  State<_OriginPendingLaunchWaitOverlay> createState() =>
      _OriginPendingLaunchWaitOverlayState();
}

class _OriginPendingLaunchWaitOverlayState
    extends State<_OriginPendingLaunchWaitOverlay> {
  Timer? _dotsTimer;
  int _dotCount = 1;
  bool _allowRoutePop = false;

  @override
  void initState() {
    super.initState();
    _dotsTimer = Timer.periodic(kWorldTick1WaitDotsInterval, (_) {
      if (!mounted) return;
      setState(() => _dotCount = _dotCount == 6 ? 1 : _dotCount + 1);
    });
  }

  @override
  void dispose() {
    _dotsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackRequest();
      },
      child: GenesisEdgeSwipeBack(
        onBack: _handleBackRequest,
        child: ColoredBox(
          color: const Color(0x8A000000),
          child: Center(
            child: AlertDialog(
              key: const ValueKey('world-tick1-wait-dialog'),
              backgroundColor: const Color(0xFFFFFFFF),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              title: Text(
                'AI is generating${List.filled(_dotCount, '.').join()}',
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: 260,
                child: const Text(
                  'Generate  a live and customized world for you.\n'
                  'Please wait for a moment.',
                  style: TextStyle(fontSize: 14, height: 1.35),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackRequest() {
    if (!_allowRoutePop && mounted) {
      setState(() => _allowRoutePop = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onBackPressed();
      });
    });
  }
}
