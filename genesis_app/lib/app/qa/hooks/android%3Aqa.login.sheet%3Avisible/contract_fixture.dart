import '../../qa_bridge.dart';

Future<Object?> _invokePersonalization(
  String operation, Map<String, dynamic> parameters, bool prepared, bool started,
) async {
  if (!prepared || const String.fromEnvironment('GENESIS_API_ENV') != 'mock') {
    throw StateError('Login sheet fixture requires prepared mock contract');
  }
  final handler = QaBridge.current?.operations['fixture.personalization.$operation'];
  if (handler == null) { throw StateError('Personalization fixture unavailable'); }
  return handler(parameters, started);
}
Future<Object?> prepareLoginSheetContract(Map<String, dynamic> parameters, bool prepared, bool started) =>
    _invokePersonalization('prepare', parameters, prepared, started);
Future<Object?> readLoginSheetContract(Map<String, dynamic> parameters, bool prepared, bool started) =>
    _invokePersonalization('read', parameters, prepared, started);
Future<Object?> restoreLoginSheetContract(Map<String, dynamic> parameters, bool prepared, bool started) =>
    _invokePersonalization('restore', parameters, prepared, started);
