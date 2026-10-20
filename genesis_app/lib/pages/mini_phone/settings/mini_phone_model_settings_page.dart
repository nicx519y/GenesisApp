import 'package:flutter/material.dart';
import '../../../network/models/gem_model.dart';
import '../../gems/memory_model_page.dart';
import 'mini_phone_model_settings.dart';
import '../state/mini_phone_analytics.dart';

class MiniPhoneModelSettingsPage extends StatelessWidget {
  const MiniPhoneModelSettingsPage({
    super.key,
    required this.settings,
    required this.onBack,
    this.analytics,
  });
  final MiniPhoneModelSettings settings;
  final VoidCallback onBack;
  final MiniPhoneAnalytics? analytics;
  @override
  Widget build(BuildContext context) {
    final generation = analytics?.generation();
    final eventContext = analytics?.context('models');
    return MemoryModelPage(
      worldId: miniPhoneModelPreviewWorldId,
      enableCollectAnalytics: false,
      onBack: onBack,
      catalogLoader: (_) => settings.catalog(),
      selectionHandler: (_, code) async {
        final previous = settings.selectedModelCode;
        settings.selectedModelCode = code;
        if (previous != code && generation == analytics?.generation()) {
          analytics?.event(
            'model_change',
            target: 'model',
            stage: 'changed',
            data: {
              ...?eventContext,
              'previous_model': previous,
              'model_code': code,
              'scope': 'local_session',
            },
          );
        }
        return GemModelSelection(selectedModelCode: code);
      },
      selectedModelCodeCacheWriter: (_) async {},
      memorySettingsLoader: (_) => settings.memory(),
      memorySettingsUpdater: (tokens) async {
        final previous = settings.memoryTokens;
        settings.memoryTokens = tokens;
        if (previous != tokens && generation == analytics?.generation()) {
          analytics?.event(
            'memory_change',
            target: 'memory_tokens',
            stage: 'changed',
            data: {
              ...?eventContext,
              'previous_tokens': previous,
              'memory_tokens': tokens,
              'scope': 'local_session',
            },
          );
        }
        return settings.memory();
      },
    );
  }
}
