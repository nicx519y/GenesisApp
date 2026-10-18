# World chat timeline — 2026-10-16

Baseline: origin/main e53e0b99. Worktree GenesisApp-chat-timeline; branch feature/chat-world-timeline-20261016. Previous working trees are preserved.

Approved behavior: entering B joins B and emits its normal entry message once. Upward browsing follows the entire World chronology, including repeated visits A/B/C/A/B. Visible history determines header/background only; send/entry/reply actions remain bound to joined B.

Implementation:
1. Install unmodified main internal debug build on connected V2121A.
2. Add page-owned read-only per-leaf V2 history loader with bounded concurrency, independent cursors, generation invalidation and complete-window watermark. No internal or backend changes. Retry failed pages without declaring history exhausted.
3. Parse history using each source location's context; deduplicate against live current-room projection and preserve pending local tail/candidate controls.
4. Observe visible message IDs using anchored list's existing post-layout geometry; update display-only location metadata. Keep existing scroll coordinator and compose/send semantics.
5. Hook upward pagination into world history; keep preview screens excluded. Preserve own source location on parsed Tick payloads.
6. Format and targeted static analysis; rebuild/hot-restart actual phone preview. No tests added/run unless requested. Verify runtime evidence without claiming unobserved backend behavior.

Risks: fan-out on very large worlds; archive edits must not target joined-room operations. Paging must not introduce chronology holes. Deletions/clear-history must invalidate the page-owned snapshot. No new localized strings required.

## Other-location collapsed history
- Split the projected chronology into contiguous location visits. All segments belonging to the actual joined room stay expanded; other segments start collapsed and can be opened independently.
- Apply folds only in the render plan; retain canonical messages and reply/action state. Preserve segment identity while earlier history arrives.
- Explicit expand/collapse navigation targets the chosen segment tail/header, using pinned measured geometry and command-generation cancellation. Clear prior reply tail reservations. Do not jump to the entire World tail or reuse a reply-position hold.
- Keep an expanded section's collapse control outside the scrollable viewport content, switching its target while reading another expanded section. Inline path controls remain tappable.
- Format/analyze and hot-restart phone preview; no tests unless requested.

## Approved refinement: shared Global, local events and movements
- Preserve actual chat/entry chronology; Tick broadcasts alone do not create a location segment. Buffer a room's Tick rows until that room has a conversation segment; leave unvisited-room Tick-only data to Events.
- Deduplicate completed Tick cards by (tickNo, locationId), retaining sub-tick contributions inside that location card. Merge Global text/statuses once into the first displayed card for the Tick.
- Keep event paragraphs constrained to that card's location. Carry oldLocationId through movement VMs and include only moves whose source or destination is that location; dedup by character/source/destination. Existing localized went-to/came-to strings reflect departure/arrival.
- Preserve source IDs and live queue state. No backend/send/entry behavior changes; no new translatable copy.
- Separate Tick projection into location_chat_tick_projection.dart to keep pagination independent. Review projection edge cases, run format/targeted analyze and hot restart. No tests requested/run.

## Approved folding refinement and verification
- Expansion now targets section start; user scrolls down to read. Inline and fixed bottom-right collapse controls use dark pill, localized label and single chevron.
- Last-two-level separators use fixed12px typography and wrap rather than scale. Preserve bold leaf and location icon.
- User authorized checks:100 targeted history/geometry/scroll tests passed,52 localization checks passed. Phone expansion/collapse and reading verified in a bounded live scenario.
- Prior duplicate-key runtime exception remains unconfirmed/unreproduced after restart; capture first full exception before further fixes. Feishu sync for two new localized keys is pending external access.

## Approved separator / sticky reading revision
- Preserve last-two-level fixed12px path, left-align it before a rule and a transparent inline toggle. Remove lower-right floating action.
- Expand/collapse navigation captures the separator row's current viewport offset before changing the render plan; preserve that offset through geometry refinement. A header already above the viewport collapses at the pinned top.
- Use the anchored list's measured row geometry to identify an expanded foreign section crossing the viewport top. Render its opaque separator as a top safety surface; remove/switch it at section boundaries. Avoid adding scroll padding when it appears.
- Exclude folded/hidden rows from reading-location selection; all-folded state uses joined-location header/background. Expanded sections retain existing midpoint background transitions.
- Touch history_sections, message_viewport, scroll_coordinator, world_history only; preserve backend and send state. Static analysis and hot restart for preview. Existing localization doc sync remains pending; no new copy in this revision.
