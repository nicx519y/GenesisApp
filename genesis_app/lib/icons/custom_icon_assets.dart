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
