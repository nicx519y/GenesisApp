import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/genesis_localizations.dart';
import '../../ui/tokens/genesis_colors.dart';

/// Anchored at response receipt; rebuilding cannot restart the countdown.
/// Uses elapsed time rather than the device's editable wall clock.
class GemDailyResetClock {
  GemDailyResetClock(this.seconds, {Duration Function()? elapsed}) {
    final watch = Stopwatch()..start();
    _elapsed = elapsed ?? (() => watch.elapsed);
  }
  final int seconds;
  late final Duration Function() _elapsed;
  int get remaining => (seconds - _elapsed().inSeconds).clamp(0, seconds);
}

class GemDailyResetCountdown extends StatefulWidget {
  const GemDailyResetCountdown({
    super.key,
    required this.clock,
    required this.onExpired,
  });
  final GemDailyResetClock clock;
  final VoidCallback onExpired;
  @override
  State<GemDailyResetCountdown> createState() => _GemDailyResetCountdownState();
}

class _GemDailyResetCountdownState extends State<GemDailyResetCountdown>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _expired = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didUpdateWidget(GemDailyResetCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock) {
      _expired = false;
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tick();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (widget.clock.remaining == 0) {
      _timer?.cancel();
      if (!_expired) {
        _expired = true;
        widget.onExpired();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.clock.remaining;
    String pad(int value) => value.toString().padLeft(2, '0');
    final time =
        '${pad(remaining ~/ 3600)}:${pad(remaining ~/ 60 % 60)}:${pad(remaining % 60)}';
    return Text(
      context.l10n.gemsDailyResetsIn(time: time),
      style: const TextStyle(
        fontSize: 12,
        height: 14 / 12,
        fontWeight: FontWeight.w400,
        color: GenesisColors.darkTextTertiary,
      ),
    );
  }
}
