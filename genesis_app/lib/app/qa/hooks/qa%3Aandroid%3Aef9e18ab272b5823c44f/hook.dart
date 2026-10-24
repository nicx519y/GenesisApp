import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart' show resource;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started || p.length != 1 || p['operation'] != 'restore')
    throw ArgumentError('Ready parameterless restore required');
  return resource().restore();
}
