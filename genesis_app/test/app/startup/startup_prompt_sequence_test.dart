import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/app/startup/startup_prompt_sequence.dart';

void main() {
  test('login ownership does not change privacy and ATT stages', () {
    final sequence = StartupPromptSequence();
    addTearDown(sequence.dispose);
    final owner = Object();
    sequence.begin();
    sequence.blockForLogin(owner);
    sequence.finishPrivacy();
    sequence.finishAtt();
    expect(sequence.value, StartupPromptStage.ready);
    expect(sequence.blocksOtherPrompts, isTrue);
    sequence.releaseLogin(owner);
    expect(sequence.blocksOtherPrompts, isFalse);

    sequence.begin();
    sequence.blockForLogin(owner);
    sequence.releaseLogin(owner);
    expect(sequence.waitingForPrivacy, isTrue);
    expect(sequence.blocksOtherPrompts, isTrue);
  });

  test('privacy completes before ATT can release other prompts', () {
    final sequence = StartupPromptSequence();
    addTearDown(sequence.dispose);
    final stages = <StartupPromptStage>[];
    sequence.addListener(() => stages.add(sequence.value));
    sequence.begin();
    sequence.finishAtt();
    expect(sequence.waitingForPrivacy, isTrue);
    expect(sequence.blocksOtherPrompts, isTrue);
    sequence.finishPrivacy();
    expect(sequence.waitingForPrivacy, isFalse);
    expect(sequence.blocksOtherPrompts, isTrue);
    sequence.finishAtt();
    expect(sequence.blocksOtherPrompts, isFalse);
    expect(stages, [
      StartupPromptStage.privacy,
      StartupPromptStage.att,
      StartupPromptStage.ready,
    ]);
    sequence.finishPrivacy();
    sequence.finishAtt();
    expect(stages, hasLength(3));
  });
}
