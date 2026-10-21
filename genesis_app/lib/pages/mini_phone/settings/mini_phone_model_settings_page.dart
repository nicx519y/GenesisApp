import 'package:flutter/material.dart';
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
    var previousModel = settings.selectedModelCode;
    var previousTokens = settings.pageCache.memorySettings?.memoryTokens;
    return MemoryModelPage(
      key: ObjectKey(settings.pageCache),
      worldId: settings.worldId,
      enableCollectAnalytics: false,
      pageCache: settings.pageCache,
      onBack: onBack,
      catalogLoader: (_) => settings.catalog(),
      onModelSaved: (code) {
        if (previousModel != code && generation == analytics?.generation()) {
          analytics?.event(
            'model_change',
            target: 'model',
            stage: 'changed',
            data: {
              ...?eventContext,
              'previous_model': previousModel,
              'model_code': code,
              'scope': 'server',
            },
          );
        }
        previousModel = code;
      },
      onMemorySaved: (saved) {
        if (previousTokens != saved.memoryTokens &&
            generation == analytics?.generation()) {
          analytics?.event(
            'memory_change',
            target: 'memory_tokens',
            stage: 'changed',
            data: {
              ...?eventContext,
              if (previousTokens != null) 'previous_tokens': previousTokens,
              'memory_tokens': saved.memoryTokens,
              'scope': 'server',
            },
          );
        }
        previousTokens = saved.memoryTokens;
      },
    );
  }
}
