import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final systemImagePickerActivity = SystemImagePickerActivity();

/// A scoped exception for system UI, not a general background-playback switch.
/// Android additionally watches task visibility and screen lock while its
/// external picker obscures Flutter. iOS's in-app picker only needs inactive.
class SystemImagePickerActivity extends ChangeNotifier
    with WidgetsBindingObserver {
  SystemImagePickerActivity() {
    WidgetsBinding.instance.addObserver(this);
  }
  static const _method = MethodChannel('com.worldo.ai/image_picker_lifecycle');
  static const _events = EventChannel(
    'com.worldo.ai/image_picker_lifecycle/events',
  );
  StreamSubscription<dynamic>? _subscription;
  Timer? _returnTimer;
  int _depth = 0;
  bool _finishing = false;
  bool _blocked = false;
  bool _allowPaused = false;
  bool _disposed = false;
  bool get active => _depth > 0 || _finishing;
  bool get backgrounded => active && _blocked;
  bool allows(AppLifecycleState state) =>
      active &&
      !_blocked &&
      (state == AppLifecycleState.inactive ||
          _allowPaused &&
              (state == AppLifecycleState.hidden ||
                  state == AppLifecycleState.paused));

  Future<T> run<T>(Future<T> Function() pick) async {
    if (_disposed) throw StateError('Image picker activity has been disposed.');
    _depth++;
    if (_depth == 1) {
      _returnTimer?.cancel();
      _finishing = _blocked = false;
      _allowPaused = false;
      notifyListeners();
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          _allowPaused = await _method.invokeMethod<bool>('begin') ?? false;
        } on MissingPluginException {
          _allowPaused = false;
        } on PlatformException {
          _allowPaused = false;
        }
        if (_allowPaused) {
          _subscription ??= _events.receiveBroadcastStream().listen((event) {
            if (event == 'background' && active && !_blocked) {
              _blocked = true;
              notifyListeners();
            }
          }, onError: (Object _) {
            _allowPaused = false;
            if (!_disposed) notifyListeners();
          });
        }
        if (!_disposed) notifyListeners();
      }
    }
    try {
      return await pick();
    } finally {
      _depth--;
      if (!_disposed && _depth == 0) {
        // The picker result may arrive just before Flutter's resumed callback.
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        _finishing = lifecycle != null && lifecycle != AppLifecycleState.resumed;
        if (_finishing) {
          _returnTimer = Timer(const Duration(seconds: 2), _finish);
        } else {
          _finish();
        }
      }
    }
  }

  void _finish() {
    if (_disposed || _depth > 0) return;
    _returnTimer?.cancel();
    _finishing = _allowPaused = false;
    notifyListeners();
    unawaited(_method.invokeMethod<void>('end').catchError((Object _) {}));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _finishing) _finish();
  }

  @visibleForTesting
  void debugSet({
    required bool active,
    bool allowPaused = true,
    bool backgrounded = false,
  }) {
    _depth = active ? 1 : 0;
    _allowPaused = allowPaused;
    _blocked = backgrounded;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _returnTimer?.cancel();
    unawaited(_subscription?.cancel() ?? Future.value());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
