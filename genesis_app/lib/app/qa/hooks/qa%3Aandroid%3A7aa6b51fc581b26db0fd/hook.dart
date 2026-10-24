import '../../../../components/chat/shared/chat_ui.dart';
import '../qa%253Aandroid%253A00d17d4c0a87395ebbd3/hook.dart' show activePanel;
import '../qa%253Aandroid%253A348c585f9fb3ee755d5c/hook.dart' show validate;
import '../qa%253Aandroid%253A4e9bddbcfd11e06f535a/hook.dart' show displayedMessages;
import '../qa%253Aandroid%253A538adf49de88c951fcbe/resource.dart';
/// Unknown provenance is retained as a mismatch; it cannot become an empty pass.
List<Map<String,Object?>> foreignRows(Iterable<ChatMessageVm> rows,Map<int,String> origins,String locationId) => [
  for(final m in rows)
    if(!m.isAiContentDisclaimer && origins[m.globalMessageId]!=locationId)
      {'messageId':'${m.globalMessageId}','locationId':origins[m.globalMessageId],'content':m.text}
];
Future<Object?> invoke(Map<String,dynamic> p,bool prepared,bool started) async {
  validate(p,started,'read');final r=resource();await r.requireOwner();
  return foreignRows(displayedMessages(activePanel()),{r.knownId:r.locationId,r.knownId+1:r.foreignLocationId},r.locationId);
}
