import '../../../../platform/session/user_session_store.dart';
import '../android%253Aworld.test_identity%253Avalue/identity.dart';

/// Complete only the already acquired mock identity. The original identity
/// resource owns the token snapshot and restores it with the UID and profile.
Future<void> prepareParentChatIdentity(WorldTestIdentity identity) async {
  if (const String.fromEnvironment('GENESIS_API_ENV') != 'mock') {
    throw StateError('Mock environment required');
  }
  final before = await identity.read();
  if (before['isolated'] != true || before['uid'] != identity.uid) {
    throw StateError('Owned parent identity required');
  }
  await identity.store.saveAuthToken('qa_mock_parent_${identity.resource}');
  final actual = await identity.store.readCompleteSession();
  if (actual == null || actual.uid != identity.uid) {
    throw StateError('Parent chat session incomplete');
  }
}
