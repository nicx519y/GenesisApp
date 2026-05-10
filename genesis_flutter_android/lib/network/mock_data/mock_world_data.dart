const Map<String, Map<String, dynamic>> kMockWorlds = {
  'wid_mock_001': {
    'wid': 'wid_mock_001',
    'display_wid_str': 'W_MOCK_001',
    'world_name': 'Steam Kingdom',
    'worldview_id': 'wv_mock_steam',
    'owner_user_id': 'u_mock_001',
  },
};

const Map<String, int> kMockTickByWorld = {'wid_mock_001': 3};

const List<Map<String, dynamic>> kMockWorldMapPositions = [
  {
    'location_id': 'loc_hub',
    'location_name': 'Central Hub',
    'point_id': 'pt_hub',
    'x_percent': 30.0,
    'y_percent': 45.0,
    'image': '',
  },
  {
    'location_id': 'loc_gate',
    'location_name': 'Rail Gate',
    'point_id': 'pt_gate',
    'x_percent': 70.0,
    'y_percent': 35.0,
    'image': '',
  },
];

const List<Map<String, dynamic>> kMockCharactersFull = [
  {'id': 'c_1', 'name': 'Iris Vale', 'avatar_url': ''},
  {'id': 'c_2', 'name': 'Marshal Crow', 'avatar_url': ''},
];

const List<Map<String, dynamic>> kMockPlayers = [
  {
    'api_user_id': 'u_mock_001',
    'user_name': 'Mock User',
    'display_name': 'Mock User',
  },
];
