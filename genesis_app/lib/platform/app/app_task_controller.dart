import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../channels/genesis_method_channels.dart';

/// Moves the Android task to the background without finishing its Activity.
Future<void> moveAppToBackground() async {
  try {
    final moved = await GenesisMethodChannels.device.invokeMethod<bool>(
      GenesisMethodChannels.moveAppToBackground,
    );
    if (moved != true) debugPrint('Unable to move the app to the background.');
  } on PlatformException catch (error) {
    debugPrint('Unable to move the app to the background: $error');
  } on MissingPluginException catch (error) {
    debugPrint('Unable to move the app to the background: $error');
  }
}
