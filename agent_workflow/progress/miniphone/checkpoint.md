# Mini phone checkpoint

Updated: 2026-10-08 (Asia/Singapore).

## Workspace and branch

- Workspace: C:/Project/worldo/frontend-debug/GenesisApp-miniphone.
- Branch: miniphone, created from 75daa7ae without an upstream.
- Original task branch feature/miniphone-ui-20261007 remains at 75daa7ae.
- Feature base: origin/main snapshot 541a5e44; no rebase or main refresh in this save task.

## Saved implementation

75daa7ae contains the debug-only local mini phone UI, bundled assets, Developer preview, World map/location chatroom entry, and aligned map controls. Home supports two pages; the time moves with the first page, the second shows locked apps. Notifications expand below the clock. Messages unread badges are above avatars. Posts, Photos and Settings retain the approved styling.

All mini phone data is isolated in the memory-only demo store. No backend data implementation is included.

## Actual validation

- 2026-10-07: relevant Dart analyze returned No issues found.
- 2026-10-07: internal arm64 debug APK build succeeded and adb install returned Success.
- APK: C:/Project/worldo/frontend-debug/packages/worldo-miniphone-saved-debug-20261007.apk.
- 2026-10-08: existing feature commit and worktree status checked; only analysis_options.yaml and pubspec.lock remained modified. These pre-existing local SDK/IDE files are retained and excluded from this branch checkpoint commit.
- Full automated regression has not been run for this UI preview.

## Delivery and next steps

This task saves a local independent branch only; no remote push or existing branch update. Continue edits in this worktree. Only push after the remote and target branch are authorized. Hot reload script: C:/Project/worldo/frontend-debug/flutter-hot-reload-miniphone.ps1.

## Local UI iteration — 2026-10-09

Continuing locally on miniphone from 54cd7f49. Added the MP–11B portrait Music page with three isolated fixture tracks, likes, seek, previous/play/pause/next and silent progress simulation. Music is unlocked on the second Home page. No audio engine or backend connection was added. The handset uses solid #232228; all custom child-page bottom home strips are removed (the Android system gesture area remains system-owned).

Reference: 界面设计/mini phone/music.js and music.css, MP–11B in index.html. New source: genesis_app/lib/pages/mini_phone/mini_phone_music.dart; five music SVGs bundled. Modified Home, page routing, shared handset and Posts footer. Existing analysis_options.yaml/pubspec.lock changes preserved. This iteration is not committed or pushed. Static/build results will be recorded after completion.

Validation completed 2026-10-09: Dart format completed; dart analyze lib/pages/mini_phone returned No issues found; flutter build apk --debug --flavor internal --target-platform android-arm64 succeeded; adb install -r returned Success and package update time confirmed. Preview APK: C:/Project/worldo/frontend-debug/packages/worldo-miniphone-music-debug-20261009.apk. Full regression was not run. No commit/push in this local iteration.

## Home notifications and wallpaper — 2026-10-09

