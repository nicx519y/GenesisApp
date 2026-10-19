# Origin preview role entry

- Date: 2026-10-11
- Workspace: frontend-debug/GenesisApp/genesis_app
- Branch: feature/message512-style-20260923; existing membership debug and SDK edits retained.
- Default collapsed role CTA now uses a shared input-looking field; tap expands existing role sheet.
- Location preview with no opening messages shows World Brief and a link to the resolved opening location; bottom field opens existing role picker.
- No API, launch payload or backend changes.
- Checks: Dart format; git diff --check; targeted analyze reports only two existing unawaited_return_in_try_block warnings in unchanged launch code.
- Phone attached from this workspace; hot restart completed in 5793ms.
- Not committed or pushed; no full tests requested this round.

## Correction
- Opening recommendation card shows image and full location hierarchy; tap navigates directly to the opening location.
- Location now reuses editable launch composer and floating-sheet role pill with local portrait-card selection.
- Targeted analyze: only two pre-existing async warnings; no new issues.

## Inline role correction
- Full existing role portrait cards and selection heading are now docked above the editable composer on the location page; selecting no longer opens a picker sheet.
- Click failure root cause: shared empty-state IgnorePointer. Added opt-in emptyStateInteractive (default false), enabled only on Origin preview.
- Targeted analyze for location preview and chat viewport: No issues found.

## Chatroom alignment
- Preview uses Location Chatroom styling and parent-location header, formal Origin character location fields for the occupant roster.
- Recommendation copy: Start at Story Opening. Card uses parent path then opening name, two rows.
- Role title: Start here by selecting your role. Opening messages and role cards share one scroll viewport; input remains docked.
- Optional previewContent/previewOccupants preserve standard joined-chat defaults.
- Targeted analyze on all touched part files: No issues found.

## Compact spacing
- Opening recommendation: Begin your story here.
- Location image 40x60 (2:3 portrait), card padding 8 (previous 12), two single-line labels; nominal card height 76 (previous 96).
- Inline role bottom spacing 8 (previous 28), indicator gap 8 (previous 14); original floating-sheet spacing preserved.
- Targeted analyze: No issues found.

## Recommendation and module spacing correction
- Recommendation title now names actual opening location: Recommended start: [location]. Role title: Start by selecting your role. Both centered 14/w600/1.2 primary text.
- Removed duplicate role pill only from inline location composer; role module bottom padding 4, internal indicator gap restored to original 14.
- Location composer bottomSafeAreaInset explicitly 0; original sheet and joined chat unaffected.
- Targeted analyze: No issues found.

## Restore role pill
- Restored small role-selection pill above the location input; retained module bottom padding 4 and zero bottom safe inset.
- Targeted analyze: No issues found.

## Three-line card and chat typography
- Opening card first line uses actual character location fields; singular is / plural are now at, followed by parent path and leaf location.
- Brief/heading/location text use shared Chatroom bubble style, role-name and path use shared sender/system styles.
- Inline module indicator gap 4, bottom padding 0; retained role pill, composer top padding 2 (sheet defaults unchanged).
- Targeted analyze: No issues found.

## Measured role gap correction
- Device screenshot confirmed large blank space below indicator. Root cause: role section Column default MainAxisSize.max inside SliverFillRemaining.
- Inline role section now opts into shrinkWrap (MainAxisSize.min); sheet defaults unchanged. Restored indicator gap 14, small pill/input top spacing to kLocationChatStyle defaults, module bottom gap 4.
- Card first line now uses Chatroom body 14/1.4 instead of sender-name label 11/1.0.
- Targeted analyze: No issues found; hot restart completed.

## Shared location card
- Added ChatLocationJumpCard used by Origin recommendation and both ordinary/tick character movement rows. Name bold, action regular, path and location redSecondary, first line wraps.
- Portrait slot 40x60 retained for missing/loading/failed images with location SVG fallback. Real-chat mention catalogue now carries formal image/icon resource.
- Origin preview composer plate/background blur removed (transparent); input and role pill remain, bottom system inset remains zero.
- Targeted analyze: No issues found. No full tests requested.

## Input safe area and independent movement cards
- Preview composer uses floating-sheet surface style and input-only system bottom inset; role region stays outside the input surface.
- Parent location path and card chevron gray; destination pink preserved.
- Tick movement cards now siblings below Tick surface, retaining grouped movement data and navigation callbacks; removed internal Tick movement separator.
- Targeted analyze: only existing curly-braces lint in untouched copy-text helper.

## Unified World preview dock and card sizing
- Tick removed avatar-side extra inset and white outline; movement cards use full narrator column width.
- Location parent path 13 with trailing >; pin SVG fallback replaces room/isometric asset. Destination remains pink and arrow gray.
- World preview keeps actual expanded composer visible in collapsed/expanded states; old faux-field overlay hidden, focusing expands role sheet. Shared controller subtree retained.
- Origin sheet/location dock now zero extra bottom inset and corrected height reservation; input standard bottom padding remains, role region transparent above.
- Targeted analyze: only existing copy-text curly-braces info; hot restart completed.

