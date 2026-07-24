const String discussIconAsset = 'assets/custom-icons/png/discuss.png';
const String searchIconAsset = 'assets/custom-icons/png/search_icon.png';

double customIconAssetRenderSize(String assetName, double baseSize) {
  return assetName == connectStatIconAsset ? baseSize + 2 : baseSize;
}

const String copyStatIconAsset = 'assets/custom-icons/svg/copy_icon.svg';
const String paragraphIconAsset = 'assets/custom-icons/svg/paragraph_icon.svg';
const String tickStatIconAsset = 'assets/custom-icons/svg/tick_icon.svg';
const String connectStatIconAsset = 'assets/custom-icons/svg/connect_icon.svg';
const String launchIconAsset = 'assets/custom-icons/svg/launch_icon.svg';
const String characterStatIconAsset =
    'assets/custom-icons/svg/ai_char_icon.svg';
const String locationChatCharacterIconAsset =
    'assets/custom-icons/svg/location_chat_ai_char_icon.svg';
const String userStatIconAsset = 'assets/custom-icons/svg/user_icon.svg';
const String createOriginBasicsIconAsset =
    'assets/custom-icons/svg/create_origin_basics.svg';
const String createOriginCharactersIconAsset =
    'assets/custom-icons/svg/create_origin_characters.svg';
const String createOriginOpeningIconAsset =
    'assets/custom-icons/svg/create_origin_opening.svg';
const String createOriginLocationsIconAsset =
    'assets/custom-icons/svg/create_origin_locations.svg';
const String createOriginStoryEventsIconAsset =
    'assets/custom-icons/svg/create_origin_story_events.svg';
const String refreshModifiedIconAsset = 'assets/custom-icons/svg/refresh_2.svg';

const double _characterIconBaseSize = 11;
const double _characterIconVisualSize = 13.75;
const double _characterIconVerticalOffset = -0.8;

double customCharacterIconRenderSize(double baseSize) {
  return baseSize * (_characterIconVisualSize / _characterIconBaseSize);
}

double customCharacterIconVerticalOffset(double baseSize) {
  return baseSize * (_characterIconVerticalOffset / _characterIconBaseSize);
}

const String bottomNavHomeIconAsset =
    'assets/custom-icons/svg/bottom_nav_home.svg';
const String bottomNavHomePressIconAsset =
    'assets/custom-icons/svg/bottom_nav_home_press.svg';
const String bottomNavOriginIconAsset =
    'assets/custom-icons/svg/bottom_nav_origin.svg';
const String bottomNavOriginPressIconAsset =
    'assets/custom-icons/svg/bottom_nav_origin_press.svg';
const String bottomNavCreateIconAsset =
    'assets/custom-icons/svg/bottom_nav_create.svg';
const String bottomNavMessagesIconAsset =
    'assets/custom-icons/svg/bottom_nav_messages.svg';
const String bottomNavMessagesPressIconAsset =
    'assets/custom-icons/svg/bottom_nav_messages_press.svg';
const String bottomNavMeIconAsset = 'assets/custom-icons/svg/bottom_nav_me.svg';
const String bottomNavMePressIconAsset =
    'assets/custom-icons/svg/bottom_nav_me_press.svg';
