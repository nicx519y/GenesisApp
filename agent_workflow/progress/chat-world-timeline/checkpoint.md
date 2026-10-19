# World chat timeline checkpoint — 2026-10-16

- Worktree: C:/Project/worldo/frontend-debug/GenesisApp-chat-timeline
- Branch: feature/chat-world-timeline-20261016; base origin/main e53e0b992103eb68e55397e40553ff1a219a005a.
- User approved full World chronology A/B/C/A + new B entry; displayed room follows reading location while actual entry/send remain B.
- Main internal debug APK built/installed on Vivo V2121A (1578064333000VV). Flutter session32069 is active from this worktree. Existing regular/miniphone worktrees untouched.
- Implemented page-owned read-only V2 per-leaf pagination, concurrency3, complete-window watermark, retry/generation guards, merged canonical queues + active projected replies, source-local Tick parsing, stable historical VM identities. No backend changes/internal endpoints.
- Anchored viewport reports visible IDs after layout. Header/path/occupants/background follow source room; current location restored at latest. Preview pages excluded. Archived rows cannot trigger active-room long-press mutations.
- Review fixes: all rooms live-refresh; suppress replaced reply IDs only (not whole round); persisted-ID ordering before live-only roundOrder. Current candidate/local messages preserve their live sequence.
- Validation: six touched Dart files targeted analyze no issues; phone hot restart completed for first version, updated restart pending. No tests run (not requested). Actual multi-location server scenario has not yet been exercised on phone.
- No feature commit/push requested. Local IDE-generated analysis_options.yaml/pubspec.lock changes excluded from feature scope.

## Review closure and preview
- Review resolved: all-location service updates included; current candidate reply suppression uses exact formal message IDs; mixed HTTP/WS order uses persistent IDs first; hidden pages automatically fill at least12 renderable rows; gap callbacks filter joined location; generation-guarded exponential retry (2s to30s) handles failures even with short/empty content. Timers/read results invalidated on deactivate/dispose/target/identity changes.
- Targeted analyze after fixes no issues. Final phone hot restart being applied. Real A/B/C server-history scroll still requires user visual validation; no test suite or backend write performed.
- Plan: docs/superpowers/plans/2026-10-16-world-chat-timeline.md. Feature remains uncommitted/unpushed for preview.

## Tick dedup and location transitions
- Group same positive tickNo/subTickNo copies in world projection. Keep first chronological anchor, merge distinct globals/statuses/location paragraphs/movements; don't mutate source VMs. Candidate/live actions remain unchanged.
- Added optional anchored-list message decorator for thin location boundary with existing location name (no new translatable copy). Row cache includes decorator and previous message identity.
- Header/background use keyed300ms AnimatedSwitcher fades; metadata follows current reading room. No tests requested; targeted analyze and hot restart applied for user preview.
- Final targeted analyze: no issues. Boundary is included inside measured row geometry. Phone connection stalled during sync; app relaunched, attaching anew (session11015).

## Tick display simplification
- One completed card per tickNo, including 0; subticks enrich the same visible card. Dedup also runs before world-history readiness. Progress placeholders remain independent.
- Paragraph comparison uses visible content/location/time/visibility rather than sourceIndex and display metadata; identical rendered content across subticks intentionally appears once per user request. Different text, locations, times, clues, or visibility remain distinct. Status lists are unioned.
- Plain/legacy fallback contributions are retained as visible location paragraphs when structured copies also exist, unless their text already appears in the merged card.
- Reviewed for content loss; no tests requested/run. Targeted analyze and phone hot restart repeated after fallback preservation. Feature remains uncommitted/unpushed.

## More visible location boundaries; Tick relevance proposal
- Replaced faint inline divider with full-width dark neutral boundary band, 1px top/bottom rules and 20px external spacing.
- Boundary now uses current header location name/parent source, shared header title renderer, overline typography, place_outlined icon and exact breadcrumb chevron. Long names remain constrained with ellipsis.
- Added ChatLocationSectionLabel in shared chat header library; header overline style extracted without changing its values.
- Tick content scope unchanged this turn. Proposed fixed per-history-segment relevant events, global once and other locations collapsed; avoid dynamically filtering card content as reading header changes.
- No new translated copy, no tests requested/run. Targeted analysis / phone hot restart pending final output. Uncommitted/unpushed.

