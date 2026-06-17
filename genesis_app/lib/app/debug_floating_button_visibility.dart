import 'package:flutter/foundation.dart';

final ValueNotifier<bool> genesisDebugFloatingButtonVisible =
    ValueNotifier<bool>(false);

void showGenesisDebugFloatingButton() {
  genesisDebugFloatingButtonVisible.value = true;
}

void hideGenesisDebugFloatingButton() {
  genesisDebugFloatingButtonVisible.value = false;
}
