part of 'tilemap_library.dart';

class _LocationImageFlowGradientEditor extends StatefulWidget {
  const _LocationImageFlowGradientEditor({
    required this.points,
    required this.foregroundColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  final List<TilemapLocationImageFlowGradientPoint> points;
  final Color foregroundColor;
  final Color secondaryColor;
  final ValueChanged<List<TilemapLocationImageFlowGradientPoint>> onChanged;

  @override
  State<_LocationImageFlowGradientEditor> createState() =>
      _LocationImageFlowGradientEditorState();
}

class _LocationImageFlowGradientEditorState
    extends State<_LocationImageFlowGradientEditor> {
  int _selectedIndex = 2;

  Rect _gradientRect(Size size) {
    return Rect.fromLTWH(12, 10, math.max(1, size.width - 24), 22);
  }

  int _closestPointIndex(double localX, Rect gradientRect) {
    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < widget.points.length; index += 1) {
      final x =
          gradientRect.left +
          gradientRect.width * widget.points[index].position;
      final distance = (x - localX).abs();
      if (distance >= closestDistance) continue;
      closestIndex = index;
      closestDistance = distance;
    }
    return closestIndex;
  }

  void _selectPoint(Offset localPosition, Size size) {
    if (widget.points.isEmpty) return;
    final index = _closestPointIndex(localPosition.dx, _gradientRect(size));
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
  }

  void _dragPoint(Offset localPosition, Size size) {
    if (widget.points.isEmpty) return;
    final index = _selectedIndex.clamp(0, widget.points.length - 1);
    final gradientRect = _gradientRect(size);
    final rawPosition =
        ((localPosition.dx - gradientRect.left) / gradientRect.width).clamp(
          0.0,
          1.0,
        );
    final minPosition = index == 0
        ? 0.0
        : widget.points[index - 1].position + 0.01;
    final maxPosition = index == widget.points.length - 1
        ? 1.0
        : widget.points[index + 1].position - 0.01;
    final updated = widget.points.toList(growable: false);
    updated[index] = updated[index].copyWith(
      position: rawPosition.clamp(minPosition, maxPosition).toDouble(),
    );
    widget.onChanged(updated);
  }

  void _updateSelectedColor({
    double? hue,
    double? saturation,
    double? lightness,
  }) {
    if (widget.points.isEmpty) return;
    final index = _selectedIndex.clamp(0, widget.points.length - 1);
    final point = widget.points[index];
    final hsl = HSLColor.fromColor(point.color);
    final updatedColor = HSLColor.fromAHSL(
      point.color.a,
      hue ?? hsl.hue,
      saturation ?? hsl.saturation,
      lightness ?? hsl.lightness,
    ).toColor();
    final updated = widget.points.toList(growable: false);
    updated[index] = point.copyWith(color: updatedColor);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return const SizedBox.shrink();
    final selectedIndex = _selectedIndex.clamp(0, widget.points.length - 1);
    final selectedPoint = widget.points[selectedIndex];
    final selectedHsl = HSLColor.fromColor(selectedPoint.color);
    return Column(
      key: const ValueKey<String>('tilemap-settings-location-flow-gradient'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 62,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                key: const ValueKey<String>(
                  'tilemap-settings-location-flow-gradient-curve',
                ),
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _selectPoint(details.localPosition, size);
                },
                onHorizontalDragStart: (details) {
                  _selectPoint(details.localPosition, size);
                  _dragPoint(details.localPosition, size);
                },
                onHorizontalDragUpdate: (details) {
                  _dragPoint(details.localPosition, size);
                },
                child: CustomPaint(
                  painter: _LocationImageFlowGradientPainter(
                    points: widget.points,
                    selectedIndex: selectedIndex,
                    gradientRect: _gradientRect(size),
                    foregroundColor: widget.foregroundColor,
                    secondaryColor: widget.secondaryColor,
                  ),
                ),
              );
            },
          ),
        ),
        _TilemapSettingsSlider(
          label: 'Hue',
          value: selectedHsl.hue,
          min: 0,
          max: 360,
          valueLabel: '${selectedHsl.hue.round()}°',
          sliderKey: const ValueKey<String>(
            'tilemap-settings-location-flow-hue',
          ),
          foregroundColor: widget.foregroundColor,
          secondaryColor: widget.secondaryColor,
          onChanged: (value) => _updateSelectedColor(hue: value),
        ),
        _TilemapSettingsSlider(
          label: 'Saturation',
          value: selectedHsl.saturation,
          min: 0,
          max: 1,
          valueLabel: '${(selectedHsl.saturation * 100).round()}%',
          sliderKey: const ValueKey<String>(
            'tilemap-settings-location-flow-saturation',
          ),
          foregroundColor: widget.foregroundColor,
          secondaryColor: widget.secondaryColor,
          onChanged: (value) => _updateSelectedColor(saturation: value),
        ),
        _TilemapSettingsSlider(
          label: 'Lightness',
          value: selectedHsl.lightness,
          min: 0,
          max: 1,
          valueLabel: '${(selectedHsl.lightness * 100).round()}%',
          sliderKey: const ValueKey<String>(
            'tilemap-settings-location-flow-lightness',
          ),
          foregroundColor: widget.foregroundColor,
          secondaryColor: widget.secondaryColor,
          onChanged: (value) => _updateSelectedColor(lightness: value),
        ),
      ],
    );
  }
}

