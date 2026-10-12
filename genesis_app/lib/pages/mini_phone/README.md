# Mini phone style preview

Base: origin/main 541a5e44. Branch: feature/miniphone-ui-20261007.

Open from the debug World map handset or Developer → button → Preview Mini phone.
Home provides Messages, Posts, Photos and Settings. Tap a chat header to view Contacts. Posts provides author filters, Create, Comments and full-image viewing.

All characters, chats, notifications, photos and posts come from `mini_phone_demo_store.dart` and bundled `assets/mini_phone`. Sends receive simulated replies; publishing, likes and comments mutate memory only. Reopening retains the demo process state; restarting the app clears that demo state. Settings no longer offers Reset phone. Wallpaper reads/saves use the World API and account-scoped local cache; device images use the same shared crop pipeline as Location covers (1:2, crop size 1500 × 3000, JPEG quality 90 or PNG when transparent, no 3 MiB input gate). Crop confirmation prepares a small in-memory preview. Apply performs full-resolution preparation (0–20%), uploads (21–90%), then saves the background (91–100%, with slow simulated progress capped at 99% until server success). A translucent mask clears from bottom to top without numbers or a spinner; the button stays loading. Saving retains the preview, and only successful full-resolution upload bytes enter the image cache. Both entry points and the route are debug-only.

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

2026-10-12 Music supersedes the fixture implementation above: the catalogue uses the formal Music API, and foreground playback uses a shared just_audio service. The service owns at most two single-track players, prepares roughly five seconds of the next song after playback starts, promotes that player on next/completion, and pauses without auto-resuming after backgrounding. No background service or full-file audio download is added. The full player and Home card share single-line bounce-scrolling metadata, buffered seek bars with 48px interaction areas, and 200ms cover transitions that immediately remove the previous song's target. Music covers use the project's XL CDN size selection with DPR capped at 1.5; next-cover prefetch uses the same provider and decoder dimensions as rendering. Reduced motion disables scrolling and cover fades. Catalogue and playback failure/retry states remain; loading/buffering text is hidden.

Music validation (2026-10-12): 60 focused service/page/widget/shared-image tests passed, targeted analysis found no issues, and the production-flavour Android arm64 debug APK built successfully. Pixel 6 checks confirmed real catalogue playback, single-line bounce motion, buffered progress, track taps and enlarged-area dragging, Home controls, previous-to-start, manual/automatic next, standby promotion, and background pause without auto-resume. The standby remained silent; its observed buffer was 32.731 seconds because the platform reads chunks despite the five-second target. Delayed/failed cover loading, 200ms removal, rapid switches, stale image results, reduced motion, large text and hidden prefetch were covered by controlled widget/service tests; no device network-fault injection or acoustic gap measurement was performed.

Music navigation controls now start playback in the foreground after previous/next, including from pause or before the first play. Previous beyond three seconds restarts the current song and plays it. Single-track navigation reuses the prepared player. Backgrounding or pausing while a requested song loads still prevents delayed autoplay.