## Approved Tick scopes implemented
- Tick placement extracted into location_chat_tick_projection.dart. Tick/story/movement broadcasts wait for a conversational/entry segment; on arrival only the latest waiting Tick context is shown, while unseen backlog remains in Events. Historical active segment starts unset; joined room is handled explicitly if entry response is pending.
- All genuine dialogue retained even when older HTTP/WS metadata is absent. Conversational VM types establish segments; broadcasts alone do not. No changes to actual join/send state.
- Cards grouped by (tickNo, source location), with local events only; Global text/statuses aggregated once at first displayed card. Empty local-only copies are omitted, progress placeholders retained, original IDs and immutable source content preserved.
- Movement VM now retains oldLocationId from V2 payload. Projection includes source/destination only, dedups character/source/destination and sets existing localized went-to/came-to rendering per location. Events filtering unchanged.
- Code review found/fixed metadata-based dialogue loss and first-anchor pre-entry backlog. No tests requested/run. Full touched-file targeted analyze initially clean; final two-file reanalysis and hot restart being completed. Uncommitted/unpushed.

## Thin path separator and canonical full Tick identity
- User requested original thin divider, pin + loc1 > loc2 path. Removed dark boundary band and unused ChatLocationSectionLabel. Resolve full ancestor tree; one-line label preserves leaf name, truncates long ancestry, full path available to tooltip/semantics.
- Root cause verified from phone screen and temporary fingerprint-only diagnostics: same main tick was merging distinct subTick0 at03:53 and subTick1 at05:47, repeating location headings and mixing historical states. Exact duplicate body audit in loaded window was0; the faulty union was the issue.
- Full Tick identity restored to (tickNo,subTickNo). Per exact identity/location choose latest meaningful nonmalformed snapshot, no cross-version concatenation. Preserve subTickNo and currentTime. Global selects a single snapshot once per full Tick.
- Snapshot winner uses authoritative sorted chronology captured before arrival placement. Cache signature includes retained first-row localId to prevent stale anchors during paging. Arrival context uses latest full Tick only.
- Temporary audits removed. Phone screenshot after hot reload confirms Tick1 has one local block followed by normal dialogue; Tick1-1 no longer spliced into it. Targeted analyze clean and review found no important remaining issues; final path-label check/restart completing. No tests/commit/push.

## Separator readability, arrival ordering and movement preservation
- Location boundary now 14/w700 with 16px pin; full path wraps without maxLines/ellipsis. Thin divider retained.
- Arrival Tick context now precedes user_enter_location marker.
- Movement events are collected from original chronological Tick replicas (including non-displayed broadcast rooms), keyed by full Tick identity and character/source/destination. Filter to source/destination of existing displayed room groups. Body snapshot policy unchanged. Cache signature includes relevant movements.
- Phone diagnostic: current Tick1-0 and1-1 raw movement count0; Tick0-1 raw3 / parsed3. Current empty movement section is expected for Tick1; avoid claiming missing server data exists. Fixed independently identified snapshot/cross-room omission risk. No invented movement records.
- Temporary diagnostic logs removed. Four-file dart analyze: No issues found. diff --check clean. Read-only peer review found no obvious issues. No tests run. Final hot restart requested on attach11015; completion being checked. Uncommitted/unpushed.

## Compact separators, midpoint transitions and entry scroll stability
- Separator uses 12px regular path with bold leaf, FittedBox.scaleDown for a complete single line, no ellipsis. Thin side rules retained.
- Reading-location callback now selects the message at the physical screen midpoint (clamped to chat viewport). Actual boundary GlobalKey center owns transition; cached relative marker offset covers virtualized rows. Boundary keys pruned when adjacency changes; geometry version includes decorator/previous-row identity.
- Phone diagnostic captured route transition replacing53 world rows with17 local rows and a -8444px coordinate correction, then17→53. This was a concrete list-shrink path. Inactive panel now pauses IO with generation invalidation and retains its last projected list plus separators until disposal/target reset. Deliberate reentry clears canceled retry cooldown. Account/service/history-generation scopes still reset as before.
- First drag synchronously captures visible content anchor before releasing entry/reply hold, rather than waiting until post-frame after lazy layout/tail changes.
- Diagnostics removed. Four-file analyze clean; diff check clean. Peer review follow-ups fixed (inactive separator geometry, retry timer). Final marker-cache cleanup compiled via hot restart; pending final analyze/restart output. No tests/commit/push. Specific user-reported first-swipe behavior still needs visual confirmation after restart.

