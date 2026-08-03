part of 'tilemap_library.dart';

class _TilemapSettingsSlider extends StatelessWidget {
  const _TilemapSettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.sliderKey,
    required this.foregroundColor,
    required this.secondaryColor,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final Key sliderKey;
  final Color foregroundColor;
  final Color secondaryColor;
  final ValueChanged<double> onChanged;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 31,
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: TextStyle(color: secondaryColor, fontSize: 11),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                key: sliderKey,
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 45,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TilemapSettingsSwitch extends StatelessWidget {
  const _TilemapSettingsSwitch({
    required this.label,
    required this.value,
    required this.switchKey,
    required this.foregroundColor,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Key switchKey;
  final Color foregroundColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Switch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }
}

class _TilemapLoadResult {
  const _TilemapLoadResult.success(this.config) : error = null;

  const _TilemapLoadResult.failure(this.error) : config = null;

  final TilemapConfig? config;
  final Object? error;
}

class _TilemapError extends StatelessWidget {
  const _TilemapError({required this.visualMode, required this.onRetry});

  final TilemapVisualMode visualMode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final visualStyle = tilemapVisualStyleFor(visualMode);
    final textColor = visualMode == TilemapVisualMode.dark
        ? Colors.white
        : Colors.black;
    return Stack(
      key: const ValueKey<String>('tilemap-error'),
      fit: StackFit.expand,
      children: [
        ColoredBox(color: visualStyle.backgroundColor),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Map failed to load', style: TextStyle(color: textColor)),
              const SizedBox(height: 10),
              FilledButton(
                key: const ValueKey<String>('tilemap-retry'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
