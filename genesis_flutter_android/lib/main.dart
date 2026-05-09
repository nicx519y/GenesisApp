import 'package:flutter/material.dart';

import 'app/genesis_app.dart';
import 'network/genesis_api.dart';
import 'platform/user_session.dart';

export 'app/genesis_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final uid = await UserSession.readUid();
  if (uid == null) {
    try {
      await GenesisApi().bindDevice().timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
  runApp(const GenesisApp());
}