## Confirmed repeated-scroll jump root cause and repair
- This supersedes the prior assumption that lifecycle collapse alone explained jumps. Runtime audit confirmed extension-method decorator tear-off compares unequal on every rebuild. Putting that function into geometry version invalidated ALL row measurements during ordinary reading/header rebuilds.
- Phone before repair: 57-row list unchanged, decorator changed repeatedly; detached correction -3463px then +1808/-377/+651. Measured paint-derived offsets exactly matched entryExtents offsets, proving actual prefix height reestimation rather than a coordinate/sign bug.
- Added messageDecorationVersion: concrete value (path-part count, full path) or null. Both geometry cache and row cache use the value, not render function or unrelated previous message ID. Rendering and version resolve through the same boundary-parts helper. Body content/date/etc remain in existing version.
- Phone after repair: two up-history drags and one reverse drag. No repeated thousand-pixel corrections; newly measured rows caused isolated -103/+165 prefix adjustments; reverse drag produced no >20px correction. This is a bounded observed scenario, not full-suite coverage.
- Temporary diagnostics removed. Two-file dart analyze No issues found; git diff --check clean; read-only review found no obvious issue. Final hot restart in progress on session11015. No tests/commit/push.

## Entry viewport starts at tail, arrival-first segment
- Latest user request supersedes Tick-before-entry display: new location segment now starts with decorated arrival marker, then local Tick context and normal conversation. Non-entry anchors keep prior context-before-dialogue behavior.
- Message list state is keyed by actual world/location (not reading location). Reentry clears reserved reply tail, pending positioning/old anchors, invalidates layout-finish callbacks, and re-enters follow-latest; user drags still cancel the standard entry scroll command. Reading header resets to actual joined location.
- Shared coordinator callback ownership guarded by message-list owner so disposal of old keyed list cannot clear new list's composer/oldest-edge hooks.
- Four-file analyze clean; additional coordinator reanalysis pending; diff check clean. No tests run; phone hot restart queued. No commit/push.

## Fresh-location viewport versus same-location reentry (2026-10-16)
- User clarified: map->same A shows ordinary history tail; map->different B starts an empty viewport with path and entry at top, history scrolls above.
- UI visit memory is service/account/world scoped; fallback setup defers until identity exists. Fresh entry gets a stable UI-only row (never outbox/service history/storage). After confirmed join, existing localized characterCameToLocation copy supplies the entry indicator. Canonical own WS entry upgrades same row and duplicate is removed; retain canonical round metadata for waiting presentation.
- Service read-only markers are reset per actual entry command. Own entry restricted by world/desired location/identity. First new realtime round filters known pre-command rounds and world/location, including world_new_message round BEFORE its HTTP refresh. Complete initial all-room history frontier is frozen for later HTTP ordering. New local client IDs are tracked separately. Historical hydration does not act as a fresh entry event.
- Footer minimum extent = stable entry content offset + viewport height; entry row pinned, restored-content rendering, safe nullable lookup. Thus bottom follow aligns new entry top; users can browse older rows normally. Prior Tick context is above fresh entry. Same-location reentry does not add this extra viewport.
- Runtime before UI fallback: same-location reentry visibly showed history tail; different room showed full-height fresh segment with path at top. Diagnostic proved backend sent ACK + user_location_change only, no user_enter_location message; this motivated the UI-only confirmed-join marker. All diagnostics removed.
- Final nine-file explicit analyzer (including parts) No issues found; diff --check clean; peer read-only review found no concrete additional issue after notification-round fix. No tests run. Final marker screenshot not yet confirmed: phone locked, async unlock request sent. Last successful restart15,138ms before final tiny canonical-round edit; final hot restart pending output on attach11015. No commit/push.

## Correction: entry indicator only for actual entry messages
- User explicitly rejected the join-success fallback indicator: when no entry message is needed, fresh room must remain empty except for its location separator.
- Removed the frontend-generated characterCameToLocation text. Stable visit boundary and full-height fresh viewport remain; body is empty unless an actual own entry event provides canonical content. Existing backend entry command/gating unchanged.
- Targeted analyzer No issues found; diff check clean. Attach11015 exited during restart attempt; recovering preview connection. This supersedes the confirmed-join UI marker behavior above. No tests/commit/push.
- Preview connection restored by restarting installed debug process (no data clearing). New attach session4245, same worktree, --no-dds; hot restart completed7,965ms. Canonical-only entry text now synced to phone.

## Reply controls before fresh visit boundary; full-width path divider
- User requested regenerate/go-on/edit/inspiration below last conversation message and above new location separator. Anchored list now inserts its single existing controls slot before a trailing visit boundary; deck fallback insertion and compact spacing use the same position. Once actual new content follows the boundary, controls return to the conversation tail. No action availability/handlers changed.
- Separator side rules now1px (was0.5), Expanded to the message-list edges shared with Tick plates. Center path is constrained to preserve at least16px per side; full single-line path, bold leaf and existing colors retained.
- Two-file explicit analyzer No issues found, diff --check clean. No tests run. Hot restart issued to attach4245; completion pending. Uncommitted/unpushed.

