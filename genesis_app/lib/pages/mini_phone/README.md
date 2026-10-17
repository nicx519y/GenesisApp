# MiniPhone

## Live Messages, Posts and Photos (2026-10-16)

World-backed sessions use `GenesisApi.miniPhone` and `MiniPhoneStore`, with the
existing World WebSocket distributing three phone event types. Home, unread
badges, conversations, posts, notifications and album data originate from Chat.
Messages and its Home inbox now render a SQLite-backed local projection; HTTPS
and World WebSocket data merge into this shared cache before persistence.
The explicit worldless developer preview remains local; live failures never
fall back to its fixtures. Music, model settings and wallpaper retain their
existing services.

Chat shares LocationChat's anchored list, scroll coordinator and extracted
keyboard layout, with the existing MiniPhone style. Send keeps the keyboard,
uses no large reply reserve, and shows reply waiting only for AI peers.
Messages merges API-listed rows by world/character and ranks them by the latest
message's delivered_at, then full message_id, both descending. Chat deliveries
and history update the cached list immediately; empty rows retain server order
after message-bearing rows. Virtual session ID 0 is supported.
Player messages use sender UID for direction. AI reply status
recovers through request-filtered HTTP history; pushes are not replayed offline.
Posts preserves author filtering and uses local image selection plus upload for
publishing. Photos remains the read-only world album. Optional legacy Feed
comment previews are used only if returned; replies use real comment IDs.

The independent `genesis_mini_phone.db` scopes DM messages, sessions, unread
baselines and queued read receipts by environment/account/world. Cached history
is readable before network completion, and reading clears the local inbox even
offline. Receipts retry after durable storage, without automatically resending
messages. Each Home entry rebases from `/home`, retaining concurrent local
changes and the count of unread items omitted by its 20-item limit. The latest
1000 ordinary historical messages per session are retained, plus unread,
unsettled and latest-message records. Posts notification behavior is unchanged.

See `docs/mini-phone-client-integration.md` for behavior, backend contract gaps
and verification boundaries. The older notes below describe prior iterations
and do not establish live API or device acceptance for this change.

## Internal page navigation (2026-10-16)

Messages → chat and other in-app detail pages use an internal Navigator with
`GenesisDarkPageRoute`, sharing the app's Android/iOS page transitions in both
directions. Back restores the existing list and its scroll position; iOS swipe
back updates MiniPhone navigation state. The fixed Close button exits the whole
phone, including during an internal transition. Home icon/card expansion remains
owned by the independent app-launch transition host.

Most MiniPhone screens share the local `_panel` / `_navigation` layout helpers;
chat uses the shared chat keyboard/viewport layout with that navigation header,
and Create uses a dedicated action header. These are not a replacement for the
app-wide `GenesisBackAppBar`.

## Shared launch transitions (2026-10-12)

Desktop icons and Home notification/music cards now use the independent
`ui/animations/app_launch_transition` module. MiniPhone owns navigation and
business effects; the module owns source measurement, expansion, return and
reduced-motion behavior. Existing detail-page return hierarchy is preserved.
See the module README for its public interface and validation commands.

Pixel 6 debug recording checked Photos, Settings, Messages, Posts and second-page
Music opening/returning. Sampled Photos intermediate frames showed no white
flash, stretched layout or overflow. Notification/card branches, reduced motion,
interruption and resize are covered by focused widget tests; this is not a
release-mode frame-time benchmark.

Base: origin/main 541a5e44. Branch: feature/miniphone-ui-20261007.

Open from the World map handset, active Location Chat handset, or Developer → button → Preview Mini phone.
Home provides Messages, Posts, Photos and Settings. Tap a chat header to view Contacts. Posts provides author filters, Create, Comments and full-image viewing.

All characters, chats, notifications, photos and posts come from `mini_phone_demo_store.dart` and bundled `assets/mini_phone`. Sends receive simulated replies; publishing, likes and comments mutate memory only. Reopening retains the demo process state; restarting the app clears that demo state. Settings no longer offers Reset phone. Wallpaper reads/saves use the World API and account-scoped local cache; device images use the same shared crop pipeline as Location covers (1:2, crop size 1500 × 3000, JPEG quality 90 or PNG when transparent, no 3 MiB input gate). Crop confirmation prepares a small in-memory preview. Apply performs full-resolution preparation (0–20%), uploads (21–90%), then saves the background (91–100%, with slow simulated progress capped at 99% until server success). A translucent mask clears from bottom to top without numbers or a spinner; the button stays loading. Saving retains the preview, and only successful full-resolution upload bytes enter the image cache. The entry points and page are available in Debug, Profile and Release builds.

Reference: C:/Project/worldo/界面设计/mini phone (v5.5).

