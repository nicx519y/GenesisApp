# MiniPhone team-branch review — 2026-10-18

## Scope and location
- User requested a local index of recent personal branches (pushed and unpushed), then fetching origin/miniphone and building a local preview package for continued UI review.
- New worktree: C:/Project/worldo/frontend-debug/GenesisApp-miniphone-review-20261018.
- Local branch: feature/miniphone-review-20261018, source/upstream origin/miniphone at 7aa4b434e1d9dccb575370d2ca736b07e75e1b7d. No same-name remote branch pushed.
- Old miniphone worktree remains c6b7600e; History worktree remains b6622a4a. No stash restore/reset, source merge or old branch mutation.

## Documentation
- C:/Project/worldo/界面设计/GenesisApp-个人分支索引-20261018.md: all16 local branches, current remote hashes, main containment, worktree locations, latest source, old APK locations and5 existing stash entries.
- Added links from September branch document and 项目交接/BRANCHES.md. Branch inventory coverage and local links checked.

## Build
- flutter build apk --debug --flavor internal --target-platform android-arm64 succeeded; Gradle332.1s.
- No business source changes. Local Flutter auto-updated analysis_options.yaml (+6 exclusion lines) and4 lockfile dependencies (matcher/meta/test_api/vector_math). Preserve as local tool differences, not UI changes.
- Archived APK: C:/Project/worldo/frontend-debug/packages/miniphone-20261018-7aa4b434/worldo-miniphone-internal-debug.apk.
- Bytes91693422; SHA25637861B024E5C758DE981F53A23041EB8AFFD96F32A2E9B3431AF7784874D85E7.
- No automated tests or full runtime acceptance performed. User will inspect actual UI.

## Phone preview
- Device1578064333000VV (Vivo V2121A); internal package com.worldo.ai.internal.
- Direct adb install -r returned Success; app launch requested. Never use flutter run installer fallback (may uninstall). No uninstall/data clear authorized or performed.
- Future UI previews must use hot restart. Local ignored .dart_tool/hot_restart_internal.py copied from History worktree; discovers no URL automatically, obtain latest live Dart VM device URL before use. It temporarily selects internal flavor for attach, restores exact pubspec bytes, then performs app.restart(fullRestart:true) and detaches leaving app alive.
- No commit/push requested for this new review branch. Continue changes here after user reviews.

## UI revision — 2026-10-18
- Posts author shortcuts now include all loaded World characters plus unknown IDs from post/authors, using fixed 72px slots aligned left even on an empty feed. Existing author filtering/read flows remain.
- Home music card keeps 44x66 portrait art and control sizes; compact seek row 48→32, outer vertical padding 10/4→8/2, removed 2px gap (22px total reduction at normal text scale).
- Music title 24→20; Like is in the title row; artist/source follow underneath.
- Create Post uses shared navigation header and fixed bottom full-width GenesisPrimaryButton. Scrollable form groups author, editor/counter, and optional photo. Removed redundant helper prose and reduced upload box to108x144.
- New drafts limited to500 grapheme clusters with IME composition support; original65535-byte backend check retained. Already-submitted unresolved requests retry original content without truncation. API/upload/account isolation unchanged.
- Updated MiniPhone AGENTS and integration docs for user-authorized changes to previous author/top-Post rules.
- `flutter analyze --no-pub lib/pages/mini_phone`: No issues found (114.1s). `git diff --check`: clean. No automated tests run for this UI request.
- Existing phone app hot restart succeeded (`app.restart` code0,6640ms); detached without reinstall. Exact pubspec restored and no diff. Latest startup Flutter error scan returned no matches; screen-by-screen visual acceptance remains with user.
- Changes are local and uncommitted; original APK archive is still the earlier7aa4b434 build, not this hot-restarted revision.