## Other-location history folding (2026-10-16)
- Actual joined location remains expanded; other contiguous location segments default folded to a clickable path/expand row. A/B/A chronology stays intact. Section identity survives older-page prepends by overlap with retained rows; state resets on a new visit.
- Full messages/reply projection remain unchanged. Only anchored-list render entries omit hidden rows, avoiding changes to actions, persistence or sending destination. Header decoration/cache versions use stable values.
- Expand targets that section's final row; collapse targets its retained header row. Separate generation-cancelable navigation detaches bottom-follow, pins/measures only the target, applies layout-phase bottom alignment and releases previous reply reserved-tail state. User drag/send cancels the target hold. An expanded section has a fixed collapse control at the top of the message viewport; reading another expanded segment switches that control.
- New helper: location_chat_history_sections.dart; viewport, page, connection and scroll coordinator updated. No new localized copy, backend changes, tests, commits or pushes.
- Targeted analyzer (three touched implementation files) No issues found; diff --check clean. Read-only review found stale reply tail risk, fixed; reported localId/layoutId concern withdrawn after source recheck.
- Previous attach4245 disconnected. Reattached without reinstall to session17819, successful hot restart8,501ms. Final tail-cleanup restart pending. Phone locked; async unlock request sent, live expanded/collapsed behavior not yet visually confirmed.

### Unlocked phone preview confirmed
- User unlocked. Final logic hot restart completed6,548ms on attach17819. Opened existing Mafia Man / Seating Area: current-location messages expanded, foreign location visits shown as collapsed path rows.
- Opened two Adrik's Office history visits: each displayed its own end-of-segment content above the composer; scrolling toward earlier records retained the top collapse control. Tapping the fixed control collapsed the segment again. No send/regenerate/Tick actions invoked.
- Visual inspection found the fixed control used a translucent white token, letting message text overlap its label. Composited that existing token over darkBackground to make only the floating control opaque. Hot reload confirmed legible dark surface. Targeted analyzer No issues found. Screenshots under frontend-debug/chat-history-{expanded,scrolled,collapsed-again,expanded-final}.png.
- Final requested hot restart after the surface fix completed6,661ms on attach17819; no tests/commit/push.

## Fold controls refinement and verification (2026-10-16)
- Latest user instruction supersedes previous tail positioning: expand aligns the first retained section row to the viewport top; collapse also retains its header. Layout correction uses current-frame content extent including fresh-visit tail, with generation cancellation on manual scroll/send.
- Separator shows only the last two hierarchy levels at fixed12px (leaf bold). Removed FittedBox; long text wraps without shrinking. Available width accounts for the inline toggle.
- Expand/Collapse uses localized text plus a single chevron, darkBackground opaque pill. Expanded collapse control stays at viewport lower-right. Cached toggle closures resolve current section before navigation.
- Added history_folding test coverage: repeated expand/collapse, top alignment, hidden rows, manual scrolling and earlier-history prepend anchoring. Five targeted suites:100 passed; log frontend-debug/chat-fold-check.log. L10n workflow:858 keys x8 target languages,52 tests passed; generated bindings updated.
- Unlocked-phone verification: opened Main Hall history from Seating Area, observed header aligned near top, read downward, used fixed lower-right Collapse, and repeated expand/collapse. No send/regenerate/Tick invoked. No duplicate-key error reproduced after latest restart in these scenarios.
- IMPORTANT unresolved diagnostic: prior accumulated Flutter output contained Duplicate keys found and cascading overflow exceptions. Original parent/key was unavailable; targeted temporary entry-key audit and current phone flow did not reproduce. Do not claim this runtime issue fixed or all bugs cleared. Removed temporary audit prints; retain as follow-up requiring full first-exception context if it recurs.
- Feishu localization document sync for chatHistoryExpand/chatHistoryCollapse remains incomplete: local workflow complete, external document access unavailable. Must report this limitation, not mark documentation synchronized.
- All changes remain uncommitted/unpushed; existing analysis_options.yaml/pubspec.lock changes preserved. Final formatting no changes; analyzer and hot restart requested after removing diagnostic (completion to be recorded).
- Final four-file analyzer: No issues found; diff --check clean. Final phone hot restart completed6,703ms on attach17819. Ready for user preview; duplicate-key investigation and external Feishu sync retain limitations above.

