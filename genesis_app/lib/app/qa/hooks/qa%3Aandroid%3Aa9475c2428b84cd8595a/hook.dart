import 'package:flutter/widgets.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ae902ad40417a12b1d8e2/hook.dart' show success;
import '../qa%253Aandroid%253Ad43c9deee50740096afb/hook.dart' show browsing;

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final s = success();
  await s.owner.requireOwner();
  final panel = eventsPanel();
  final texts = panel == null
      ? <String>[]
      : elements(panel).where((e) => visible(e)).map((e) {
          final w = e.widget;
          return w is Text
              ? (w.data ?? w.textSpan?.toPlainText() ?? '')
              : w is RichText
              ? w.text.toPlainText()
              : '';
        }).toList();
  final b = browsing[s.owner];
  return {
    'contentReadable': texts.any(
      (t) => t.contains(s.content) && s.content.isNotEmpty,
    ),
    'browseSucceeded':
        b != null &&
        b.succeeded &&
        b.attempt == s.owner.attempt &&
        panel != null,
    'visibleTexts': texts.where((s) => s.isNotEmpty).toList(),
  };
}
