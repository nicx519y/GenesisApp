import 'dart:convert';
/// Preserve actual map geometry/assets and isolate only its chat entry target.
Map<String,dynamic> leafMapJson(Map<String,dynamic> raw, String locationId) {
 if(locationId.isEmpty) throw ArgumentError('Leaf location required');
 final map=jsonDecode(jsonEncode(raw['map_json']));
 if(map is! Map<String,dynamic> || map['tiles'] is! List || (map['tiles'] as List).isEmpty) throw StateError('Displayable mock map required');
 final tiles=map['tiles'] as List;
 for(final tile in tiles) {if(tile is! Map) throw StateError('Invalid map tile');tile.remove('location_id');}
 (tiles.first as Map)['location_id']=locationId;
 return map;
}
