import '../telemetry/genesis_telemetry.dart';

void trackGemTaskClaimedIfNeeded({
  required String taskCode,
  required String status,
}) {
  if (status.trim() != 'claimed') return;
  final normalizedTaskCode = taskCode.trim();
  if (normalizedTaskCode.isEmpty) return;
  GenesisTelemetry.collectLog(
    actionType: 'pay_event',
    action: 'task_claimed',
    object1: normalizedTaskCode,
  );
}
