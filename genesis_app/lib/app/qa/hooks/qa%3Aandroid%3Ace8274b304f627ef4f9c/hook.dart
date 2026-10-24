import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart';
import 'package:flutter/widgets.dart';
import '../qa%253Aandroid%253A1cd4ae5d9b2c78255d2b/hook.dart';

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  await resource().requireOwner();
  final f = fault();
  if (f.firstResponse == null) return '';
  final notices = elements()
      .where((e) => e.widget is Text && visible(e))
      .map(
        (e) =>
            (e.widget as Text).data ??
            (e.widget as Text).textSpan?.toPlainText() ??
            '',
      )
      .where((s) => s == 'Tick now failed')
      .toList();
  return notices.isEmpty ? '' : notices.single;
}
