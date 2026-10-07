# Mini phone UI implementation plan

**Goal:** Reproduce the supplied mini phone v4.1 as native Flutter screens for debug style iteration.

**Architecture:** A debug-only route owns a memory-only demo store. Bundled design assets, demo-prefixed identities and independent navigation keep all writes outside real chat, posts, accounts and network services. Reopening retains the current process demo; Reset restores its seeds. Restart clears it.

**Reference:** `C:/Project/worldo/界面设计/mini phone/app.js`, styles.css, v2.css, v3.css, v4.css. v4.1 takes precedence; no new layout strategy.

**Tech stack:** Flutter, bundled Inter, flutter_svg, existing image_picker dependency, Genesis colour/blur tokens.

- [x] Build and install origin/main 541a5e44 internal debug APK in the isolated feature/miniphone-ui-20261007 worktree.
- [x] Add mini_phone_demo_store.dart: characters, chats, unread, posts, comments, likes, wallpaper and reset; no production services or persistence.
- [x] Add mini_phone_ui.dart: source SVGs, avatar, glass surfaces, navigation and typography.
- [x] Add mini_phone_page.dart and page parts: Home; Messages/Contacts/Chat; Posts/Comments/Create; Photos/Settings/viewer.
- [x] Import exact source assets into assets/mini_phone/; register directories in pubspec.yaml.
- [x] Add debug-only World map handset and Developer preview button. Contacts is available through Developer preview and a chat profile, without changing the four-app dock or adding a Messages plus button.
- [x] Preserve empty/disabled send states, 500-character post/comment limit, 1000-character chat limit, JPG/PNG/WebP selection with 3 MB cap and original-image viewing. Sending/likes/posts/comments are demonstrative local mutations, including seeded simulated chat replies.
- [x] Format and analyze touched files; build/install final internal debug APK. Check runtime startup and provide the new hot reload working directory. User reviews styles before system-wide regression.

**Isolation contract:** Entry points and the route require kDebugMode. UI identifies Demo in navigation; Settings explains that no messages/posts are sent to the server. IDs start mini-demo-. No API client, session data, server world ID, backend endpoint, network images or production database is referenced.
