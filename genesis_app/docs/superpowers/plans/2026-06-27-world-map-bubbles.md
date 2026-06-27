# World Map Bubbles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild world map bubbles as a simple derived UI from `messagesByLocation` and current AI character positions.

**Architecture:** Add a small pure selector that derives bubble candidates from chatroom state and world character positions, then render the current playable candidate in `WorldMap` anchored to the visible AI avatar. `WorldPage` owns playback timing and passes only the active bubble to the map.

**Tech Stack:** Flutter, Dart, existing `WorldChatroomService`, existing `WorldMap` and `UserAvatar` models.

---

### Task 1: Candidate Selection

**Files:**
- Create: `genesis_app/lib/pages/world/world_map_bubble_candidates.dart`
- Test: `genesis_app/test/pages/world/world_map_bubble_candidates_test.dart`

- [ ] Write failing tests for current tick filtering, AI character filtering, latest conversation per AI location, and character-position anchoring.
- [ ] Implement the pure candidate selector.
- [ ] Run the selector tests until they pass.

### Task 2: Map Rendering

**Files:**
- Modify: `genesis_app/lib/components/world_map.dart`
- Test: `genesis_app/test/components/world_map_test.dart`

- [ ] Add a minimal map bubble render model containing `characterId` and `content`.
- [ ] Render at most one active bubble next to the matching visible avatar.
- [ ] Verify a bubble is shown only when the matching avatar is present on the current map surface.

### Task 3: World Page Playback

**Files:**
- Modify: `genesis_app/lib/pages/world/world_page.dart`

- [ ] Store derived bubble candidates from `WorldChatroomState`.
- [ ] Loop through currently playable candidates with a timer.
- [ ] Pass the active bubble to `WorldMap`.

### Task 4: Verification

**Files:**
- Existing focused tests under `genesis_app/test/pages/world` and `genesis_app/test/components`

- [ ] Run Dart format.
- [ ] Run analyzer on touched files.
- [ ] Run focused candidate and map tests.
