import 'dart:async';

import 'package:flutter/material.dart';

import '../network/models/world.dart';
import 'common/genesis_modal_routes.dart';

const Duration kWorldTick1WaitPollInterval = Duration(seconds: 2);
const Duration kWorldTick1WaitDotsInterval = Duration(milliseconds: 400);

bool worldHasTick1(WorldDetail? world) {
  return (world?.tickCount ?? 0) >= 1;
}

Future<WorldDetail?> showWorldTick1WaitDialog({
  required BuildContext context,
  required Future<WorldDetail> Function() loadWorld,
}) async {
  WorldDetail? readyWorld;
  await showGenesisDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => WorldTick1WaitDialog(
      loadWorld: loadWorld,
      onWorldReady: (world) => readyWorld = world,
    ),
  );
  return readyWorld;
}

class WorldTick1WaitDialog extends StatefulWidget {
  const WorldTick1WaitDialog({
    super.key,
    required this.loadWorld,
    required this.onWorldReady,
  });

  final Future<WorldDetail> Function() loadWorld;
  final ValueChanged<WorldDetail> onWorldReady;

  @override
  State<WorldTick1WaitDialog> createState() => _WorldTick1WaitDialogState();
}

class _WorldTick1WaitDialogState extends State<WorldTick1WaitDialog> {
  Timer? _pollTimer;
  Timer? _dotsTimer;
  bool _loading = true;
  bool _hasError = false;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _dotsTimer = Timer.periodic(kWorldTick1WaitDotsInterval, (_) {
      if (!mounted || _hasError) return;
      setState(() => _dotCount = _dotCount == 6 ? 1 : _dotCount + 1);
    });
    unawaited(_poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dotsTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    _pollTimer?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _hasError = false;
      });
    }
    try {
      final world = await widget.loadWorld();
      if (!mounted) return;
      if (worldHasTick1(world)) {
        widget.onWorldReady(world);
        Navigator.of(context).pop();
        return;
      }
      setState(() => _loading = false);
      _pollTimer = Timer(kWorldTick1WaitPollInterval, () => unawaited(_poll()));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('world-tick1-wait-dialog'),
      title: const Text(
        'Generating first tick',
        style: TextStyle(fontSize: 16, height: 1.2),
      ),
      content: SizedBox(
        width: 260,
        child: Text(
          _hasError
              ? 'Generation status could not be loaded.'
              : 'LLM is generating your first tick. This may take a moment${List.filled(_dotCount, '.').join()}',
          style: const TextStyle(fontSize: 14, height: 1.35),
        ),
      ),
      actions: _hasError
          ? [
              TextButton(
                key: const ValueKey('world-tick1-wait-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('world-tick1-wait-retry'),
                onPressed: _loading ? null : () => unawaited(_poll()),
                child: const Text('Retry'),
              ),
            ]
          : null,
    );
  }
}