UI files: mini_phone_home.dart, mini_phone_conversations.dart, mini_phone_posts.dart, mini_phone_media.dart. Shared styles: mini_phone_ui.dart. Navigation: mini_phone_page.dart.

App style alignment: page titles use GenesisTypography.pageTitle (20/600/1.4); content and input use body (14/1.4); supporting copy and times use supporting (12/1.4). Standard text colours, 16px page inset, input/button radii and primary/close buttons come from the common UI library. Chat bubbles share chat_scene_plate_tokens. Home glass and the display clock retain their special layout; notification height scales with text.

v5.5 Home: reflective translucent clock, light glass notification groups for unread Messages and Posts, exposed stack strips, independently expandable groups, two-page pager (left swipe opens the second page with locked apps), and white Heroicons on dark grey dock tiles. Posts notifications clear when viewed. The notification glass and dock have no outlines. Photos use an edge-to-edge three-column grid without gaps. Posts author shortcuts are 54px; comment previews have no separator above them. The map handset is aligned above the existing zoom control; its badge/message tile track the local message unread count. Subpages use back navigation without a close button and faint half-pixel dividers. The map zoom pill and handset share a 34px width; the handset is also accessible in location chatrooms. The portrait popup is 36px. A one-shot vibration/message reveal and circular portrait popup demonstrate incoming activity, respecting reduced motion. All of these states remain local preview data.

Hot reload from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Project\worldo\frontend-debug\flutter-hot-reload-miniphone.ps1 -Attach
```

Keep the phone app open. `r` reloads, `R` restarts and resets demo state, `d` detaches. New assets require a rebuild. This script targets the new worktree; the previous script targets the original checkout.

Validation: touched Dart files formatted/analyzed without issues; internal arm64 debug APK built and installed successfully. The Messages UI was observed on the phone with source assets and unread badge. Full regression and all upload/navigation branches have not been exercised; this iteration is for visual review.

2026-10-09 local iteration: MP–11B Music is available on Home's second page (Music is unlocked; the other placeholders remain locked). The portrait player has three local fixture tracks, likes, seek, previous/play/pause/next and a silent progress timer. Playback stops on leaving the page or backgrounding the app; no audio or backend service is connected. Removed the custom bottom strip from subpages and made the handset fill solid #232228. Relevant static analysis and internal arm64 debug build passed; installed to the test phone. This iteration remains uncommitted.

2026-10-12 Music supersedes the fixture implementation above: the catalogue uses the formal Music API, and foreground playback uses a World-owned just_audio service. The service owns at most two single-track players, prepares roughly five seconds of the next song after playback starts, promotes that player on next/completion, and pauses without auto-resuming after backgrounding. No background service or full-file audio download is added. The full player and Home card share single-line bounce-scrolling metadata, buffered seek bars with 48px interaction areas, and 200ms cover transitions that immediately remove the previous song's target. Music covers use the project's XL CDN size selection with DPR capped at 2; next-cover prefetch uses the same provider and decoder dimensions as rendering. Reduced motion disables scrolling and cover fades. Catalogue and playback failure/retry states remain; loading/buffering text is hidden.

Music validation (2026-10-12): 60 focused service/page/widget/shared-image tests passed, targeted analysis found no issues, and the production-flavour Android arm64 debug APK built successfully. Pixel 6 checks confirmed real catalogue playback, single-line bounce motion, buffered progress, track taps and enlarged-area dragging, Home controls, previous-to-start, manual/automatic next, standby promotion, and background pause without auto-resume. The standby remained silent; its observed buffer was 32.731 seconds because the platform reads chunks despite the five-second target. Delayed/failed cover loading, 200ms removal, rapid switches, stale image results, reduced motion, large text and hidden prefetch were covered by controlled widget/service tests; no device network-fault injection or acoustic gap measurement was performed.

Music navigation controls now start playback in the foreground after previous/next, including from pause or before the first play. Previous beyond three seconds restarts the current song and plays it. Single-track navigation reuses the prepared player. Backgrounding or pausing while a requested song loads still prevents delayed autoplay.

Music sessions now belong to each World page. Closing MiniPhone retains that World session; exiting/removing World disposes its MiniPhone routes, demo state and both audio decoders. Current track `file`, millisecond position and known duration are stored locally under account/environment/World keys, periodically and on seek/pause/exit. Reopening restores the track and position without autoplay. Missing tracks fall back to the first song. Concurrent exit/reopen writes are ordered.

Shared system image selection temporarily exempts picker-driven lifecycle transitions. Android monitors screen lock and task visibility while its external picker is open, so Home/lock still pause music; returning never resumes automatically. Without the native monitor, only `inactive` is exempt. Existing foreground-only behavior applies outside picker flows. This iteration is validated at the code/test level; no device verification was performed.
