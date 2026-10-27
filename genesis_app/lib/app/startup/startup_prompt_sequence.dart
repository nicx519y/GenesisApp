import 'package:flutter/foundation.dart';

/// Presentation priority only. Never use this to gate SDKs, data or telemetry.
enum StartupPromptStage { ready, privacy, att }

final startupPromptSequence = StartupPromptSequence();

class StartupPromptSequence extends ValueNotifier<StartupPromptStage> {
  StartupPromptSequence() : super(StartupPromptStage.ready);

  bool get waitingForPrivacy => value == StartupPromptStage.privacy;
  bool get blocksOtherPrompts => value != StartupPromptStage.ready;

  void begin() => value = StartupPromptStage.privacy;

  void finishPrivacy() {
    if (waitingForPrivacy) value = StartupPromptStage.att;
  }

  void finishAtt() {
    if (value == StartupPromptStage.att) value = StartupPromptStage.ready;
  }

  @visibleForTesting
  void resetForTesting() => value = StartupPromptStage.ready;
}
