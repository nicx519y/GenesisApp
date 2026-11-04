import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/network/mini_phone/mini_phone_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_models.dart';
import 'package:genesis_flutter_android/pages/mini_phone/camera/mini_phone_camera_preview_jobs.dart';
import 'package:genesis_flutter_android/pages/mini_phone/state/mini_phone_requests.dart';

const scope = MiniPhoneCameraScope(
  environment: 'dev',
  accountId: 'u',
  worldId: 'w',
);
const person = PhonePerson('p', 'Person', '');
MiniPhoneCameraRequest request([String prompt = 'First']) =>
    MiniPhoneCameraRequest(
      scope: scope,
      participants: [person],
      prompt: prompt,
    );

void main() {
  testWidgets('failed placeholders disappear only on a later album visit', (
    tester,
  ) async {
    final requests = MiniPhoneRequests(() {})..uid = 'u';
    final jobs = MiniPhoneCameraPreviewJobs(requests: requests, scope: scope);
    addTearDown(jobs.dispose);
    for (var i = 0; i < 3; i++) {
      jobs.submit(request(), sampleAsset: 'sample');
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(seconds: 30));
    jobs.beginAlbumVisit();
    expect(jobs.tasks.length, 3);
    expect(jobs.tasks.first.state, CameraPreviewTaskState.failed);
    jobs.endAlbumVisit();
    expect(jobs.tasks.length, 3);
    jobs.beginAlbumVisit();
    expect(jobs.tasks.length, 2);
    expect(
      jobs.tasks.every((t) => t.state == CameraPreviewTaskState.succeeded),
      isTrue,
    );
  });
  testWidgets(
    'preview accepts selected characters without a written description',
    (tester) async {
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final jobs = MiniPhoneCameraPreviewJobs(requests: requests, scope: scope);
      addTearDown(jobs.dispose);
      expect(jobs.submit(request(''), sampleAsset: 'sample'), isTrue);
      expect(jobs.pendingCount, 1);
      expect(jobs.tasks.single.request.prompt, isEmpty);
      await tester.pump(const Duration(seconds: 20));
      expect(jobs.tasks.single.state, CameraPreviewTaskState.succeeded);
    },
  );
  testWidgets(
    'parallel tasks retain snapshots and reject only rapid double taps',
    (tester) async {
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final jobs = MiniPhoneCameraPreviewJobs(requests: requests, scope: scope);
      addTearDown(jobs.dispose);
      expect(jobs.submit(request(), sampleAsset: 'one'), isTrue);
      expect(jobs.submit(request(), sampleAsset: 'one'), isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(jobs.submit(request('Second'), sampleAsset: 'two'), isTrue);
      expect(jobs.pendingCount, 2);
      expect(jobs.tasks.map((t) => t.request.prompt), ['Second', 'First']);
      await tester.pump(const Duration(seconds: 15));
      expect(jobs.tasks.last.state, CameraPreviewTaskState.succeeded);
      expect(jobs.tasks.first.state, CameraPreviewTaskState.generating);
      await tester.pump(const Duration(seconds: 10));
      expect(jobs.pendingCount, 0);
      expect(jobs.unreadCount, 2);
      jobs.markViewed(jobs.tasks.first.id);
      expect(jobs.unreadCount, 1);
    },
  );

  testWidgets(
    'one failed task retries in place without changing its original input',
    (tester) async {
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final jobs = MiniPhoneCameraPreviewJobs(requests: requests, scope: scope);
      addTearDown(jobs.dispose);
      for (var i = 0; i < 3; i++) {
        jobs.submit(request('Photo $i'), sampleAsset: 'sample-$i');
        await tester.pump(const Duration(seconds: 1));
      }
      final failed = jobs.tasks.first;
      await tester.pump(const Duration(seconds: 30));
      expect(failed.state, CameraPreviewTaskState.failed);
      expect(jobs.tasks.length, 3);
      jobs.retry(failed.id);
      jobs.retry(failed.id);
      expect(failed.attempt, 2);
      await tester.pump(const Duration(seconds: 30));
      expect(failed.state, CameraPreviewTaskState.succeeded);
      expect(failed.request.prompt, 'Photo 2');
      expect(failed.sampleAsset, 'sample-2');
      expect(jobs.tasks.first.id, failed.id);
    },
  );

  testWidgets(
    'account reset discards pending and complete results even for same uid',
    (tester) async {
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final jobs = MiniPhoneCameraPreviewJobs(requests: requests, scope: scope);
      addTearDown(jobs.dispose);
      jobs.submit(request(), sampleAsset: 'one');
      requests.reset();
      requests.uid = 'u';
      jobs.bindScope(scope);
      await tester.pump(const Duration(seconds: 40));
      expect(jobs.tasks, isEmpty);
      expect(jobs.pendingCount, 0);
    },
  );

  testWidgets(
    'world mismatch cannot submit and changing world clears only this queue',
    (tester) async {
      final requests = MiniPhoneRequests(() {})..uid = 'u';
      final a = MiniPhoneCameraPreviewJobs(requests: requests, scope: scope);
      const other = MiniPhoneCameraScope(
        environment: 'dev',
        accountId: 'u',
        worldId: 'b',
      );
      final b = MiniPhoneCameraPreviewJobs(requests: requests, scope: other);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      a.submit(request(), sampleAsset: 'one');
      expect(b.submit(request(), sampleAsset: 'one'), isFalse);
      expect(b.tasks, isEmpty);
      a.bindScope(other);
      await tester.pump(const Duration(seconds: 40));
      expect(a.tasks, isEmpty);
    },
  );
}
