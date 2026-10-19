import '../json_utils.dart';

class GemTaskActionResult {
  const GemTaskActionResult({
    required this.status,
    this.rewardGemsCent,
    this.balanceCent,
    this.ledgerId = '',
  });

  factory GemTaskActionResult.fromJson(Map<String, dynamic> json) {
    return GemTaskActionResult(
      status: asString(json['status']),
      rewardGemsCent: json['reward_gems_cent'] == null
          ? null
          : asInt(json['reward_gems_cent']),
      balanceCent: json['balance_cent'] == null
          ? null
          : asInt(json['balance_cent']),
      ledgerId: asString(json['ledger_id']),
    );
  }

  final String status;
  final int? rewardGemsCent;
  final int? balanceCent;
  final String ledgerId;
}