## Compact status-card surface and floating role overlay
- Movement cards align to scene Tick location-status column (14 content + 23 paragraph left, 14 right); same darkCardBackground/radius8/padding11x9 as Tick status cards.
- Backend default map image URLs and local map_default assets treated as placeholders, rendering pin SVG rather than Worldo default image.
- Origin location role pill moved into composerTopOverlay; actual input sole dock with zero extra bottom inset. Disabled LocationChatComposerExtension only for Origin preview via default-preserving opt-in.
- Scroll content reserves 42 for floating role pill; targeted analyze clean.

## Movement cards back inside Tick / unified role position
- Grouped location cards restored inside Tick after horizontal divider; no extra movement inset, matching Global status-card column.
- Removed separate location role overlay/reserved 42; location and preview sheet both use same launch composer with role selector enabled, same style and zero extra bottom inset.
- Targeted analyze: existing copy-text brace info only.

## Opening composer mask and location line spacing
- Location preview composer outer fill and blur disabled; input surface and shared role/composer geometry retained, bottom inset remains zero.
- Location path and leaf name now one rich-text paragraph at 1.3 line height without extra inter-line gap.
- Targeted Dart analyze: no issues; format completed. No tests run for this UI iteration.

## Opening viewport clipping fix
- Role pill moved from fixed composer Column into viewport overlay; only input now reduces viewport height. Scroll content reserves 42px so role cards remain reachable under floating pill. Overlay fills width, retaining original inset.
- Location portrait reduced 40x60 to 34x51 (2:3); shared text spacing unchanged.
- Targeted analyze no issues; formatted. UI device preview pending visual review.

## Role pill width and keyboard visibility
- Shared role region explicitly aligns pill left with intrinsic width despite overlay full-width constraints.
- Every location preview fades big role cards out and disables taps while keyboard inset is positive; retains role widget/selection.
- Parent location path font 13 to 12, destination remains 14, line height 1.3.
- Targeted Dart analyze no issues; formatted.

## Preview location glass
- Added opt-in glass surface to shared location card; preview enables it with light blur (4) and darkCardBackground alpha .72. Tick cards retain opaque style.
- Targeted analyze no issues; format/diff check completed.

## Unified location glass revision
- Removed preview-only flag and composer-button blur wrapper. Both preview and chat location cards use ChatStableBackdropSurface, Tick fill 0x99151517 and Tick blur sigma14, radius8. Existing geometry retained.
- Targeted analyze no issues; formatted and diff checked. On-device appearance still requires visual review.

## Restore location fill
- User rejected Tick fill substitution. Restored previous location glass gray (darkCardBackground alpha .72); kept shared backdrop blur14. No geometry changes.

## Match Global child-card surface
- Authoritative _TickStatusGroup uses opaque darkCardBackground, radius8, padding11/9, no child blur. Restored shared location card to those exact surface values; removed independent blur and alpha. Tick outer glass retained unchanged.
- Previous glass experiments superseded. Targeted analyze clean.

## Add blur only on Global-matched card
- Wrapped shared location card in ChatStableBackdropSurface (GenesisBlur.strong14). Existing opaque darkCardBackground/radius8/padding11x9 untouched, per explicit user request. Opaque fill masks visible backdrop contribution; user informed.
- Targeted analyze clean; no tests requested.

## Smaller location placeholder pin
- Shared no-image pin reduced22 to18; portrait placeholder34x51 unchanged. Targeted analyze clean.

## Tick movement heading
- Added Character movement heading above movement cards within Tick after divider, reusing _ChatMovementIcon and bodyStrong section heading typography; 8px gap to cards. No data logic changes.

## Movement icon direction
- Mirrored movement painter vertically: bottom-left to top-right; stroke/size/color unchanged. Targeted analyze clean.

## Publish snapshot 2026-10-11
- Branch: feature/origin-preview-ui-20261011, based on ffc2a4b2 (current working revision; no rebase/fetch merge).
- Includes all current application and existing test changes: debug membership override; Origin preview input/inline roles/opening navigation and actual occupants; keyboard role-card visibility; shared location card and map-image pin fallback; Tick movement grouping/heading/icon; chat viewport overlay adjustments.
- Shared location card: Global child-card fill, radius8, padding11/9; backdrop blur14 added without changing opacity per user request. Portrait34x51, no-image pin18, parent path12 and leaf14 at line-height1.3.
- Excludes local analysis_options.yaml and pubspec.lock auto-resolution changes; both retained untouched locally.
- Verification: targeted analyze has two pre-existing unawaited-return warnings and one pre-existing brace info, no errors; diff check clean. No tests run for this publish request. Production arm64 release build in progress.
- Push target: origin (nicx519y/GenesisApp), new branch only.
