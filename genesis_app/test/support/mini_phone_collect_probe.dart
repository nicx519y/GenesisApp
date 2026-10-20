import 'package:genesis_flutter_android/app/telemetry/genesis_telemetry.dart';

/// Captures the real Collect wire events without starting network uploads.
class MiniPhoneCollectProbe {
  MiniPhoneCollectProbe() {
    GenesisTelemetry.resetForTesting();
    GenesisTelemetry.setCollectUploaderForTesting(
      CollectTelemetryUploader(store: store)..configure(enabled: true),
    );
  }
  final store = MemoryCollectEventStore();

  Future<List<CollectEvent>> take() async {
    await GenesisTelemetry.waitForCollectWritesForTesting();
    final batch = await store.claimPending(limit: 1000);
    if (batch == null) return [];
    await store.deleteClaimed(batch.batchId);
    return batch.events;
  }

  void dispose() => GenesisTelemetry.resetForTesting();
}
