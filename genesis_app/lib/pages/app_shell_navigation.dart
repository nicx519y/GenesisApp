import 'package:flutter/foundation.dart';

final ValueNotifier<int> homeTabForWorldEntryRequests = ValueNotifier<int>(0);

/// Selects the retained Home tab before a launched World is pushed.
void requestHomeTabForWorldEntry() {
  homeTabForWorldEntryRequests.value += 1;
}
