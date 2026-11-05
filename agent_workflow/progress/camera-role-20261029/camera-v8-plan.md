# Camera v8 layout plan — 2026-10-30

User-approved reference: Desktop/相机生图界面改版.html. Implement its camera composition with existing Worldo typography, dark surfaces and pink accents; keep the existing real API boundary.

- Refine the confirmation sheet locally: strike color, camera glyph, tighter title/body and checkbox/text spacing. Preserve preferences and callbacks.
- Camera compose: scene image viewfinder, selected-character focus frames, glass prompt along lower edge; horizontal cast below; existing real template choices below that; album / white glass shutter / scene thumbnail footer. Scene selection is a local composition preview only, never a World movement.
- Read locations from the already-fetched World snapshot, clear on account reset; no new API endpoint, fake generated photo, progress, billing or album write.
- Keep common navigation, character/avatar primitives, localization strings and generation lifecycle. Existing template dialog remains reachable from prompt action. Maintain scrolling and input reachability on small screens/keyboard/large fonts.
- Verify touched Dart, focused camera tests including lifecycle and layout, render normal/selected/keyboard states, then hot restart the current Internal Debug. No build, commit or push requested.
