import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/system_image_picker_activity.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('com.worldo.ai/image_picker_lifecycle');
  const events = MethodChannel('com.worldo.ai/image_picker_lifecycle/events');
  late SystemImagePickerActivity picker;
  late List<String> calls;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(methods, (
      call,
    ) async {
      calls.add(call.method);
      return call.method == 'begin' ? true : null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      events,
      (call) async => null,
    );
    picker = SystemImagePickerActivity();
  });
  tearDown(() async {
    picker.dispose();
    await Future<void>.delayed(Duration.zero);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(methods, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(events, null);
    debugDefaultTargetPlatformOverride = null;
  });
  test(
    'native monitored picker allows paused until Home or lock event',
    () async {
      final gate = Completer<int>();
      final result = picker.run(() => gate.future);
      await Future<void>.delayed(Duration.zero);
      expect(picker.allows(AppLifecycleState.paused), isTrue);
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        events.name,
        const StandardMethodCodec().encodeSuccessEnvelope('background'),
        (_) {},
      );
      expect(picker.backgrounded, isTrue);
      expect(picker.allows(AppLifecycleState.paused), isFalse);
      gate.complete(42);
      expect(await result, 42);
      expect(picker.active, isFalse);
      expect(calls, ['begin', 'end']);
    },
  );
  test('nested picker scopes end once and errors release the scope', () async {
    await expectLater(
      picker.run(() async {
        await picker.run(() async => 1);
        expect(picker.active, isTrue);
        throw StateError('cancelled');
      }),
      throwsStateError,
    );
    expect(picker.active, isFalse);
    expect(calls, ['begin', 'end']);
  });
  test('missing native monitor only exempts inactive', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      methods,
      (call) async => false,
    );
    await picker.run(() async {
      expect(picker.allows(AppLifecycleState.inactive), isTrue);
      expect(picker.allows(AppLifecycleState.hidden), isFalse);
      expect(picker.allows(AppLifecycleState.paused), isFalse);
    });
    expect(picker.active, isFalse);
  });
}
