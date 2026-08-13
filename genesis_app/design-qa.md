# Design QA

- Reference: `codex-clipboard-f5d4f963-2893-4308-8fcc-4c5b3fb76084.png`
- Surface checked: main bottom-navigation Create action
- Reference control bounds: 42 × 33 px, 4 px from the top edge
- Implementation bounds: 42 × 33 logical px, 4 logical px from the top edge
- Fill: `#FF2442`
- Shape: continuous-corner rectangle (`ContinuousRectangleBorder`), not a circular-radius rounded rectangle
- Content: centered white Material add icon; no visible Create label
- Interaction: full navigation cell remains tappable and keeps the Create accessibility label

Visual comparison found no P0, P1, or P2 mismatch in the requested control.

final result: passed
