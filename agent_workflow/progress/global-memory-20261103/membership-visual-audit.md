# Membership visual audit · 2026-11-04

Scope: C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103. Only the three membership components below, their owned widget test, and this note changed. No git operations, localization edits, generated files, shared World memory, Me shell, checkout implementation, or catalog changes.

## Source evidence

Read exact Subscribe.dc.html, MeMember.dc.html, Caps.dc.html upsell CSS and render data; compared the previous premium.png/deluxe.png/me-membership.png and the new source-subscribe.png/source-deluxe.png/source-me.png under agent_workflow/references/global-memory-20261103. Source size 390×844.

The initial task phrase “stacked vertical pricing cards” conflicts with Subscribe.dc.html line 117 and the rendered reference: its two plans are side by side, with vertically arranged content. The later instruction to follow exact CSS and supplied images is implemented as the default. Optional stackedPlans=true remains available to hosts without changing default source layout.

## Implemented

- Surface variants for subscription, compact profile, and upsell. CSS-angle gradients are computed using the paint rectangle, preserving 104/112/165 degree directions at all aspect ratios; stops and alpha values follow source. Deluxe pearl sheen no longer turns the whole card bright purple/brown.
- Subscription top 200px layer masked after 30%; crown 150×106 at right -24/top -26, opacity .3, mask 35–92%. Offer crown 176×125 at right -22/top -28, opacity .42. Profile 41px highlight and source background; profile/offer have no subscription border.
- Subscription track 314px cards, 10px gap, x16/340 then x-264/60 at 390px. 280ms cubic motion, 48px drag decision, cancellation snap-back, edge damping, inactive .85 opacity, tap-to-select. Both independent vertical scrollers remain mounted. Fade 96px, 55% stop, 200ms opacity, hidden when extentAfter<6, including no-scroll content.
- Compact equal-height two-column gem cards, original 12×18 faceted Pink/Red assets, amount and /day in one row, precise text sizes/spacing. Benefit icons use existing original inspiration/edit/badge/recharge/gem assets; book and speech bubble SVG paths copied verbatim from Subscribe source into the owned Dart component.
- White 22×6 / 6×6 pagination. Source plan card radius14, inset16/14/14, floating savings chip, selected tint/ring, consistent height. Annual billing text retains existing l10n semantics. Source CTA height44/radius13/gradient/shadow, selected localized plan plus catalog price. Active subscription is disabled. Auto-renew line and functioning existing legal routes restored.
- Offer header17px, 28px details circle, body12/17.4, two-plan teaser, 44px CTA. New optional yearlyPrice/monthlyPrice/previewDraftOffers parameters are compatible. With onPlanSubscribe, selection is retained and forwarded; without it in production, plan taps call onDetails and no selected state is falsely retained. Explicit Developer preview enables harmless local plan selection even with navigation-only callbacks, matching the source Yearly default. Default real usage has no fabricated prices. Deluxe remains unavailable, never mounts a checkout.
- Me 82px minimum height, 16px heading, inline active chip, source background/button colors, expired chip beside date without an incorrect “Expires” prefix, local date formatting retained. Large text can grow. Sorting and tier-specific callbacks unchanged.

## Verification

- Targeted Dart format passed for all four Dart files.
- Targeted direct Dart analyze passed with “No issues found!” for the three changed library files and memory_membership_test.dart. Final rerun after the CTA label change is recorded in the agent response.
- No Flutter tests, builds, or device operations run, per main-agent coordination. No git commands run.
- Current implementation screenshots have NOT been generated in this subtask. Main supplied content/world-cast-locked.png and it was inspected: it shows the new offer surface and teaser, but the old caller still omitted previewDraftOffers. Main is wiring that default-false flag only through Developer previews. Offer crown opacity is exactly .42; its top highlight was corrected from a fixed height to source 50%. Source comparison is evidence for measurements, not a final rendered-app acceptance.

Main should run serially from genesis_app:

    flutter test test/components/memory_membership_test.dart
    $env:MEMORY_SCREENSHOTS = '1'
    flutter test test/pages/world/global_memory_navigation_test.dart
    flutter test test/components/world_memory/world_memory_visual_test.dart

The existing build/global-memory-review images must be regenerated before final visual acceptance. Also rerun the existing World/Phone lock-card layout and entry/navigation tests because their teaser is now taller.

Updated stale assertion: the navigation-only lock-card test previously expected no MemoryMembershipPlanSelector. It now expects the teaser selector, no prices, no retained selection, and a details callback on a plan tap. Added source geometry + active purchase guard coverage. Existing purchase-forwarding, no-Deluxe-checkout, nine Me states, and large-text tests retained.

## Remaining fidelity limits owned by the main task

2026-11-04 parent follow-up: the short monthly allowance, standalone period, billed-annually note, Deluxe Me allowance and two source offer paragraphs below have now been localized and integrated. Badge labels use Premium/Deluxe. Explicit Developer lock previews pass draft prices; normal callers still default false. See design-qa.md for the final review; the following bullets describe the earlier handoff state.

- Existing localization has no short “Up to {amount} Gems Monthly” row. The original localized offer sentence is retained, so this row is longer and adds height compared with source. Do not truncate or derive translated phrases by parsing English.
- Existing yearly billing localization is “{price}, Billed annually”; source has separate /year and “Billed annually”. No untranslated English period labels introduced. There is no /year or /month standalone localized key available in this component scope.
- Existing badge benefit placeholder receives the localized Worldo Premium/Worldo Deluxe title, while source says Premium/Deluxe. Existing Deluxe Me copy is the tagline rather than source allowance sentence. Existing offer paragraphs differ from source wording. These need approved source-copy localization by the owner if exact text fidelity is required.
- Developer preview keeps its existing header and draft notice. Production wallet headers and Me shell are outside this task; their position/viewport must be evaluated by the main agent.
- Offer real callers need to supply official catalog prices; explicit Developer-only callers can opt into previewDraftOffers. No draft values leak through default constructors.
- Me's host-owned outer padding/clip and scroll shell are unchanged. Current profile implementation remains natural horizontal scrolling; the exact custom snapping/50px edge reveal is implemented for Subscription only.

## Changed paths

- C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/components/gems/memory_membership_style.dart
- C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/components/gems/memory_membership_carousel.dart
- C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/lib/components/gems/memory_membership_offer_card.dart
- C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/genesis_app/test/components/memory_membership_test.dart
- C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103/agent_workflow/progress/global-memory-20261103/membership-visual-audit.md