## Photos correction — 2026-10-18
- User clarified missing avatars means avatar images absent from the album, not author badges.
- Read-only device VM inspection: first page had10 assets but only5 distinct image URLs; each pair described parent/child locations sharing the same image. All5 character profiles had avatar URLs, none in that first page. hasMore=true, page=1. Thus duplicate content is distinct asset registrations, not duplicate widget painting; missing avatars must be checked on subsequent pages before concluding registration failure.
- Photos raw asset-ID cache preserved; grid and viewer now share an exact image-URL-deduplicated list. Auto-load pages near the viewport end after layout, including underfilled first page, honoring loading/error guards.
- Static analysis of photos directory passed (17.8s); diff whitespace clean. Hot restart code0 (6944ms), exact pubspec restored. No automated tests run.
- After user reopened the album, read-only device inspection confirmed page3/hasMore=false,24 raw assets/15 unique images, and all5 profile avatar URLs present. Avatar absence was pagination, not missing backend registration in this world. UI now projects the15 unique resources and viewer uses the same list.

## Default artwork and empty worlds — 2026-10-18
- User clarified default backgrounds means placeholder location artwork, not phone wallpapers or the World cover.
- Device inspection: Mafia Man had2 asset rows referencing known default-map images; same existing resolver that maps backend defaults to local map_default artwork identifies these. Album projection now excludes recognized defaults/empty URLs before grid/viewer construction; source records untouched.
- Empty-world evidence: Jeju Trip: They Only Want Me had album page1, hasMore=false, no album error,0 rows, but6 profiles with avatars. This differs from prior pagination issue. Current API contract explicitly excludes historical-world backfill and does not backfill on reads; no backend change authorized/performed.
- Photos static analysis passed (15s), diff whitespace clean. Hot restart succeeded (code0,5932ms), exact pubspec restored. No tests run, rebuild/install or source push. User can preview filtered album; historical backfill remains a backend follow-up.

## Worldo cover exclusion — 2026-10-18
- User also excludes the Worldo cover from Photos. World metadata now retains cover resource keys; Photos filters matching resource variants before grid/viewer projection. Account reset clears cover keys. No description/name heuristic or backend asset deletion.
- Photos and changed Store static analysis passed (20.8s); git diff --check clean. No automated tests. Phone hot restart succeeded (code0,6037ms); pubspec restored, no rebuild/install/push.

## Shared MiniPhone clock — 2026-10-18
- Entry previously hardcoded01:04; Home used parsed World time. Entry/Home/settings preview now use MiniPhoneSession.clockTime; Store parses existing world time and falls back to18:05. Worldless sessions use the same default. Existing World socket and Store listeners update both views; no device-clock dependency.
- Account reset clears old currentTime. Missing date behavior unchanged. Module/integration notes updated to replace old empty-time rule.
- MiniPhone static analysis passed (17.3s), diff whitespace clean. No tests or APK build. Phone hot restart succeeded (code0,7262ms); pubspec restored unchanged.

## Clock fallback correction — 2026-10-18
- User clarified18:05 is for the outside entry icon ONLY. Parsed Store/session clock now returns empty when absent; dedicated entryClockTime supplies18:05. Home/settings preview stay blank without valid world time. All views still share actual world time when available. This supersedes the shared fallback described above.
- MiniPhone static analysis passed (15.5s), git diff --check clean. No tests/build. Hot restart succeeded (code0,5822ms), pubspec restored unchanged.

## Team branch submission — 2026-10-18
- User authorized pushing this reviewed version to the team repository. Target: origin/feature/miniphone-review-20261018; verified absent before publishing. Existing origin/miniphone remains7aa4b434, origin/main e53e0b99 at pre-push check.
- Fresh final `flutter analyze --no-pub lib/pages/mini_phone`: No issues found (14.1s); `git diff --check` clean. No test suite or APK rebuild requested/run for this submission.
- Team-readable change list: genesis_app/docs/mini-phone-ui-20261018.md. Include source, module/integration docs and this checkpoint. Keep analysis_options.yaml/pubspec.lock SDK changes local; excluded from commit.
- Publish only the explicit new remote branch, without force, merge, or changing existing branch pointers. Push receipt/commit hash are recorded in the shared local branch index after publishing.
