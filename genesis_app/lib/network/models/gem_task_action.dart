import '../json_utils.dart';

class GemTaskActionResult {
  const GemTaskActionResult({required this.status});

  factory GemTaskActionResult.fromJson(Map<String, dynamic> json) {
    return GemTaskActionResult(status: asString(json['status']));
  }

  final String status;
}
