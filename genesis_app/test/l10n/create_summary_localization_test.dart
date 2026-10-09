import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/l10n/app_localizations_en.dart';

void main() {
  test('Create and Edit Worldo summary templates preserve visible English', () {
    final en = AppLocalizationsEn();

    expect(en.createWorldoTitle, 'Create Worldo');
    expect(en.createFailed, 'Create failed');
    expect(en.createNotesRequired, 'Update notes are required to publish.');
    expect(en.createActionInProgress, 'This action is already in progress.');
    expect(en.createCurrentVersion(version: 'V2'), 'Current Version: V2');
    expect(en.createChecking, 'Checking...');
    expect(en.createNotStartedYet, 'Not started yet');
    expect(en.createSummaryName(name: '#World'), 'Worldo Name: #World');
    expect(en.createSummaryBrief(brief: 'Story'), 'Worldo Brief: Story');
    expect(
      en.createSummaryCover(status: en.createNotUploaded),
      'Cover Image: Not uploaded',
    );
    expect(
      en.createSummaryCover(status: en.createUploaded),
      'Cover Image: Uploaded',
    );
    expect(
      en.createSummarySettings(settings: 'Rules'),
      'Worldo Settings: Rules',
    );
    expect(en.createSummaryTime(time: 'Today'), 'Worldo Time: Today');
    expect(en.createSummaryMetric(metric: 'XP'), 'Worldo Metric: XP');
    expect(en.createDays(count: 1), '1 day');
    expect(en.createDays(count: 3), '3 days');
    expect(en.createSummaryNoCharacters, '0 characters');
    expect(
      en.createSummaryCharacters(count: 2, names: 'Ada, Bob'),
      '2 characters: Ada, Bob',
    );
    expect(en.createSummarySuggested(name: 'Ada'), 'Suggested: Ada');
    expect(en.createSummaryRegion(count: 1), 'L1 · Region : 1');
    expect(en.createSummaryBuilding(count: 2), 'L2 · Building : 2');
    expect(en.createSummaryRoom(count: 3), 'L3 · Room : 3');
    expect(en.createSummaryEvents(count: 4), '4 events');
    expect(en.createSummaryDialogue(count: 1), 'Character dialogue : 1');
    expect(en.createSummaryNarrator(count: 2), 'Narrator : 2');
    expect(en.createSummaryImage(count: 3), 'Image : 3');
    expect(en.inboxNewFollowers, 'New followers');
  });
}
