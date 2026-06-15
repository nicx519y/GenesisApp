import 'package:flutter/foundation.dart';

final ValueNotifier<bool> genesisDebugFloatingButtonVisible =
    ValueNotifier<bool>(true);

void showGenesisDebugFloatingButton() {
  genesisDebugFloatingButtonVisible.value = true;
}

void hideGenesisDebugFloatingButton() {
  genesisDebugFloatingButtonVisible.value = false;
}
