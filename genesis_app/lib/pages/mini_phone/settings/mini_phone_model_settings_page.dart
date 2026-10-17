import 'package:flutter/material.dart';
import '../../../network/models/gem_model.dart';
import '../../gems/memory_model_page.dart';
import 'mini_phone_model_settings.dart';

class MiniPhoneModelSettingsPage extends StatelessWidget {
  const MiniPhoneModelSettingsPage({
    super.key,
    required this.settings,
    required this.onBack,
  });
  final MiniPhoneModelSettings settings;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => MemoryModelPage(
    worldId: miniPhoneModelPreviewWorldId,
    onBack: onBack,
    catalogLoader: (_) => settings.catalog(),
    selectionHandler: (_, code) async {
      settings.selectedModelCode = code;
      return GemModelSelection(selectedModelCode: code);
    },
    selectedModelCodeCacheWriter: (_) async {},
    memorySettingsLoader: (_) => settings.memory(),
    memorySettingsUpdater: (tokens) async {
      settings.memoryTokens = tokens;
      return settings.memory();
    },
  );
}
