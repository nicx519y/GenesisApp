import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_action_state.dart';
import 'package:genesis_flutter_android/features/location_chat_reply/shared/reply_controls_snapshot.dart';

const _all = (regenerate: true, goOn: true, edit: true, inspiration: true);
const _none = (regenerate: false, goOn: false, edit: false, inspiration: false);

LocationChatReplyControlsSnapshot _resolve({
  bool hidden = false,
  bool blocked = false,
  bool prepared = true,
  LocationChatReplyActionFlags supported = _all,
  LocationChatReplyActionFlags busy = _none,
  LocationChatReplyActionFlags active = _none,
  bool rendered = false,
  bool limit = false,
}) => resolveLocationChatReplyControls(
  hidden: hidden,
  blocked: blocked,
  showWhenUnavailable: prepared,
  supported: supported,
  canInvoke: _all,
  busy: busy,
  active: active,
  regenerationContentRendering: rendered,
  regenerateLimitReached: limit,
);

void main() {
  test(
    'silent edit quota check locks other actions without showing a spinner',
    () {
      final result = _resolve(
        active: (
          regenerate: false,
          goOn: false,
          edit: true,
          inspiration: false,
        ),
      );
      expect(result.edit, LocationChatReplyActionState.idle);
      expect(result.regenerate, LocationChatReplyActionState.disabled);
      expect(result.goOn, LocationChatReplyActionState.disabled);
      expect(result.inspiration, LocationChatReplyActionState.disabled);
    },
  );

  test(
    'an accepted action remains busy when its old capability disappears',
    () {
      final result = _resolve(
        blocked: true,
        supported: _none,
        busy: (regenerate: false, goOn: true, edit: false, inspiration: false),
      );
      expect(result.goOn, LocationChatReplyActionState.busy);
      expect(result.edit, LocationChatReplyActionState.none);
    },
  );

  test(
    'rendered regeneration content retires its spinner before generation ends',
    () {
      final result = _resolve(
        rendered: true,
        busy: (regenerate: true, goOn: false, edit: false, inspiration: false),
        active: (
          regenerate: true,
          goOn: false,
          edit: false,
          inspiration: false,
        ),
      );
      expect(result.regenerate, LocationChatReplyActionState.disabled);
      expect(result.goOn, LocationChatReplyActionState.disabled);
      expect(result.canExplainRegenerateLimit, isFalse);
    },
  );

  test(
    'card limit keeps the disabled slot and explains only when unblocked',
    () {
      final result = _resolve(limit: true, supported: _none);
      expect(result.regenerate, LocationChatReplyActionState.disabled);
      expect(result.canExplainRegenerateLimit, isTrue);
      expect(
        _resolve(limit: true, blocked: true).canExplainRegenerateLimit,
        isFalse,
      );
      expect(
        _resolve(
          limit: true,
          active: (
            regenerate: false,
            goOn: false,
            edit: true,
            inspiration: false,
          ),
        ).canExplainRegenerateLimit,
        isFalse,
      );
    },
  );

  test('tick or accepted Go on hides all actions even during a request', () {
    final result = _resolve(hidden: true, busy: _all, limit: true);
    expect([
      result.regenerate,
      result.goOn,
      result.edit,
      result.inspiration,
    ], everyElement(LocationChatReplyActionState.none));
    expect(result.canExplainRegenerateLimit, isFalse);
  });

  test(
    'prepared entry retains unavailable supported slots; legacy entry hides them',
    () {
      final prepared = _resolve(blocked: true);
      final legacy = _resolve(blocked: true, prepared: false);
      expect([
        prepared.regenerate,
        prepared.goOn,
        prepared.edit,
        prepared.inspiration,
      ], everyElement(LocationChatReplyActionState.disabled));
      expect([
        legacy.regenerate,
        legacy.goOn,
        legacy.edit,
        legacy.inspiration,
      ], everyElement(LocationChatReplyActionState.none));
    },
  );
}
