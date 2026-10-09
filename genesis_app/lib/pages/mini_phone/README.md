# Mini phone style preview

Base: origin/main 541a5e44. Branch: feature/miniphone-ui-20261007.

Open from the debug World map handset or Developer → button → Preview Mini phone.
Home provides Messages, Posts, Photos and Settings. Tap a chat header to view Contacts. Posts provides author filters, Create, Comments and full-image viewing.

All characters, chats, notifications, photos and posts come from `mini_phone_demo_store.dart` and bundled `assets/mini_phone`. No production account/world identifiers, API clients, database or upload service are used. Sends receive simulated replies; publishing, likes and comments mutate memory only. Reopening retains the process state; restarting the app or Settings → Reset phone clears it. Both entry points and the route are debug-only.

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
