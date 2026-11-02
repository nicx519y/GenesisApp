import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/platform/session/app_background_resume.dart';

void main() {
  test('inactive alone and repeated resumed do not trigger refresh', () {
    final tracker = AppBackgroundResume();
    expect(tracker.update(AppLifecycleState.inactive), false);
    expect(tracker.update(AppLifecycleState.resumed), false);
    expect(tracker.update(AppLifecycleState.resumed), false);
  });
  test('actual app background and foreground trigger once', () {
    final tracker = AppBackgroundResume();
    tracker.update(AppLifecycleState.inactive);
    tracker.update(AppLifecycleState.hidden);
    tracker.update(AppLifecycleState.paused);
    tracker.update(AppLifecycleState.inactive);
    expect(tracker.update(AppLifecycleState.resumed), true);
    expect(tracker.update(AppLifecycleState.resumed), false);
  });
}
