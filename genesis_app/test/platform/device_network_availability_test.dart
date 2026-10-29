import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/channels/genesis_method_channels.dart';
import 'package:genesis_flutter_android/utils/network_availability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(GenesisMethodChannels.device, null);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final available in [false, true]) {
      test('$platform uses the system snapshot available=$available', () async {
        debugDefaultTargetPlatformOverride = platform;
        messenger.setMockMethodCallHandler(GenesisMethodChannels.device, (
          call,
        ) async {
          expect(call.method, GenesisMethodChannels.getNetworkAvailability);
          return available;
        });
        // A native offline result wins even if the test host has IP interfaces.
        expect(await hasDeviceNetworkConnection(), available);
      });
    }
  }

  test('each check reads fresh state after a network transition', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var available = true;
    var reads = 0;
    messenger.setMockMethodCallHandler(GenesisMethodChannels.device, (_) async {
      reads++;
      return available;
    });
    expect(await hasDeviceNetworkConnection(), isTrue);
    available = false;
    expect(await hasDeviceNetworkConnection(), isFalse);
    expect(reads, 2);
  });

  test(
    'an unknown or failed native probe does not grant network access',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      messenger.setMockMethodCallHandler(GenesisMethodChannels.device, (
        _,
      ) async {
        return null;
      });
      expect(await hasDeviceNetworkConnection(), isFalse);
      messenger.setMockMethodCallHandler(GenesisMethodChannels.device, (
        _,
      ) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(await hasDeviceNetworkConnection(), isFalse);
      messenger.setMockMethodCallHandler(GenesisMethodChannels.device, null);
      expect(await hasDeviceNetworkConnection(), isFalse);
    },
  );

  test(
    'a stalled native probe ends without proceeding to socket checks',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final pending = Completer<bool>();
      messenger.setMockMethodCallHandler(
        GenesisMethodChannels.device,
        (_) => pending.future,
      );
      expect(await hasDeviceNetworkConnection(), isFalse);
      pending.complete(true);
    },
  );
}
