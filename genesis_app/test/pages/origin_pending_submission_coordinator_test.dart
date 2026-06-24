import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/pages/create/create_origin_draft_store.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_pending_submission_coordinator.dart';
import 'package:genesis_flutter_android/pages/origin_editor/origin_pending_submission_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    OriginPendingSubmissionCoordinator.instance.resetForTesting();
  });

  tearDown(() {
    OriginPendingSubmissionCoordinator.instance.resetForTesting();
  });

  test('expired create pending keeps saved draft', () async {
    final draft = CreateOriginDraft.empty().copyWith(
      basics: const BasicsDraft(
        originName: 'Draft Worldo',
        worldView: 'Still editable after timeout.',
        worldLogic: 'Creation did not finish.',
      ),
      basicsSaved: true,
    );
    await CreateOriginDraftStore.saveFinal(draft);
    await OriginPendingSubmissionStore.saveCreating('o_timeout_1');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'creating_origin_started_at',
      DateTime.now()
          .toUtc()
          .subtract(OriginPendingSubmissionStore.timeout)
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
    );

    await OriginPendingSubmissionCoordinator.instance.ensureCreatingPolling(
      loadOriginInfo: (_) =>
          fail('Expired pending should not poll origin info'),
    );

    expect(await OriginPendingSubmissionStore.loadCreating(), isNull);
    expect(
      (await CreateOriginDraftStore.loadFinal()).basics.originName,
      'Draft Worldo',
    );
  });
}
