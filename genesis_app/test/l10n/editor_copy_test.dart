import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();

  test('editor validation keeps the existing English wording', () {
    expect(en.createBasicsNameRequired, 'Worldo Name is required.');
    expect(
      en.createCharacterNameRequired(index: 2),
      'Character 2: Name is required.',
    );
    expect(
      en.createLocationL2NameNeeded(locationLabel: '"Downtown"'),
      '"Downtown" has an L2 location that needs a name.',
    );
    expect(
      en.createLocationRoomsFull(count: 15),
      "You've used all 15 rooms. Delete one to add another.",
    );
    expect(
      en.createLocationDeleteBubbles(count: 1),
      'Saving Locations will also delete 1 Opening dialogue bubble '
      'for the removed characters.',
    );
    expect(
      en.createLocationDeleteBubbles(count: 3),
      'Saving Locations will also delete 3 Opening dialogue bubbles '
      'for the removed characters.',
    );
  });

  test('share invitation keeps the existing line breaks and URL', () {
    expect(
      en.worldInviteText(
        worldName: 'Dream Bazaar',
        wid: 'w_123',
        downloadUrl: 'https://worldo.ai/download',
      ),
      'Join my world "Dream Bazaar" on Worldo!\n'
      'w_123\n'
      'Search this WID on Worldo to find and join.\n'
      'https://worldo.ai/download',
    );
  });
}
