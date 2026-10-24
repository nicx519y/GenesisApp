import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../bootstrap/app_services_scope.dart';
import '../../../bootstrap/service_registry.dart';
import '../../../config/app_config.dart';
import '../../../genesis_navigator.dart';
import '../../../../network/http_transport.dart';
import '../../../../network/models/world.dart';
import '../../qa_bridge.dart';
import '../../fixtures/http/mock_response_registry.dart' as responses;
import '../android%253Aworld.test_identity%253Avalue/identity.dart';
import '../android%253Aworld.mock_dataset%253Avalue/dataset.dart';
import '../android%253Aworld.selected.map_renderable%253Avalid/observation.dart';
import '../qa%253Aandroid%253Abf448f29b28c4fce0618/resource.dart' show WorldMembership;
import '../qa%253Aandroid%253A72754e52110558afc990/resource.dart' show WorldProgression;
import 'socket.dart';
import 'history.dart';
import 'map_fixture.dart';

class LocationChatResource {
  LocationChatResource(this.bridge);
  final QaBridge bridge;
  WorldDataset? dataset;
  WorldMembership? membership;
  WorldProgression? progression;
  LocationChatPeer? peer;
  AppConfig? beforeConfig;
  AppServices? isolatedServices;
  bool servicesMounted=false, servicesReleased=false;
  responses.QaMockResponderRegistration? registration;
  String locationId = '', locationName = '', foreignLocationId = '';
  final knownId = 910001;
  String get knownContent => 'QA known location history ${bridge.resource}';
  String get snapshotId => 'location-chat:${bridge.resource}';
  bool identityAcquired = false, datasetAcquired = false, restored = false;
  Map<String, Object?>? receipt;
  final beforeHistory = <String, List<Map<String,dynamic>>>{};
  final beforeHttpHistory = <String, Object?>{};
  Route<void>? route;
  Route<dynamic>? previousRoute;
  BuildContext get context => genesisNavigatorKey.currentContext ?? (throw StateError('App navigator not ready'));
  AppServices get services => AppServicesScope.maybeRead(context) ?? (throw StateError('App scope not ready'));
  String get worldId => dataset!.selectedId!;
  String get owner => worldIdentityResource().uid;
  Future<void> requireOwner() async {
    if (restored || !identical(QaBridge.current,bridge) || dataset == null) throw StateError('No active location chat resource');
    await dataset!.requireOwner();
  }
  Map<String,dynamic> message(String id) => historyMessage(
    worldId:worldId, locationId:id,
    messageId:id == locationId ? knownId : knownId+1,
    content:id == locationId ? knownContent : 'QA foreign history ${bridge.resource}',
  );
  Future<Object?> httpHistory(String id) async => (await services.api.chatroomHttp.getMessages(worldId:worldId,locationId:id)).messages.map((m)=>m.rawJson).toList();
  Future<Map<String,Object?>> prepare() async {
    if (identityAcquired) throw StateError('Duplicate location chat preparation');
    if (const String.fromEnvironment('GENESIS_API_ENV') != 'mock') throw StateError('Mock environment required');
    beforeConfig = services.config;
    identityAcquired = true;
    await worldIdentityResource().prepare();
    dataset = await worldDatasetResource(acquire:true);
    try { await dataset!.prepare(); }
    finally { datasetAcquired = dataset!.active; }
    membership = WorldMembership(dataset!);
    progression = WorldProgression(dataset!);
    await membership!.prepare();
    await progression!.prepare();
    final world = await services.api.getWorld(worldId);
    final leaves = world.processedLocationTree.flattened.where((n)=>n.children.isEmpty && n.id != 'root').toList();
    if (leaves.length < 2) throw StateError('Mock world requires two distinct leaf locations');
    locationId = leaves[0].id;
    locationName = '${leaves[0].value['name'] ?? leaves[0].value['location_name'] ?? ''}';
    foreignLocationId = leaves[1].id;
    // The mock root map originally points at a non-leaf parent. Assign its
    // existing tile to the selected leaf within the owned dataset snapshot.
    final leafMap = leafMapJson(await dataset!.selected('map'), locationId);
    await dataset!.replace('map', ['map_json'], leafMap);
    if (locationName.isEmpty) throw StateError('Mock leaf has no name');
    for (final id in [locationId,foreignLocationId]) {
      beforeHistory[id] = (jsonDecode(jsonEncode(await services.chatroomMessages.loadLatestMessages(ownerUid:owner,worldId:worldId,locationId:id,limit:200))) as List).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
      beforeHttpHistory[id] = await httpHistory(id);
    }
    registration = responses.registerQaHook('qa:android:538adf49de88c951fcbe', respond);
    peer = LocationChatPeer(worldId,owner);
    await peer!.open();
    isolatedServices=ServiceRegistry.build(config:beforeConfig!.copyWith(chatroomWsBaseUrl:peer!.url),
      deviceIdOverride:services.deviceId,sessionStoreOverride:bridge.store,
      chatroomMessagesOverride:services.chatroomMessages);
    return read();
  }
  Future<TransportResponse?> respond(TransportRequest request) async {
    if (request.method != 'GET' || request.uri.queryParameters['world_id'] != worldId) return null;
    final path=request.uri.path;
    if (!['/aitown-chat/api/v2/messages','/aitown-chat/api/messages','/aitown-chat/internal/world/messages'].contains(path)) return null;
    await requireOwner();
    final id=request.uri.queryParameters['location_id'];
    if (id != null && id != locationId && id != foreignLocationId) return null;
    final messages=[message(locationId),message(foreignLocationId)];
    final data = path.endsWith('/internal/world/messages') ? {'locations':[for(final id in [locationId,foreignLocationId]) {'location_id':id,'messages':[legacyHistoryMessage(message(id))]}]} : {'messages':messages.where((m)=>m['location_id']==id).map((m)=>path.endsWith('/v2/messages')?m:legacyHistoryMessage(m)).toList(),'has_more':false,'newest_message_id':id==locationId?knownId:knownId+1};
    final body=jsonEncode({'err_no':0,'err_msg':'success','data':data});
    return TransportResponse(statusCode:200,headers:const {'content-type':'application/json'},body:body,bodyBytes:utf8.encode(body));
  }
  Future<Map<String,Object?>> read() async {
    await requireOwner();
    final WorldDetail world = await services.api.getWorld(worldId);
    final history=await services.api.chatroomHttp.getMessages(worldId:worldId,locationId:locationId);
    final leaf=world.processedLocationTree.nodeById(locationId);
    final identity=await worldIdentityResource().read();
    return {
      'source':'mock','snapshotId':snapshotId,'resource':bridge.resource,
      'worldId':world.worldId,'worldName':world.name,'locationAId':locationId,'locationAName':locationName,
      'knownMessageId':'$knownId','knownMessageContent':knownContent,
      'isolatedIdentity':identity['isolated'],'loggedIn':identity['loggedIn'],
      'joinedTargetWorld':world.relationStatus=='joined'||world.relationStatus=='owner',
      'worldIdPresent':world.worldId.isNotEmpty,'worldNamePresent':world.name.isNotEmpty,'currentTimePresent':world.currentTime.isNotEmpty,
      'mapDisplayable':extractObservation(await dataset!.selected('map')),
      'locationALeaf':leaf!=null&&leaf.children.isEmpty,
      'locationAChatAvailable':leaf!=null&&leaf.children.isEmpty&&(world.relationStatus=='joined'||world.relationStatus=='owner'),
      'knownLocationAHistoryPresent':history.messages.any((m)=>m.globalMessageId==knownId && m.content==knownContent && m.locationId==locationId),
      'worldAdvancing':world.isProgressing,'chatConnectionAvailable':await peer?.probe()??false,
    };
  }
  Future<Map<String,Object?>> restore() async {
    if (!identityAcquired || !identical(QaBridge.current,bridge)) throw StateError('No owned chat snapshot');
    if (restored) return receipt!;
    final ownedRoute=route;
    if (ownedRoute?.isActive==true) {
      if (!ownedRoute!.isCurrent) throw StateError('Foreign route above owned world');
      ownedRoute.navigator!.removeRoute(ownedRoute);
      await WidgetsBinding.instance.endOfFrame;
      servicesReleased=true;
    }
    if(!servicesMounted&&!servicesReleased&&isolatedServices!=null) { isolatedServices!.dispose(); servicesReleased=true; }
    final historyActual=<String,Object?>{};
    if(dataset!=null) {
      await dataset!.requireOwner();
      for(final id in beforeHistory.keys) {
        await services.chatroomMessages.replaceMessages(ownerUid:owner,worldId:worldId,locationId:id,messages:beforeHistory[id]!);
        historyActual[id]=await services.chatroomMessages.loadLatestMessages(ownerUid:owner,worldId:worldId,locationId:id,limit:200);
      }
    }
    registration?.close(); registration=null;
    final httpActual=<String,Object?>{};
    for(final id in beforeHttpHistory.keys) { httpActual[id]=await httpHistory(id); }
    if(peer?.acquired==true) await peer!.close();
    final config=beforeConfig;
    // Dataset owns the original responses, including membership/progression.
    // Release that snapshot even if a field preparation failed halfway.
    final worldResult=datasetAcquired?await dataset!.restore():<String,Object?>{'acquired':false,'matchesSnapshot':null};
    final identityResult=await worldIdentityResource().restore();
    const equality=DeepCollectionEqualityForWorld();
    final historyMatches=equality.equal(historyActual,beforeHistory)&&equality.equal(httpActual,beforeHttpHistory);
    final connectionMatches=identical(services.config,config)&&(peer==null||!peer!.acquired||peer!.closed)&&(isolatedServices==null||servicesReleased);
    receipt={
      'snapshotId':snapshotId,'resource':bridge.resource,'restoredIdentity':identityResult,'restoredWorld':worldResult,
      'restoredHistory':{'cache':historyActual,'http':httpActual},
      'restoredConnectionConfiguration':{'wsUrl':services.config.chatroomWsBaseUrl,'peerClosed':peer?.closed},
      'identityMatchesSnapshot':identityResult['matchesSnapshot'],'worldMatchesSnapshot':worldResult['matchesSnapshot'],
      'historyMatchesSnapshot':historyMatches,'connectionConfigurationMatchesSnapshot':connectionMatches,
    };
    if(!historyMatches||!connectionMatches||(datasetAcquired&&worldResult['matchesSnapshot']!=true)||identityResult['matchesSnapshot']!=true) throw StateError('Location chat restoration mismatch');
    restored=true;
    return receipt!;
  }
}
final resources=Expando<LocationChatResource>();
LocationChatResource resource({bool acquire=false}) {
  final bridge=QaBridge.current;
  if(bridge==null || const String.fromEnvironment('GENESIS_API_ENV')!='mock') throw StateError('Authenticated mock session required');
  final old=resources[bridge];
  if(old!=null) return old;
  if(!acquire) throw StateError('Location chat preparation required');
  return resources[bridge]=LocationChatResource(bridge);
}
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
  if(!started||p.length!=1) throw StateError('Ready parameterless operation required');
  if(p['operation']=='read') return resource().read();
  if(prepared) throw StateError('Case preparation cannot use contract session');
  return switch(p['operation']) {'prepare'=>resource(acquire:true).prepare(),'cleanup'=>resource().restore(),_=>throw ArgumentError('Unsupported operation')};
}
Future<Object?> contract(Map<String,dynamic> p,bool prepared,bool started) async {
  if(!prepared||!started||p.length!=1) throw StateError('Started isolated contract required');
  return switch(p['operation']) {'prepare'=>resource(acquire:true).prepare(),'read'=>resource().read(),'restore'=>resource().restore(),_=>throw ArgumentError('Unsupported contract operation')};
}
