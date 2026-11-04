# Shared memory UI subtask — handoff

- Workspace: `C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103`.
- Branch/base: `feature/global-memory-deluxe-20261103`, `8d0062581117513aeefe9dc507759e4347a4cd18`, upstream `origin/main`.
- No commit/push; only this subtask's files were edited. World/MiniPhone/router/Developer, membership components, ARB/generated l10n, pubspec and the parent checkpoint belong to other agents and were not edited here.

## Delivered

- `genesis_app/lib/components/world_memory/world_memory.dart`: requested public content widget; exports pure model types only. All strings use `context.l10n`; 14/12 typography and 1.4 line height use existing dark tokens.
- `world_memory_models.dart`: const empty/default snapshots, `copyWith(summary: ...)`, typed events/cast/relations, independently supplied membership booleans. No DTO/network/store assumptions.
- `world_memory_recap.dart`: independent Timeline/Deluxe and Summary/Premium checks; stable newest-first capped 10 events; full latest summary or authorized `summaryContent` override.
- `world_memory_cast.dart`: World expands at most one profile; Phone opens a separate detail body and returns to Cast without taking over the parent's close button. Empty form rows/groups hidden; updated fields; departed/dead profiles at end, grayscale, status and Last seen. Phone also shows Right now/Toward you.
- `world_memory_bonds.dart`: two groups, relationship list rows, paired portraits and dashed empty prompts.
- `world_memory_common.dart`: structural-only locked views, no data-backed avatars/text/semantics. Shared membership offer stays at the bottom with bounded independent scrolling on short/large-text surfaces.
- `world_memory_preview_data.dart`: explicit Developer-only `WorldMemoryPreviewData.live()`, `.fresh()`, `.departures()`; NOT exported by the production barrel. Five real offline reference portraits in `genesis_app/assets/world_memory_preview/`. Parent confirmed adding the assets directory to pubspec. Shared GenesisCharacterAvatar/GenesisAvatar now supports local assets; no avatar code copied.
- `memory-strings.json`: 47 source messages, all 47 have descriptions; includes `memoryCast`/`memoryBonds`. Parent owns translation/generation/check.
- `memory-ui-interface.md`: stable integration contract.

## Actual verification

Tests were written before implementation. First red run failed on absent model, then model tests passed while widget tests failed on absent view; no existing UI was used as the implementation under test.

Final command (SDK cache access required escalation):

```powershell
& 'C:/dev/flutter/bin/cache/dart-sdk/bin/dart.exe' 'C:/dev/flutter/bin/cache/flutter_tools.snapshot' test --no-pub test/components/world_memory
```

Result: **25 passed, exit 0**, including independent ownership combinations, locked content and semantics, exact tier callbacks, latest 10 ordering, full summary/override, empty/setup/departed/dead states, single expansion, separate Phone detail/back, actual local asset providers, external controller ownership, entitlement revocation and 280/350/390 widths at 1.5x text scale. Initial three semantics tests had a test-owned SemanticsHandle cleanup timing error; fixed with try/finally and final run passed all three.

Formatting completed for this subtask's Dart files. `git diff --check` exit 0. JSON parsed successfully: 47 keys, 0 missing descriptions. Static inspection found no service/HTTP imports or production references to preview data in the memory UI directory.

Focused analyzer first completed with one unused optional parameter and three brace-style findings; all four were corrected. Its final rerun was **canceled at the parent's explicit request** while still running; do not claim a final analyzer pass. Only the exact memory-scoped analyzer and its descendants were stopped. No additional analyze/test command is running from this subtask after handoff.

## Parent-owned remaining validation

Full changed-scope integration checks, l10n check, representative screenshot review, and final Debug build. This subtask does not claim true-device or pixel-level visual acceptance. New memory production data stays empty until the parent supplies a verified adapter; no example fallback or global membership override exists.
