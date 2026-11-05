import 'mini_phone_camera_image.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../components/common/genesis_bottom_sheet_panel.dart';
import '../../../network/mini_phone/mini_phone_camera_models.dart';
import '../../../l10n/genesis_localizations.dart';
import '../shared/mini_phone_ui.dart';

class PhoneCameraStyleSheet extends StatefulWidget {
  const PhoneCameraStyleSheet({
    super.key,
    required this.options,
    this.selected,
  });
  final PhoneCameraOptions options;
  final String? selected;

  @override
  State<PhoneCameraStyleSheet> createState() => _PhoneCameraStyleSheetState();
}

class _PhoneCameraStyleSheetState extends State<PhoneCameraStyleSheet> {
  late String? _selected = widget.selected;
  Timer? _dismissTimer;

  void _select(String label) {
    if (_dismissTimer != null) return;
    setState(() => _selected = label);
    // Let the new selection paint before starting the sheet's exit animation.
    _dismissTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, label);
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GenesisActionSheetHeader(
            title: context.l10n.miniPhoneCameraStyle,
            showClose: true,
            onClose: () => Navigator.pop(context),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: miniPageInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final style in widget.options.styles)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 128,
                      child: Semantics(
                        button: true,
                        selected: style.label == _selected,
                        child: InkWell(
                          onTap: () => _select(style.label),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: style.label == _selected
                                        ? miniPink
                                        : miniLine,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: AspectRatio(
                                  aspectRatio: 2 / 3,
                                  child: MiniPhoneCameraImage(
                                    imageUrl: style.demoImageUrl,
                                    fixedSize: true,
                                    fit: BoxFit.cover,
                                    placeholder: (_) =>
                                        const ColoredBox(color: miniRaised),
                                    errorWidget: (_, _) =>
                                        const ColoredBox(color: miniRaised),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                style.name,
                                textAlign: TextAlign.center,
                                style: miniStyle(12, FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
