import '../../qa_bridge.dart';
import '../../../../platform/session/user_session_store.dart';
import '../../fixtures/http/mock_response_overrides.dart';
import '../../../../network/http_transport.dart';

QaMockResponseLease? _lease;
QaBridge? _owner;
String? _uid;
String? _beforeToken;
Map<String, dynamic>? _beforeInfo;
Future<Object?> prepareEmptyContract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  final b = QaBridge.current;
  if (!prepared || started || b == null || p.isNotEmpty)
    throw StateError('Requires pre-start contract');
  if (_lease != null) throw StateError('Already prepared');
  final uid = await b.store.readLoginUid();
  if (uid == null) throw StateError('Requires isolated QA identity');
  if (!QaMockResponseOverrides.enabled || !uid.startsWith('qa_test_')) {
    throw StateError('Requires isolated mock contract identity');
  }
  _beforeToken = await b.store.readAuthToken();
  _beforeInfo = await b.store.readUserInfo();
  _uid = uid;
  _owner = b;
  _lease = QaMockResponseOverrides.install(
    resource: b.resource,
    ownerUid: uid,
    currentOwner: b.store.readLoginUid,
    currentResource: () => identical(QaBridge.current, b),
    responses: {
      'GET /api/v1/direct_message/conversations': {
        'err_no': 0,
        'err_msg': '',
        'data': {'list': [], 'has_more': false, 'next_after_message_id': ''},
      },
    },
  );
  // A local UID alone triggers real backend-token recovery in the profile loader.
  // This synthetic credential is confined to the authenticated mock contract.
  await b.store.saveAuthToken('qa_mock_private_empty_${b.resource}');
  return {
    'owner': await b.store.readLoginUid(),
    'resource': b.resource,
    'backendSessionReady': await b.store.readCompleteSession() != null,
  };
}

Future<Object?> restoreEmptyContract(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!prepared || p.isNotEmpty) throw StateError('Requires contract');
  if (_owner != null && !identical(QaBridge.current, _owner))
    throw StateError('Contract owner changed');
  final owner = _owner;
  if (owner != null && await owner.store.readLoginUid() != _uid) {
    throw StateError('Contract identity changed');
  }
  _lease?.restore();
  if (owner != null) {
    // The store has no token-only clear API; restore the isolated snapshot.
    await owner.store.clearUid();
    await owner.store.saveUid(_uid!);
    if (_beforeToken != null) await owner.store.saveAuthToken(_beforeToken!);
    if (_beforeInfo != null) await owner.store.saveUserInfo(_beforeInfo!);
    if (await owner.store.readAuthToken() != _beforeToken ||
        await owner.store.readLoginUid() != _uid) {
      throw StateError('Contract session restoration failed');
    }
  }
  _lease = null;
  _owner = null;
  final probe = await QaMockResponseOverrides.respond(
    TransportRequest(
      method: 'GET',
      uri: Uri.parse('https://qa.invalid/api/v1/direct_message/conversations'),
      headers: const {},
      bodyBytes: null,
      timeoutMs: 1,
    ),
  );
  return {'restored': probe == null};
}
