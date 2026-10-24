import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';

Object? extractObservation(Map<String, dynamic> raw) =>
    raw['info'] is Map ? raw['info']['world_name'] : null;
Future<Object?> observeSelectedName(
  Map<String, dynamic> parameters,
  bool prepared,
  bool started,
) async {
  if (parameters.isNotEmpty)
    throw ArgumentError('Selected world observation takes no parameters');
  final resource = await worldDatasetResource();
  return extractObservation(await resource.selected('detail'));
}
