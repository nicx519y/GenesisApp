# Design QA

- Reference: `codex-clipboard-950be4d8-19b9-4bb9-9c11-37ba58818b65.png`
- Surface checked: main bottom-navigation Create action
- Implementation bounds: 42 × 33 logical px
- Fill: `#FF2442`
- Shape: continuous-corner rectangle (`ContinuousRectangleBorder`), not a circular-radius rounded rectangle
- Content: 26 px rounded Material add icon with increased white stroke weight; no visible Create label
- Alignment: the button center matches the vertical center of the neighboring icon-and-label groups
- Interaction: full navigation cell remains tappable and keeps the Create accessibility label

Visual comparison found no P0, P1, or P2 mismatch in the requested control.

final result: passed
