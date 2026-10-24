import 'package:flutter/material.dart';
import '../../../../components/world_map.dart';
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart' show selectedWorld, elements, visible, validate;
import '../qa%253Aandroid%253A8f81866f11bb4803f54c/hook.dart' show targetHitTestable;
import '../qa%253Aandroid%253A538adf49de88c951fcbe/resource.dart';

/// Dispatch the existing rendered target's tap, never the navigation handler.
Map<String,Object?> tapLocation(Element? world,String id,String name) {
  if(world==null) throw StateError('Target world is not visible');
  final maps=elements(world).where((e)=>e.widget is WorldMap && visible(e)).toList();
  if(maps.length!=1) throw StateError('Expected one visible world map');
  final map=maps.single;
  final targets=labelTargets(map,name);
  final nodes=<WorldMapLocationNode>[];
  void flatten(List<WorldMapLocationNode> items){for(final n in items){nodes.add(n);flatten(n.children);}}
  flatten((map.widget as WorldMap).common.locationNodes);
  final matching=nodes.where((n)=>n.id==id&&n.point.name==name&&n.children.isEmpty).toList();
  if(matching.length!=1||targets.length!=1) throw StateError('Location entry absent, obscured, or ambiguous');
  targets.values.single();
  return {'action':'tap','targetLocationMatches':matching.single.id==id,'dispatched':true,'locationId':id};
}
/// Tilemap text is an IgnorePointer sibling of its gesture surface. Match
/// the existing keyed bubble body first; legacy map labels use text ancestors.
Map<Element,VoidCallback> labelTargets(Element root,String name) {
  final keyed=elements(root).where((e)=>e.widget.key==ValueKey<String>('tile-location-bubble-body-$name')&&visible(e)).toList();
  final labels=keyed.isNotEmpty?keyed:elements(root).where((e)=>e.widget is Text&&(e.widget as Text).data==name&&visible(e)).toList();
  final targets=<Element,VoidCallback>{};
  for(final e in labels) {
    e.visitAncestorElements((a) {
      if(identical(a,root)) return false;
      final w=a.widget;
      final VoidCallback? callback=w is GestureDetector?w.onTap:w is InkWell?w.onTap:w is ButtonStyleButton?w.onPressed:null;
      if(callback!=null) {if(targetHitTestable(a))targets[a]=callback;return false;}
      return true;
    });
  }
  return targets;
}
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
  validate(p,started,'interact');final r=resource();await r.requireOwner();
  return tapLocation(selectedWorld(r.worldId),r.locationId,r.locationName);
}
