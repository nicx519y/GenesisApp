import 'package:flutter/foundation.dart';

final ValueNotifier<bool> genesisDebugFloatingButtonVisible =
    ValueNotifier<bool>(kDebugMode);

void showGenesisDebugFloatingButton() {
  genesisDebugFloatingButtonVisible.value = true;
}

void hideGenesisDebugFloatingButton() {
  genesisDebugFloatingButtonVisible.value = false;
}
