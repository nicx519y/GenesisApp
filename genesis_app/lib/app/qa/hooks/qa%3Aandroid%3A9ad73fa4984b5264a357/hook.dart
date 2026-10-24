import 'package:flutter/material.dart';
import '../../../../components/home/world_item_card.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';

final origins = Expando<Route<dynamic>>();
bool matchesCard(Widget w, String id) =>
    id.isNotEmpty && w is WorldItemCard && w.item.wid == id;
VoidCallback? cardAction(Element e) {
  VoidCallback? result;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is InkWell) {
      result = w.onTap;
      return false;
    }
    if (w is GestureDetector) {
      result = w.onTap;
      return false;
    }
    return true;
  });
  return result;
}

Element? entryCard(String id) {
  final found = elements()
      .where(
        (e) =>
            matchesCard(e.widget, id) &&
            visible(e) &&
            ModalRoute.of(e)?.isCurrent == true &&
            cardAction(e) != null,
      )
      .toList();
  if (found.length > 1) throw StateError('Ambiguous selected world entry');
  return found.isEmpty ? null : found.single;
}

Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'read');
  final d = await selection();
  final card = entryCard(d.selectedId!);
  if (card == null) return false;
  final original = origins[d];
  // Preserve the first origin; reads never move the user or replace it.
  final route = ModalRoute.of(card);
  if (route == null) return false;
  if (original == null) origins[d] = route;
  return identical(origins[d], route);
}

bool atOrigin(WorldDataset d) {
  final original = origins[d];
  final card = entryCard(d.selectedId!);
  return original != null &&
      original.isCurrent &&
      card != null &&
      identical(ModalRoute.of(card), original);
}
