# Shared memory UI interface (owned by memory UI subtask)

Import `package:genesis_flutter_android/components/world_memory/world_memory.dart`.

`WorldMemorySection { recap, cast, bonds }` and the requested `WorldMemoryView` signature are stable. The view is content-only: the parent owns the title/close/navigation chrome. It fills bounded height and owns a vertical scroll view, optionally using the supplied `scrollController` (never disposes it). Use a key containing world/account identity when switching sessions.

`const WorldMemorySnapshot.empty()` and `const WorldMemorySnapshot()` both contain empty `events`, `cast`, `relations`, and `summary: ''`. `snapshot.copyWith(summary: latestP5Body)` preserves the other lists. `summaryContent` overrides summary text/empty state only after the independent Premium check; use it for loading/error UI. No truncation or conversion of Summary into old ticks.

Pure data model, no store/DTO/service imports:
- `WorldMemoryEvent(id, timeLabel, order, body, participants = [], change = WorldMemoryChange.none)`. `order` is a comparable story chronology number supplied by the adapter (not inferred from human text). The view sorts descending, takes 10; ties preserve input order.
- `WorldMemoryPerson(id, name, avatarUrl = '', avatarAsset = '')`. Registered local `avatarAsset` takes precedence; the shared character avatar now supports assets. No image/service implementation is copied.
- `WorldMemoryCharacter(person, identity = '', isPlayer = false, status = WorldMemoryCharacterStatus.active, now = '', towardYou = '', fields = {}, updated = false)`.
- `fields` maps `WorldMemoryField` to `WorldMemoryValue(text, updated = false)`. Fields: age, gender, orientation, appearance, personality, background, likesDislikes, boundaries, goodToKnow, arc, definingMoment. Blank values/groups are omitted. Status is separately typed and rendered first for departed/dead profiles.
- `WorldMemoryRelation(id, group, from, to, body, updated = false)`, `WorldMemoryRelationGroup { towardPlayer, betweenCharacters }`.
- `WorldMemoryCharacterStatus { active, departed, dead }`; `WorldMemoryChange { none, added, updated }`.
- `WorldMemorySnapshot(..., bool hasStoryMemory = false)` allows the caller to indicate initial setup vs generated story memory for the Cast note. Lists/maps are read-only by convention; UI never mutates them.

Recap starts on Timeline for Deluxe owners, otherwise Summary. Both tabs remain available and check their own entitlement. Cast/Bonds check Deluxe. Lock skeletons never instantiate user content or real avatars. Subscription/details callbacks forward the exact target tier through `onSubscribe`.

Preview is a separate import `world_memory_preview_data.dart`, **not exported by world_memory.dart**: `WorldMemoryPreviewData.live()`, `.fresh()`, `.departures()`. Only Developer explicitly calls these factories and passes membership booleans to its own view. No automatic sample or membership fallback anywhere.

Five offline reference portraits are ready under `genesis_app/assets/world_memory_preview/`; parent must add `assets/world_memory_preview/` to pubspec assets. World expands at most one profile. Phone switches to a separate detail body with its own back-to-Cast action; parent close chrome remains owned by the host.

`memory-strings.json` is ready for parent l10n import/translation/generation. It contains only new ARB messages and descriptions; existing `recapEmpty` is reused. UI compilation awaits parent generation and the other subtask's `memory_membership_style.dart` / `memory_membership_offer_card.dart`.
