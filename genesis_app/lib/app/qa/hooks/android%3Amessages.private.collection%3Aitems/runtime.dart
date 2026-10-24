import 'package:flutter/widgets.dart';
import '../../../bootstrap/app_services_scope.dart';
import '../../../bootstrap/service_registry.dart';
import '../../../../network/direct_message_conversation_store.dart';
import '../../qa_bridge.dart';
import 'collection.dart';

PrivateCollection? _owned;
QaBridge? _bridge;
AppServices? _services;

AppServices actualServices() {
  final found = <AppServices>{};
  void visit(Element e) {
    final services = AppServicesScope.maybeRead(e);
    if (services != null) found.add(services);
    e.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  if (found.length != 1)
    throw StateError('Actual App services are not uniquely ready');
  return found.single;
}

Future<Object?> collectionOperation(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started ||
      p.length != 1 ||
      !['prepare', 'read', 'cleanup'].contains(p['operation'])) {
    throw ArgumentError('Started App and one collection operation required');
  }
  final bridge = QaBridge.current;
  final services = actualServices();
  if (bridge == null || !identical(bridge.store, services.sessionStore)) {
    throw StateError('App and bridge identity sources differ');
  }
  if (_owned != null &&
      (!identical(_bridge, bridge) || !identical(_services, services))) {
    throw StateError('Collection owner changed before restoration');
  }
  PrivateCollection create() => PrivateCollection(
    session: services.sessionStore,
    store: services.directMessageConversations,
    storage: SqfliteDirectMessageConversationStorage(),
    resource: bridge.resource,
    currentResource: () =>
        identical(QaBridge.current, bridge) &&
        identical(actualServices(), services),
  );
  switch (p['operation']) {
    case 'read':
      return (_owned ?? create()).read();
    case 'prepare':
      _bridge = bridge;
      _services = services;
      _owned ??= create();
      return _owned!.prepare();
    case 'cleanup':
      if (_owned == null) throw StateError('No owned collection fixture');
      final result = await _owned!.cleanup();
      _owned = null;
      _bridge = null;
      _services = null;
      return result;
  }
  throw ArgumentError('Unknown collection operation');
}
