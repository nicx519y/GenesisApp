import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../components/chat/shared/chat_ui.dart';
import '../qa%253Aandroid%253Afa6d6e9732df53bf7030/resource.dart';
import '../qa%253Aandroid%253A88f61b36d73b39e019fe/view.dart';
import '../qa%253Aandroid%253A049d4a0c0bcd1b89f6c0/hook.dart'
    show dispatchSingleTap;

const draftText = '父级地点测试草稿';

class DraftLease {
  DraftLease(this.editor, this.before);
  final EditableTextState editor;
  final TextEditingValue before;
  bool cleared = false;
  Future<String> clear() async {
    if (editor.mounted) {
      if (editor.widget.controller.text != draftText &&
          editor.widget.controller.text != before.text)
        throw StateError('Draft changed outside owned interaction');
      // Restoration owns this snapshot; it is not a keyboard event. The retained
      // composer may be read-only after returning to the world page.
      editor.widget.controller.value = before;
      if (editor.widget.controller.value != before)
        throw StateError('Draft restoration mismatch');
    }
    cleared = true;
    return editor.mounted ? editor.widget.controller.text : '';
  }
}

final drafts = Expando<DraftLease>();
Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  if (!started ||
      p.length != 1 ||
      !['interact', 'cleanup'].contains(p['operation']))
    throw ArgumentError('Expected draft interaction or cleanup');
  final r = resource();
  await r.requireOwner();
  if (p['operation'] == 'cleanup') {
    final d = drafts[r];
    if (d == null) throw StateError('No owned draft');
    return d.clear();
  }
  if (drafts[r] != null) throw StateError('Draft already acquired');
  final panel = parentPanel();
  if (panel == null) throw StateError('Parent panel required');
  final composers = elements(
    panel,
  ).where((e) => e.widget is ChatComposer && visible(e)).toList();
  if (composers.length != 1 ||
      (composers.single.widget as ChatComposer).inputEnabled != true)
    throw StateError('Editable parent composer required');
  final inputs = elements(composers.single)
      .where(
        (e) =>
            e is StatefulElement && e.state is EditableTextState && visible(e),
      )
      .toList();
  if (inputs.length != 1) throw StateError('Unique parent text input required');
  final e = inputs.single as StatefulElement,
      editor = (inputs.single as StatefulElement).state as EditableTextState;
  if (editor.widget.controller.text.isNotEmpty)
    throw StateError('Existing draft must not be overwritten');
  dispatchSingleTap(e);
  await WidgetsBinding.instance.endOfFrame;
  if (!editor.widget.focusNode.hasFocus)
    throw StateError('Parent input did not receive touch');
  final lease = DraftLease(editor, editor.widget.controller.value);
  drafts[r] = lease;
  r.restorers.add(() async {
    if (!lease.cleared) await lease.clear();
  });
  editor.updateEditingValue(
    const TextEditingValue(
      text: draftText,
      selection: TextSelection.collapsed(offset: draftText.length),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  return editor.widget.controller.text;
}
