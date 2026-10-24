import 'package:flutter/material.dart';
import '../../../../components/common/genesis_center_toast.dart';
import '../../../../components/login_sheet.dart';
import '../../../../components/login_provider_button.dart';
import '../../../../platform/auth/auth_cancelled_exception.dart';
import '../../../../platform/auth/auth_session.dart';
import 'notice.dart';

OverlayEntry? _entry;
final _subjectKey = GlobalKey();
int _providerCalls = 0;

Future<void> _frame() async {
  WidgetsBinding.instance.scheduleFrame();
  await WidgetsBinding.instance.endOfFrame;
}

/// Disposable real LoginSheet with a controlled provider result. No fixture is
/// imported by the read primitive. Never logs a fabricated business event.
Future<Object?> loginFailureContractFixture(
  Map<String, dynamic> parameters, bool prepared, bool started,
) async {
  if (!prepared || !started || const String.fromEnvironment('GENESIS_API_ENV') != 'mock') {
    throw StateError('Requires a started, prepared mock contract session');
  }
  final kind = parameters['kind'];
  if (parameters.length != 1 || !['failure', 'dynamic', 'cancel', 'ordinary', 'cleanup'].contains(kind)) {
    throw ArgumentError('Unknown notice contract stimulus');
  }
  if (kind == 'cleanup') {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    await _frame();
    return {'fixtureMounted': _subjectKey.currentContext != null,
      'toastTexts': renderedToastElements().map((e) => (e.widget as Text).data).toList()};
  }
  if (_entry != null) { throw StateError('Previous contract subject must be restored'); }
  OverlayState? overlay;
  void visit(Element element) {
    if (overlay != null) { return; }
    if (element is StatefulElement && element.state is OverlayState) {
      overlay = element.state as OverlayState;
      return;
    }
    element.visitChildren(visit);
  }
  final root = WidgetsBinding.instance.rootElement;
  if (root != null) { visit(root); }
  if (overlay == null) { throw StateError('App root overlay is not ready'); }
  _providerCalls = 0;
  if (kind == 'ordinary') {
    showGenesisToastInOverlay(overlay!, 'QA ordinary notice', brightness: Brightness.dark);
  } else {
    _entry = OverlayEntry(builder: (_) => Positioned.fill(
      child: Material(color: Colors.transparent, child: Align(
        alignment: Alignment.bottomCenter,
        child: KeyedSubtree(key: _subjectKey, child: LoginSheet(
          isDismissible: false,
          onLogin: (_) async {
            _providerCalls++;
            if (kind == 'cancel') { throw const AuthCancelledException(); }
            if (kind == 'dynamic') { throw Exception('QA provider unavailable'); }
            return false;
          },
        )),
      )),
    ));
    overlay!.insert(_entry!);
    await _frame();
    LoginProviderButtons? buttons;
    void find(Element element) {
      if (element.widget is LoginProviderButtons) { buttons = element.widget as LoginProviderButtons; }
      element.visitChildren(find);
    }
    final context = _subjectKey.currentContext;
    if (context is! Element) { throw StateError('Contract LoginSheet did not mount'); }
    find(context);
    if (buttons == null) { throw StateError('Contract provider buttons did not mount'); }
    await buttons!.onLogin(IdentityProvider.google);
  }
  await _frame();
  return {'fixtureMounted': _subjectKey.currentContext != null,
    'providerCalls': _providerCalls,
    'toastTexts': renderedToastElements().map((e) => (e.widget as Text).data).toList()};
}
