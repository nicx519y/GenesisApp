import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final debugScreenTranslationService = DebugScreenTranslationService();

class DebugScreenTranslationLine {
  const DebugScreenTranslationLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  factory DebugScreenTranslationLine.fromMap(Map<Object?, Object?> map) {
    double number(String key) => (map[key] as num?)?.toDouble() ?? 0;

    return DebugScreenTranslationLine(
      text: map['text'] as String? ?? '',
      left: number('left'),
      top: number('top'),
      right: number('right'),
      bottom: number('bottom'),
    );
  }

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
}

class DebugScreenTranslationService {
  DebugScreenTranslationService({
    MethodChannel channel = const MethodChannel(
      'com.worldo.ai/debug_screen_translation',
    ),
  }) : _channel = channel;

  final MethodChannel _channel;
  Future<void>? _preparing;

  bool get isSupported =>
      kDebugMode && defaultTargetPlatform == TargetPlatform.android;

  Future<void> prepare() {
    if (!isSupported) {
      return Future<void>.error(
        UnsupportedError(
          'Screen translation is only available in Android debug builds.',
        ),
      );
    }
    return _preparing ??= _channel
        .invokeMethod<void>('prepare')
        .whenComplete(() => _preparing = null);
  }

  Future<List<DebugScreenTranslationLine>> translateScreen(
    Uint8List pngBytes,
  ) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Screen translation is only available in Android debug builds.',
      );
    }
    final rawLines = await _channel.invokeListMethod<Object?>(
      'translateScreen',
      <String, Object?>{'pngBytes': pngBytes},
    );
    if (rawLines == null) return const <DebugScreenTranslationLine>[];
    return rawLines
        .whereType<Map<Object?, Object?>>()
        .map(DebugScreenTranslationLine.fromMap)
        .where((line) => line.text.trim().isNotEmpty)
        .toList(growable: false);
  }
}
