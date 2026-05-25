const Map<String, Map<String, dynamic>> kMockWorlds = {
  'wid_mock_001': {
    'wid': 'wid_mock_001',
    'display_wid_str': 'W_MOCK_001',
    'world_name': 'Steam Kingdom',
    'worldview_id': 'wv_mock_steam',
    'owner_user_id': 'u_mock_001',
  },
};

const Map<String, int> kMockTickByWorld = {'wid_mock_001': 1240};

const List<Map<String, dynamic>> kMockWorldMapPositions = [
  {
    'location_id': 'loc_hub',
    'location_name': 'Central Hub',
    'point_id': 'pt_hub',
    'x_percent': 30.0,
    'y_percent': 45.0,
    'image': '',
    'character_ids': ['c_1', 'c_3', 'c_4'],
  },
  {
    'location_id': 'loc_gate',
    'location_name': 'Rail Gate',
    'point_id': 'pt_gate',
    'x_percent': 70.0,
    'y_percent': 35.0,
    'image': '',
    'character_ids': ['c_2', 'c_5', 'c_6', 'c_7'],
  },
  {
    'location_id': 'loc_market',
    'location_name': 'Brass Market',
    'point_id': 'pt_market',
    'x_percent': 47.0,
    'y_percent': 58.0,
    'image': '',
    'character_ids': ['c_8', 'c_9', 'c_10', 'c_11', 'c_12'],
  },
  {
    'location_id': 'loc_underworks',
    'location_name': 'Underworks',
    'point_id': 'pt_underworks',
    'x_percent': 22.0,
    'y_percent': 68.0,
    'image': '',
    'character_ids': ['c_13', 'c_14'],
  },
  {
    'location_id': 'loc_airdock',
    'location_name': 'Airdock Nine',
    'point_id': 'pt_airdock',
    'x_percent': 78.0,
    'y_percent': 60.0,
    'image': '',
    'character_ids': ['c_15'],
  },
];

const List<Map<String, dynamic>> kMockCharactersFull = [
  {
    'id': 'c_1',
    'name': 'Iris Vale',
    'avatar_url': 'assets/images/mock_avatars/avatar_iris.png',
    'location_id': 'loc_hub',
  },
  {
    'id': 'c_2',
    'name': 'Marshal Crow',
    'avatar_url': 'assets/images/mock_avatars/avatar_crow.png',
    'location_id': 'loc_gate',
  },
  {
    'id': 'c_3',
    'name': 'Lena North',
    'avatar_url': 'assets/images/mock_avatars/avatar_lena.png',
    'location_id': 'loc_hub',
  },
  {
    'id': 'c_4',
    'name': 'Toma Reed',
    'avatar_url': 'assets/images/mock_avatars/avatar_toma.png',
    'location_id': 'loc_hub',
  },
  {
    'id': 'c_5',
    'name': 'Orren Pike',
    'avatar_url': 'assets/images/mock_avatars/avatar_orren.png',
    'location_id': 'loc_gate',
  },
  {
    'id': 'c_6',
    'name': 'Nia Sable',
    'avatar_url': 'assets/images/mock_avatars/avatar_nia.png',
    'location_id': 'loc_gate',
  },
  {
    'id': 'c_7',
    'name': 'Jules Quill',
    'avatar_url': 'assets/images/mock_avatars/avatar_jules.png',
    'location_id': 'loc_gate',
  },
  {
    'id': 'c_8',
    'name': 'Mira Kest',
    'avatar_url': 'assets/images/mock_avatars/avatar_mira.png',
    'location_id': 'loc_market',
  },
  {
    'id': 'c_9',
    'name': 'Finn Copper',
    'avatar_url': 'assets/images/mock_avatars/avatar_orren.png',
    'location_id': 'loc_market',
  },
  {
    'id': 'c_10',
    'name': 'Senna Volt',
    'avatar_url': 'assets/images/mock_avatars/avatar_lena.png',
    'location_id': 'loc_market',
  },
  {
    'id': 'c_11',
    'name': 'Bram Coil',
    'avatar_url': 'assets/images/mock_avatars/avatar_crow.png',
    'location_id': 'loc_market',
  },
  {
    'id': 'c_12',
    'name': 'Vale Ember',
    'avatar_url': 'assets/images/mock_avatars/avatar_iris.png',
    'location_id': 'loc_market',
  },
  {
    'id': 'c_13',
    'name': 'Rook Under',
    'avatar_url': 'assets/images/mock_avatars/avatar_toma.png',
    'location_id': 'loc_underworks',
  },
  {
    'id': 'c_14',
    'name': 'Elda Gear',
    'avatar_url': 'assets/images/mock_avatars/avatar_nia.png',
    'location_id': 'loc_underworks',
  },
  {
    'id': 'c_15',
    'name': 'Asha Skye',
    'avatar_url': 'assets/images/mock_avatars/avatar_mira.png',
    'location_id': 'loc_airdock',
  },
];

const List<Map<String, dynamic>> kMockPlayers = [
  {
    'api_user_id': 'u_mock_001',
    'user_name': 'Mock User',
    'display_name': 'Mock User',
  },
];