## Inline controls, preserved toggle position and sticky section (2026-10-16)
- Latest request supersedes top-align-on-expand and floating lower-right control. Divider is left-aligned pin + last-two hierarchy levels at fixed12px (leaf bold), rule, transparent inline Expand/Collapse. Removed floating action.
- Before fold plan changes, capture old target row extent relative to scroll pixels. Navigation layout correction preserves that viewport offset instead of zero. If original header is above viewport (sticky collapse), offset clamps to0. Existing generation cancellation and lazy measured geometry retained.
- Expanded foreign-section message->header mapping drives a ValueNotifier sticky header in the anchored viewport Stack. Opaque darkBackground full-width top surface covers messages beneath it. Visible original header is not duplicated before reaching top; switches/removes on leaving that section. No scroll padding insertion or reused GlobalKey.
- Hidden rows excluded from visibility/reading geometry. Folded navigation rows still report crossing midpoint, but resolve display background/header to actual joined room; expanded content uses normal reading-location transition. This also fixes peer-review finding that skipping folded rows entirely left a stale expanded-room background.
- Four-file static analyzer clean before final one-line observer cleanup; final analyzer pending output. No tests added/run this revision. Existing test suites were100 passing before this revision, not a claim about current changes.
- Phone: new divider layout shown, all-folded state retained Seating Area background. Boardroom expansion preserved separator screen position; downward reading switched header/background and showed opaque sticky separator; tapped sticky Collapse. No send/regenerate/Tick actions. One earlier Main Hall capture shifted during initial/pagination activity; not isolated/reproduced in subsequent Boardroom check, so do not claim exhaustive scroll stability.
- Temporary FoldAnchor diagnostic removed. Prior Duplicate keys exception remains unconfirmed from previous version (not reproduced in these steps). Existing Feishu sync limitation unchanged; no new strings this revision.
- Uncommitted/unpushed. Final hot restart requested on attach17819 after final background correction.
- Final four-file analyzer: No issues found. diff --check clean (existing CRLF warnings only). No test execution in this revision.

## Compact transparent separators (2026-10-16)
- Latest user revision: reduce separator height, remove sticky surface fill, add right-end breathing room on the joined-location line, equalize spacing between foreign/current headers, and increase header-to-message spacing.
- Removed foreign-only vertical8 wrapper; inline/sticky/current rows share min32 inner height plus4 top/bottom =40 single-line total (previous foreign68). Toggle min-height44->32 and vertical padding8->4. Fixed font12 and wrapping retained.
- Added12px gap before body for both current and expanded foreign section. Empty fresh-entry marker remains separator only. Current-location line ends16px before the normal list edge.
- Sticky header now transparent. Clip only scroll-message paint/hit area below the actual laid-out header height via _HistoryHeaderContentClipper; do not alter viewport layout/scroll extents. Real background shows through without text behind the pinned label; measured height handles wrapping/font scaling.
- Three-file dart analyzer: No issues found; formatted. No tests added/run. Hot restart requested on attach17819, completion pending. All work uncommitted/unpushed; earlier unresolved runtime duplicate-key and Feishu sync notes unchanged.
- Final hot restart completed9,299ms on attach17819; diff --check clean. Latest visual spacing/transparent sticky ready for user preview, not yet manually inspected on device in this revision.
- Follow-up: remove12px right internal padding from shared Expand/Collapse button (left12/top4/bottom4 retained). Its trailing icon box now ends at the same list boundary as the Tick plate; applies inline and sticky. Targeted analyze clean; hot restart requested. No tests/commit/push.

## Frozen local preview package (2026-10-16)
- User requested freezing current version and installing a package to phone; future UI work continues from this local state. No commit/push requested.
- Build: flutter build apk --debug --flavor internal --target-platform android-arm64 --no-pub, success90.6s. APK121,526,581bytes; SHA2564FF492270B3D8C932A3D04AA181DDD3CBCB0A16E2B7494D848356BB4F7C3C75E.
- Archive: C:/Project/worldo/frontend-debug/packages/chat-world-timeline-20261016-214244/. Contains APK, source-changes.zip (40 modified/untracked files), binary changes.patch, build-info.json (base commit/branch/file list). Current branch feature/chat-world-timeline-20261016 unchanged. No credentials/signing materials copied into archive.
- Phone1578064333000VV V2121A: adb install -r returned Success, retaining app data; package com.worldo.ai.internal version9.9.9+999. Started MainActivity after installation.
- Detached prior flutter attach17819 with d before building. Future previews require new attach from this worktree; do not reuse the finished session.
- No new tests run for packaging. Previously documented unresolved duplicate-key diagnostic/Feishu sync remain limitations.
