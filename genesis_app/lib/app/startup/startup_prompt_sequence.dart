import 'package:flutter/foundation.dart';

/// Presentation priority only. Never use this to gate SDKs, data or telemetry.
enum StartupPromptStage { ready, privacy, att }

final startupPromptSequence = StartupPromptSequence();

class StartupPromptSequence extends ValueNotifier<StartupPromptStage> {
  StartupPromptSequence() : super(StartupPromptStage.ready);

  final Set<Object> _loginOwners = {};
  bool get loginBlocked => _loginOwners.isNotEmpty;
  bool get waitingForPrivacy => value == StartupPromptStage.privacy;
  bool get blocksOtherPrompts =>
      loginBlocked || value != StartupPromptStage.ready;

  void blockForLogin(Object owner) {
    if (_loginOwners.add(owner)) notifyListeners();
  }

  void releaseLogin(Object owner) {
    if (_loginOwners.remove(owner)) notifyListeners();
  }

  void begin() => value = StartupPromptStage.privacy;

  void finishPrivacy() {
    if (waitingForPrivacy) value = StartupPromptStage.att;
  }

  void finishAtt() {
    if (value == StartupPromptStage.att) value = StartupPromptStage.ready;
  }

  @visibleForTesting
  void resetForTesting() {
    _loginOwners.clear();
    value = StartupPromptStage.ready;
    notifyListeners();
  }
}
