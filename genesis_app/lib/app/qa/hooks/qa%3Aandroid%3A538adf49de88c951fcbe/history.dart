/// Wire fixtures follow the real HTTP parsers, not legacy WebSocket aliases.
Map<String,dynamic> historyMessage({required String worldId, required String locationId,
  required int messageId, required String content}) => {
  'type':'user','world_id':worldId,'location_id':locationId,
  'global_message_id':messageId,'message_id':messageId,'location_message_id':messageId,
  'conversation_round_id':1,'conversation_type':'user_message','ts':1700000000000,
  'sender_type':'user','sender_id':'qa-history-author','sender_name':'QA Historian',
  'user_id':'qa-history-author','message_type':'text',
  'payload':{'content':content},
};
Map<String,dynamic> legacyHistoryMessage(Map<String,dynamic> message) => {
  ...message, 'content':(message['payload'] as Map)['content'],
  'created_at':'2023-11-14T22:13:20.000Z',
};