Removed the generic Notifications heading and duplicate app labels. Messages/Posts each use a single category heading with count; only one Show all/less control remains. Pagination capsule keeps its fill without an outline. Fresh/reset wallpaper is solid miniBackground (#151517); Settings includes Dark alongside existing photo choices.

Dart format completed and dart analyze lib/pages/mini_phone returned No issues found. This round is local and uncommitted; the installed music APK predates these edits. No active flutter run/attach process was found. A hot restart or selecting Dark in Settings is needed to replace the previous in-memory wallpaper choice. No tests, build, install or remote push were performed in this round.

## Playback entry refinement — 2026-10-09

Restored the source single-note SVG at the existing musical-note asset path. Shared isolated in-memory silent playback state now survives closing Music/the mini phone; the entry shows the note pulse plus a persistent round pause/play control via OverlayPortal for correct hit testing outside the handset. Pausing dims the note; app background pauses simulation. Avatar pointer overlaps the circle by 1px to eliminate the seam. Dart format completed; analyze lib/pages/mini_phone returned No issues found. Changes remain local and uncommitted.

User preference: after each local UI modification, directly hot restart the connected phone to preview. Existing attach session 11043 is used for this round.
2026-10-09 refinement: playback popup reduced from 52px to the same 36px circle as avatar (16px control glyph), positioned at the same -48px offset. Pointer and border both white; removed Material elevation tint and painted pointers above the circles/shadows to avoid seam discoloration. Static analyze: No issues found. Local changes only; hot restart requested through session 11043.
2026-10-09 notification precedence: popup circle and arrow now use a single union path painted opaque #FFFFFFFF behind the inset child, shared by avatar/music. Incoming avatar is no longer suppressed by music, unread badge remains in all playback states, and the notification tile takes priority inside the handset while unread exists. During avatar animation the persistent music control moves left beside it, returning above the handset afterward. Format/analyze completed: No issues found. Hot restart requested in session 11043; local/uncommitted.
2026-10-09 overlap and chatroom dock: notification avatar and music control share the same popup; during arrival a 17px pause/play control overlaps the avatar at its lower right, and badge remains. Duplicate traced to persistent World map entry under active location chat; map entry now excludes active chat locations. Music overlays also exclude covered routes. Location chat uses MiniPhoneEdgeDock with pan, bounded vertical movement and 180ms nearest-side snap (12px side inset), reserving header/popup and keyboard/composer space. Format and targeted analyze: No issues found. No automated tests requested/run. Local/uncommitted; hot restarted via session 11043.
2026-10-09 dock bottom and paused-exit reset: moved the chatroom dock into the actual message viewport, which already excludes header/composer and follows the existing keyboard layout. Removed fixed 100px reservation and duplicate keyboard/safe-area math; dock stops 8px above viewport bottom/input. Added debug-only resetPausedOnWorldExit scheduled after World disposal; inactive playback clears activation/track/progress, playing preview is retained. Format completed; phone hot restart confirmed (9,908ms). Targeted analyze pending completion; local/uncommitted.
Validation completed: dart analyze lib/pages/mini_phone lib/pages/chat/location_chat_page.dart lib/pages/world/world_page.dart returned No issues found. No tests or remote push in this UI round.
2026-10-09 clock rendering fix: device screenshot showed rectangular contour lines at the overlaps in glyph 4. _glassClock had a stroked Text underneath its gradient Text; removed the stroke layer, keeping the same typography and gradient fill. Dart format/analyze mini_phone: No issues found. Hot restart requested session 11043. Local/uncommitted.
2026-10-09 top drag clearance: removed the fixed 48px popup reservation and reduced chat viewport top inset from 16px to 8px. Dock near top (<48px) renders avatar/music popup below the handset with an upward-pointing shared frame; elsewhere popup remains above. Targeted format/analyze: No issues found. Local/uncommitted; hot restart requested session 11043.
2026-10-09 remembered dock: restored always-above popup and removed below-popup variant. Chat top bound is popup offset 48px plus 4px clearance; bottom remains 8px above composer. First-use default is right/bottom. Dock saves side and normalized vertical height in device-local SharedPreferences key worldo.debug.mini_phone.dock_position.v1, not fixture/account/backend data; asynchronous restore avoids overwriting a new user drag, queued writes preserve order. Existing viewport size/keyboard clamps remain. Format/targeted analyze: No issues found. Local/uncommitted; hot restart requested session 11043.
2026-10-09 replies and photo gallery: optional replyTo fixture field renders author @recipient comment in feed and @recipient body in details; p1 includes two reply examples. Photos opens a PageView at the tapped index (seven fixtures with explicit per-photo authors), with page count, pinch zoom and paging disabled while zoomed. Each image includes lower-right @author overlay; post image previews pass their actual fixture author. Controllers disposed. Format/analyze mini_phone: No issues found. Local/uncommitted; hot restart requested session 11043.
2026-10-09 save/push requested: verified current miniphone branch and team origin target; remote miniphone remains 54cd7f49 before push. Fresh targeted analyze covering mini_phone/chat/world files returned No issues found; git diff --check passed. Save all authorized local mini-phone UI refinements and music assets, excluding pre-existing analysis_options.yaml/pubspec.lock. No full automated regression in this save round. Target: origin/miniphone, normal fast-forward push.
Feature saved as f96bfc31. Staged check found trailing blank lines in four newly added SVGs; removed them in a follow-up cleanup before push.
2026-10-09 next UI iteration (local after published 4fc539f8): World map entry now shares the edge-snapping draggable dock with a separate device-local map position preference. All mini phone screen headers, Create and photo viewer include global close; process-local resume remembers screen/contact/post/filter/Home page/Create draft and photo viewer index. Message/character rows follow Inbox avatar 48px/radius8, 8px vertical spacing, title14/600, preview12/single line/time11. Chat detail reuses ChatMessageRow and ChatComposer with kPrivateChatStyle. Model button reuses MemoryModelEntryButton roomHeader; MemoryModelPage is reused with injected isolated catalogue/selection/memory callbacks and 40% local fixture quotes, token range1k–128k. Added an optional onBack hook to MemoryModelPage so embedded preview returns to its prior phone page; normal callers retain their existing behavior. Music play glyph shifted2px right for optical centering. No backend state or actual billing involved. Format and targeted analyze returned No issues found; no automated tests run. Phone attach reconnected in session21462 and syncing; restart result pending. No commit/push requested for this iteration.
Phone preview synchronized; hot restart confirmed in session21462 (6,956ms). Current UI iteration remains uncommitted.
2026-10-09 alignment corrections: map dock now has a lower left-side boundary (8px above collapsed World bar), reserving zoom controls only on the right. Removed chat header portrait; character-list access now uses explicit New message action. List row follows Inbox layout (48px radius8 avatar, 13px gap, 14/600 name, 12px one-line preview/right60px reserve, 11px tertiary time); detail still directly reuses kPrivateChatStyle components (14px/20px line-height). Global phone close is rendered once at safeTop+14px/right16px; all page headers reserve its slot, Home keeps 56px header, photo dialog header matches56px. Replaced Fast/Pro fixtures with read-only current World/chatroom model catalogue via the same page cache/API; names/groups/tags/descriptions match source. Selection/token changes and 40% discounted quotation remain local preview callbacks and never call selectModel/updateMemory settings. World/chat entries pass model World ID and shared cache. Async catalogue generation guards avoid stale World responses. Static format/analyze and diff-check passed. Hot restart requested session21462. Local/uncommitted; no tests or push in this round.

## 2026-10-09 Message cleanup
- Fixed local memory snapshot validation: use isolated local-mini-phone-preview ID in model page and returned memory settings; actual model catalogue remains read-only from World.
- Removed New message/contact picker and quick reply chips. Shared Inbox composer now has Send label and empty-send guard.
- Local changes only; no commit or push; no tests run.

- Messages character list: removed model selector; retained selector in conversation detail (2026-10-09).

## 2026-10-09 Wallpaper replacement
- Imported user assets E:/Worldo/mini phone/背景图/01,02,04 as wallpaper-01/02/04.png. Replaced built-in wallpaper choices; initial/reset wallpaper now 01 (Mist Forest).
- Rebuilding internal debug APK to include new assets; no tests/commit/push.

- Internal debug build completed (assembleInternalDebug 165.8s); adb install -r returned Success; launched app and reconnecting Flutter attach session 40366. Prior mini_phone static analysis passed (No issues found).

## 2026-10-09 Publication
User authorized publishing current changes to team origin/miniphone. Includes draggable map entry, resume/global close, Inbox-aligned Messages, model catalogue with local 40% quotes, UI refinements and three wallpapers. Era/icon mapping investigated only, not implemented. SDK/IDE analysis_options.yaml and pubspec.lock remain excluded. Latest internal debug APK build and device installation succeeded; no automated regression tests run.

- Fresh targeted Dart analyze passed (No issues found); staged diff --check passed. Publishing to origin/miniphone as a normal fast-forward push.

## 2026-10-10 Home music widget
- Added active-playback Home card above notifications, using existing MiniGlass, typography and music SVGs. Shows cover/title/author, elapsed/remaining time, seek, previous/play-pause/next; title opens Music. Paused playback retains card via activated state; World-exit reset follows existing behavior.
- Shares in-memory silent miniDemoMusic state with Music app/entry, no audio/backend/billing added. Home notification area adjusts height while music is active and remains scrollable. Local/uncommitted; tests not requested/run. Flutter attach session 82520 syncing for preview.

- Validation: Dart format completed; targeted dart analyze returned No issues found; git diff --check passed. Phone hot restart confirmed in session 82520: Restarted application in 5,708ms. No commit/push.

- Home music refinement: match message glass (white alpha .36, radius21, no outline), remove trailing note/red play fill. Cover height56→44, padding14/8→10/6, progress slot28; overall default height approximately178→136. Activated/pause lifetime unchanged: card retained until paused World exit resets state. Format and targeted analyze passed; no tests/commit/push.

- Home music proportions: restore portrait44x66 cover (same asset), title up to2 lines; central glyph32 vs skip24, controls40px height, progress22px, reduced bottom padding4/gap2. Information section enlarged while lower controls compact. Format/analyze passed, no tests/commit/push.

- Expanded Home notifications now share one CustomScrollView with date/clock/music; upward scrolling carries clock out together with cards while bottom dock/pager remain fixed. Collapsed layout remains clock plus bottom-aligned stack. Home music title16/600 and author14/400. Local only; no tests/commit/push.

- Home top occlusion fix: removed fixed top SafeArea/header reservation from scroll viewport. Initial status/header spacing is now a scrollable sliver for expanded notices, allowing cards/clock to scroll to screen top under independently floating global close. Collapsed clock and second app page retain initial safe spacing. Dart format/analyze passed; no tests/commit/push.

- Home bottom layout: full-height page scroll instead of viewport clipped above fixed dock; app dock/dots float independently over wallpaper. Bottom clearance is part of scroll content. SliverFillRemaining anchors collapsed card groups near dock; AnimatedSize with bottom alignment unfolds cards upward. Clock/music/notices share scroll in both modes. Format/analyze passed; no tests/commit/push.

- Messages Home notification avatars now use rounded squares (radius8 matching message list), including stacked and expanded cards. Posts retain circular avatars. MiniAvatar supports optional corner radius with circular default. Format/targeted analyze passed. Local/uncommitted; no tests run.

- Corrected notification expansion anchor: bottom-first scroll slivers reserve dock gap at bottom, then notification/music group grows upward via bottom-aligned AnimatedSize; clock is above group rather than constraining it from top. Last group bottom stays fixed as notification heights expand. Format/analyze passed; no tests/commit/push.

- Expanded Home notices: downward vertical swipe >=56px on release clears all expanded groups and resets bottom-anchored scroll to0, restoring folded stacks. Raw pointer listener preserves normal scrolling and horizontal pager/seek gestures; tracks pointer/cancel. Dedicated controller disposed with page. Format/analyze passed; no tests/commit/push.

- Replaced conditional expanded/strip UI and whole-group AnimatedSize with measured per-card render layout. All cards remain mounted; 320ms transition interpolates stack offsets/insets to independent rows, content opacity fades in and reverse paint preserves front card. Bottom-first scroll keeps bottom anchored. Downward drag controls expansion fraction directly, release collapses or springs back through tween; no jumpTo/reset on release. Targeted analyze/format checked; hot restart confirmed8,953ms. Local/uncommitted; no tests run.

- Fixed bottom-card anchor rather than only group height: front card stays at group bottom for every expansion fraction; other cards interpolate upward from overlapping slots. Footer spacing remains15 throughout (previous25→15 interpolation removed). Disabled native vertical scroll physics to stop Scrollable stealing collapse drag; downward gesture now exclusively controls fold progress. Format/analyze passed; no tests/commit/push.

- Corrected card identity/order: source list remains top-to-bottom; LAST card lower edge is the anchor throughout progress0..1. Earlier cards interpolate upward; no reversal placing first card at bottom. Native vertical scrolling remains disabled; down gesture folds. Format/analyze passed; no tests/commit/push.

- Folded notification stack tap: opaque hit area on stack GestureDetector lets tap expand even while child cards ignore taps. Single-card groups still allow direct card navigation. Targeted analyze passed; no tests/commit/push.

- Added collapsed upward-drag expansion using same per-card progress; expanded downward-drag collapse remains. Gesture starts from initial0/1, progress follows180px range, release uses distance/velocity and cancelled gestures restore prior group state. Click expansion and fixed last-card anchor retained. Format/analyze passed; no tests/commit/push.

- Horizontal swipe unintended expansion root cause: VerticalDragCancel can run when horizontal pager wins before VerticalDragStart; prior code restored stale group snapshot. Added active vertical-drag guard to update/end/cancel, so rejected horizontal gestures never mutate groups. Added12px progress deadzone and24px minimum for velocity-only settle. Format/analyze passed; no tests/commit/push.

## 2026-10-10 Publication: Home music and notification gestures
User approved publishing this preview to team origin/miniphone. Includes Home music controls, portrait cover/type refinements, message square avatars, per-card bottom-anchored expand/fold, tap/up/down gestures, and horizontal-cancel guard. Fresh dart analyze lib/pages/mini_phone passed; diff --check passed. Latest phone hot restart confirmed6,622ms. No automated regression tests run; SDK/IDE analysis_options.yaml/pubspec.lock excluded.

## 2026-10-12 Settings wallpaper upload tile
- Replaced separate Choose from device row with first gallery tile. Same Expanded width and 100px portrait interior, padding2/border2/radius8 as defaults. Full tile tap reuses _pickPhoto(wallpaper:true), pink selected ring for custom image. Apply unchanged.
- Branch miniphone; no commit/push requested. Local analysis_options.yaml and pubspec.lock preserved. Debug preview being launched from this worktree.
- Verification complete: targeted Dart analyze no issues, diff check clean. Internal debug APK built and installed on V2121A; Flutter preview session93440 active. No commit/push this round.

## 2026-10-12 Wallpaper settings follow-up
- Preview now190px wide at9:16 AspectRatio. Custom wallpaper Image.memory explicitly fills bounds with centered cover crop (home/preview shared). Removed Reset phone button and now-unreachable confirmation action. Upload icon matches Create add_photo_alternate_outlined24 and darkTextSecondary gray.
- No backend or image-byte transformation. No commit/push requested.

- Upload icon color changed from darkTextSecondary to miniPink per follow-up; size24/layout unchanged.

## Settings update publication 2026-10-12
- User authorized publishing this iteration to team origin/miniphone. Includes wallpaper upload tile, 9:16 preview, cover fill, Reset removal and pink upload icon.
- Fresh targeted Dart analyze no issues; diff check clean; phone hot restart previously completed. No tests run.
- Excludes local analysis_options.yaml/pubspec.lock. Push is regular fast-forward, never forced.
