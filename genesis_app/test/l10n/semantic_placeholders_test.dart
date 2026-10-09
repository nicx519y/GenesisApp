import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations_en.dart';

void main() {
  test('renamed placeholders preserve the existing English copy', () {
    final en = AppLocalizationsEn();

    expect(
      en.searchOIDCreatorOriginatorBrief(
        oid: 'O1',
        originator: 'Ada',
        brief: 'Brief',
        version: 'V2',
      ),
      r'OID: O1  Creator: Ada'
      '\n'
      r'Brief: Brief'
      '\n'
      r'Latest Version: V2',
    );
    expect(en.searchWIDOwner(wid: 'W1', owner: 'Ada'), 'WID: W1\nOwner: Ada');
    expect(en.worldActionFailed(actionLabel: 'Request'), 'Request failed');
    expect(en.worldoDetailCreator(creatorName: 'Ada'), 'Creator: Ada');
    expect(
      en.worldoDetailTickCountSubLabel(
        tickCount: '3',
        subTickLabel: '-2',
        messageCountLabel: '12 messages',
      ),
      'Tick 3-2 · 12 messages',
    );
    expect(en.worldoViewAllReplies(replyCount: '4'), 'View all 4 replies');
    expect(en.worldoDiscuss(discussCount: '5'), 'Discuss (5)');
    expect(
      en.createCharacterCharactersName(characterIndex: '2'),
      'Characters #2: Name is required.',
    );
    expect(
      en.createCharacterCharacters(characterIndex: '2'),
      'Characters #2: Identity is required.',
    );
    expect(
      en.createCharacterRequired(characterIndex: '2'),
      'Characters #2: Personality is required.',
    );
    expect(
      en.createLocationLocationsLocation(locationIndex: '3'),
      'Locations #3: Location Name is required.',
    );
    expect(en.meUID(uid: '123'), 'UID: 123');
    expect(
      en.worldDetailTickCount(tickCount: '5', subTickSuffix: '-2'),
      'Tick 5-2',
    );
    expect(
      en.worldDetailItemTickNumber(tickNumber: '5', subTickSuffix: '-2'),
      'Tick 5-2',
    );
    expect(
      en.worldDetailHeaderTickNumber(
        tickNumber: '5',
        subTickSuffix: '-2',
        dateSuffix: ' · Today',
      ),
      'Tick 5-2 · Today',
    );
    expect(
      en.worldFirstTickGenerating(progressDots: '...'),
      'LLM is generating your first tick. This may take a moment...',
    );
    expect(
      en.worldoLatestVersion(version: '3', ageSuffix: ' · Today'),
      'Latest Version: V3 · Today',
    );
    expect(
      en.createSaveBeforeCreating(missingSections: 'Characters, Locations'),
      'Please save Characters, Locations before creating.',
    );
    expect(
      en.inboxJoinRequestTitle(world: 'Worldo', worldIdSuffix: '(W1)'),
      'request to Worldo(W1)',
    );
  });
}
