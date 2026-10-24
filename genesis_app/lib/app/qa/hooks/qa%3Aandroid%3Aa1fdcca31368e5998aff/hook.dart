import 'package:flutter/widgets.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';

bool observe(Element? root) =>
    root != null && textElements('Detail', root).isNotEmpty;
Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final d = await selection();
  return observe(selectedWorld(d.selectedId!));
}
