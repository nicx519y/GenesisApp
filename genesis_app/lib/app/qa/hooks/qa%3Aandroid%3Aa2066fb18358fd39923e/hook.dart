import 'package:flutter/widgets.dart';
import '../../../../components/world_map.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

bool observe(Element? root, String id) =>
    root != null &&
    elements(
      root,
    ).any((e) => e.widget is WorldMap && id.isNotEmpty && visible(e));
Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final d = await selection();
  return observe(selectedWorld(d.selectedId!), d.selectedId!);
}
