import 'package:flutter/widgets.dart';
import '../android%253Amessages.private.empty_state%253Avisible/observer.dart';

Future<Object?> readEmptyText(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (p.isNotEmpty) throw ArgumentError('Expected parameterless read');
  if (!started) return '';
  final elements = emptyStateElements();
  if (elements.length > 1) throw StateError('Ambiguous empty state');
  if (elements.isEmpty) return '';
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text) {
      texts.add(w.data ?? w.textSpan!.toPlainText());
      return;
    }
    e.visitChildren(visit);
  }

  visit(elements.single);
  if (texts.length != 1) throw StateError('Ambiguous empty state text');
  return texts.single;
}