class _LocationImageFlowGradientPainter extends CustomPainter {
  const _LocationImageFlowGradientPainter({
    required this.points,
    required this.selectedIndex,
    required this.gradientRect,
    required this.foregroundColor,
    required this.secondaryColor,
  });

  final List<TilemapLocationImageFlowGradientPoint> points;
  final int selectedIndex;
  final Rect gradientRect;
  final Color foregroundColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(gradientRect, const Radius.circular(6)),
      backgroundPaint,
    );
    final gradient = ui.Gradient.linear(
      gradientRect.centerLeft,
      gradientRect.centerRight,
      [for (final point in points) point.color],
      [for (final point in points) point.position],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(gradientRect, const Radius.circular(6)),
      Paint()..shader = gradient,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(gradientRect, const Radius.circular(6)),
      Paint()
        ..color = secondaryColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke,
    );

    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final center = Offset(
        gradientRect.left + gradientRect.width * point.position,
        gradientRect.bottom + 12,
      );
      final isSelected = index == selectedIndex;
      final opaqueColor = point.color.withValues(alpha: 1);
      canvas
        ..drawCircle(
          center,
          isSelected ? 8 : 6,
          Paint()..color = foregroundColor.withValues(alpha: 0.18),
        )
        ..drawCircle(center, isSelected ? 5 : 4, Paint()..color = opaqueColor)
        ..drawCircle(
          center,
          isSelected ? 5 : 4,
          Paint()
            ..color = isSelected
                ? foregroundColor
                : secondaryColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _LocationImageFlowGradientPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.gradientRect != gradientRect ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

class _TilemapLocationImageFlowBlendModeEditor extends StatelessWidget {
  const _TilemapLocationImageFlowBlendModeEditor({
    required this.value,
    required this.foregroundColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  final TilemapLocationImageFlowBlendMode value;
  final Color foregroundColor;
  final Color secondaryColor;
  final ValueChanged<TilemapLocationImageFlowBlendMode> onChanged;

  String _labelFor(TilemapLocationImageFlowBlendMode mode) {
    return switch (mode) {
      TilemapLocationImageFlowBlendMode.normal => 'Normal (srcATop)',
      TilemapLocationImageFlowBlendMode.screen => 'Screen',
      TilemapLocationImageFlowBlendMode.overlay => 'Overlay',
      TilemapLocationImageFlowBlendMode.plus => 'Add',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              'Blend',
              style: TextStyle(color: secondaryColor, fontSize: 11),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: foregroundColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TilemapLocationImageFlowBlendMode>(
                    key: const ValueKey<String>(
                      'tilemap-settings-location-flow-blend-mode',
                    ),
                    value: value,
                    isExpanded: true,
                    dropdownColor: foregroundColor.computeLuminance() > 0.5
                        ? const Color(0xFF35352F)
                        : Colors.white,
                    iconEnabledColor: foregroundColor,
                    style: TextStyle(color: foregroundColor, fontSize: 11),
                    items: [
                      for (final mode
                          in TilemapLocationImageFlowBlendMode.values)
                        DropdownMenuItem(
                          value: mode,
                          child: Text(_labelFor(mode)),
                        ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) onChanged(mode);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
