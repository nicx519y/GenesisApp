import '../../qa_bridge.dart';
import 'local_identity.dart';

final _instances = Expando<LocalIdentityHook>();
LocalIdentityHook _current() {
  final bridge = QaBridge.current;
  if (bridge == null) throw StateError('No authenticated QA instance');
  return _instances[bridge] ??= LocalIdentityHook(
    bridge.store,
    resource: bridge.resource,
  );
}

Future<Object?> readLocalIdentity(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) => _current().read(p);
Future<Object?> prepareIdentityContract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) => _current().handlers['contract.localIdentity.prepare']!(
  p,
  prepared,
  started,
);
Future<Object?> readIdentityContract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) => _current().handlers['contract.localIdentity.read']!(p, prepared, started);
Future<Object?> cleanupIdentityContract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) => _current().handlers['contract.localIdentity.cleanup']!(
  p,
  prepared,
  started,
);

// The bridge enforces mock, resource, authentication and Case isolation first.
Future<Object?> prepareIdentityCase(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) => _current().handlers['fixture.localIdentity.prepare']!(p, prepared, started);

Future<Object?> cleanupIdentityCase(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) => _current().handlers['fixture.localIdentity.cleanup']!(p, prepared, started);
