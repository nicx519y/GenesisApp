import 'package:flutter/foundation.dart';

import 'http_transport.dart';
import 'local_mock_genesis_transport.dart';

const bool kLocalMockTransportAvailable = !kReleaseMode;

HttpTransport? createLocalMockGenesisTransport() {
  if (!kLocalMockTransportAvailable) return null;
  return LocalMockGenesisTransport.instance;
}
