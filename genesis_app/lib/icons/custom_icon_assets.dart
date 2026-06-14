const String discussIconAsset = 'assets/custom-icons/png/discuss.png';
const String searchIconAsset = 'assets/custom-icons/png/search_icon.png';

double customIconAssetRenderSize(String assetName, double baseSize) {
  return assetName == connectStatIconAsset ? baseSize + 2 : baseSize;
}

const String copyStatIconAsset = 'assets/custom-icons/svg/copy_icon.svg';
const String tickStatIconAsset = 'assets/custom-icons/svg/tick_icon.svg';
const String connectStatIconAsset = 'assets/custom-icons/svg/connect_icon.svg';
const String characterStatIconAsset =
    'assets/custom-icons/svg/ai_char_icon.svg';
const String userStatIconAsset = 'assets/custom-icons/svg/user_icon.svg';

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
    'assets/custom-icons/png/bottom_nav_home.png';
const String bottomNavHomePressIconAsset =
    'assets/custom-icons/png/bottom_nav_home_press.png';
const String bottomNavOriginIconAsset =
    'assets/custom-icons/png/bottom_nav_origin.png';
const String bottomNavOriginPressIconAsset =
    'assets/custom-icons/png/bottom_nav_origin_press.png';
const String bottomNavCreateIconAsset =
    'assets/custom-icons/png/bottom_nav_create.png';
const String bottomNavMessagesIconAsset =
    'assets/custom-icons/png/bottom_nav_messages.png';
const String bottomNavMessagesPressIconAsset =
    'assets/custom-icons/png/bottom_nav_messages_press.png';
const String bottomNavMeIconAsset = 'assets/custom-icons/png/bottom_nav_me.png';
const String bottomNavMePressIconAsset =
    'assets/custom-icons/png/bottom_nav_me_press.png';
