import 'package:flutter/services.dart';

enum GenesisKeyboardAnimationDirection { opening, closing, changing }

class GenesisKeyboardAnimationTarget {
  const GenesisKeyboardAnimationTarget({
    required this.generation,
    required this.direction,
    required this.startInset,
    required this.endInset,
    required this.duration,
  });

  final int generation;
  final GenesisKeyboardAnimationDirection direction;
  final double startInset;
  final double endInset;
  final Duration duration;

  static GenesisKeyboardAnimationTarget? tryParse(Object? value) {
    if (value is! Map) return null;
    final phase = value['phase']?.toString();
    final direction = switch (phase) {
      'opening' => GenesisKeyboardAnimationDirection.opening,
      'closing' => GenesisKeyboardAnimationDirection.closing,
      'changing' => GenesisKeyboardAnimationDirection.changing,
      _ => null,
    };
    if (direction == null) return null;
    final generation = (value['generation'] as num?)?.toInt();
    final startInset = (value['startInset'] as num?)?.toDouble();
    final endInset = (value['endInset'] as num?)?.toDouble();
    final durationMillis = (value['durationMillis'] as num?)?.toDouble();
    if (generation == null ||
        startInset == null ||
        endInset == null ||
        durationMillis == null ||
        !startInset.isFinite ||
        !endInset.isFinite ||
        !durationMillis.isFinite) {
      return null;
    }
    return GenesisKeyboardAnimationTarget(
      generation: generation,
      direction: direction,
      startInset: startInset.clamp(0.0, double.infinity).toDouble(),
      endInset: endInset.clamp(0.0, double.infinity).toDouble(),
      duration: Duration(
        microseconds: (durationMillis.clamp(0.0, double.infinity) * 1000)
            .round(),
      ),
    );
  }
}

class GenesisKeyboardAnimationEvents {
  const GenesisKeyboardAnimationEvents._();

  static const channelName = 'com.worldo.ai/keyboard_animation';
  static const EventChannel _channel = EventChannel(channelName);

  static final Stream<GenesisKeyboardAnimationTarget> _targets = _channel
      .receiveBroadcastStream()
      .map(GenesisKeyboardAnimationTarget.tryParse)
      .where((event) => event != null)
      .cast<GenesisKeyboardAnimationTarget>();

  static Stream<GenesisKeyboardAnimationTarget> get targets => _targets;
}
