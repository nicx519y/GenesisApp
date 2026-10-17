# App launch transition

Import `app_launch_transition.dart`. This module depends only on Flutter and has
no MiniPhone, network, player, or Navigator dependency.

- Keep one `AppLaunchTransitionController` for the lifetime of a host. Use
  `initiallyOpen: true` for a restored/direct-entry page.
- Supply `home`, the current `page`, a surface color and `onDismissed` to
  `AppLaunchTransitionHost`. The home remains mounted; the page remains mounted
  through closing and is removed after dismissal. The caller clears its logical
  page in `onDismissed`.
- Wrap each origin in `AppLaunchSource` with an ID unique within the host, its
  actual corner radius, and optional color/presentation-only icon preview. It
  does not add gestures. Wrap only the visual tile when a badge extends outside.
- Call `controller.open(sourceId: id)` **before** business effects that can remove
  or move the origin. Only if it returns true, update the current page and perform
  navigation effects. A second launch while a page exists is rejected.
- Call `close(fallbackSourceId: id)` for return to home. The module remeasures the
  original source first, then the fallback. Missing/clipped origins fade; direct
  entry pages always fade. Internal page navigation is owned by the caller and
  can replace `page` without starting a new launch.
- Listen to controller status for completion, use `finish()` before dismissing
  an outer route, and dispose the controller with its owner.

Default motion: 360ms open, 280ms close, ease-out cubic, 96% background scale,
12% black dim, 120ms fallback fade. `AppLaunchTransitionSpec` centralizes these
values. Reduced motion switches immediately; a viewport resize settles the
active transition after layout. A mid-opening close reverses the current path.

The host requires bounded constraints. Origins are measured in the unscaled
home coordinate space and checked against ancestor paint clips. Pages receive
final viewport constraints throughout the transition and are uniformly scaled
inside the animated rounded rectangle, so content never lays out at icon size.
Hidden home tickers, input, focus and semantics are disabled. Keep controls that
must remain usable during transition (such as an outer close button) outside
the host.

Focused coverage: `test/ui/animations/app_launch_transition_test.dart` and
`test/pages/mini_phone/mini_phone_launch_transition_test.dart`.

## Validation commands

Run from `genesis_app/`. The focused suite includes existing music, wallpaper,
like-status and shared music widget regressions as well as the launch tests.

```sh
dart format lib/ui/animations/app_launch_transition lib/pages/mini_phone/mini_phone_page.dart lib/pages/mini_phone/home/mini_phone_home.dart test/ui/animations/app_launch_transition_test.dart test/pages/mini_phone/mini_phone_launch_transition_test.dart
flutter analyze --no-pub lib/ui/animations/app_launch_transition lib/pages/mini_phone/mini_phone_page.dart lib/pages/mini_phone/home/mini_phone_home.dart test/ui/animations/app_launch_transition_test.dart test/pages/mini_phone/mini_phone_launch_transition_test.dart
flutter test --no-pub test/ui/animations/app_launch_transition_test.dart test/pages/mini_phone/mini_phone_launch_transition_test.dart test/pages/mini_phone/mini_phone_music_page_test.dart test/pages/mini_phone/mini_phone_wallpaper_page_test.dart test/pages/mini_phone/mini_phone_music_widgets_test.dart test/pages/mini_phone/mini_phone_music_like_page_test.dart
flutter run --no-pub --debug --flavor production -d 1A101FDF6006AX
```
