# Membership UI handoff

Workspace: `C:/Project/worldo/frontend-debug/GenesisApp-memory-20261103`.
Branch: `feature/global-memory-deluxe-20261103`; base `8d0062581117513aeefe9dc507759e4347a4cd18`.
No commit or push. Existing parent changes preserved.

## Interfaces
- `memory_membership_style.dart`: public `MemoryMembershipTier { premium, deluxe }` and shared gold/pearl presentation.
- `MemoryMembershipOfferCard({required tier, required onSubscribe, required onDetails, onPlanSubscribe})`: after integration review, navigation-only callers see no selectable plans. Optional `onPlanSubscribe(bool yearly)` enables local per-tier Yearly/Monthly selection and receives it instead of `onSubscribe`. No price/SKU invented; no Premium technical note.
- `MemoryMembershipSubscriptionCarousel`: `premiumActive`, `deluxeActive`, `premiumExpiry`, `deluxeExpiry`, `initialTier`, required void `onPremiumSubscribe` / `onDeluxeSubscribe`, optional `onPremiumPlanSubscribe(bool yearly)`, `premiumYearlyPrice`, `premiumMonthlyPrice`, `previewDraftOffers=false`. Pure presentation, no services.
- `MemoryMembershipProfileCarousel`: same independent ownership/expiry values, plus `premiumExpired` / `deluxeExpired`; required two void callbacks; `previewDraftOffers=false`. Active memberships sort first. Natural-height horizontal scrolling.
- `MemoryMembershipPreviewPage({premiumActive=false, deluxeActive=false, initialTier=premium})`: pure Scaffold compatible with parent gallery import. Single top draft notice; header action switches Subscription/Me. No account state or billing writes.

## Integration
- `GemWalletPage.showDeluxeInitially=false` passed to `MemoryMembershipWalletContent`; route arguments owned by parent.
- Wallet adapter refreshes the existing catalog using `loadForEntry()` on entry/reentry; uses existing account-scoped cache for immediate display and follows session changes. No new service/network implementation.
- Premium action forwards selected month/year via optional callback to `ProSubscriptionContent.initialPlanCode`. The original component changed only to initialize `_plan`; purchasing, eligibility, store prices, orders and success behavior are retained.
- Original checkout remains separate inside the wallet. Carousel stays mounted offstage to preserve per-tier selection on return. Deluxe callback only displays unavailable toast and cannot mount Premium checkout.
- Me shell/library now compose the shared profile carousel and independently route each card. Real adapter uses current Premium state; Deluxe is always false.

## Localization / assets
- `membership-strings.json`: standard ARB entries and metadata for parent translation/generation. Existing keys reused for plans, status, expiry, Subscribe, legal labels and Gems labels.
- IMPORTANT: JSON `memoryMembershipDeluxeUnavailable` was shortened to `Deluxe is not available yet.` during integration review; parent must use latest JSON rather than earlier long source copy.
- `assets/icons/memory_crown_deluxe.svg` copied from approved design with SVG filter definitions and references removed. Parent owns pubspec declaration (confirmed added by parent).
- No ARB, generated file, service, platform, network, router, World, MiniPhone, or Developer integration file edited by this subtask.

## Validation
- First seven pure widget tests passed: lock-card callbacks, independent selections, four ownership combinations at 350px/1.5x text, and Deluxe-first Me ordering.
- New regression reproduced missing catalog load (`expected 1, actual 0`); fixed entry loading and Monthly forwarding. Nine-test rerun PASSED, including real-loader entry display, Monthly selected in original checkout, and Deluxe never opening Premium checkout.
- `git diff --check` passed; targeted Dart format completed.
- Sandbox Flutter/cache and analyzer runs stalled; canceled own sessions and retried with host permissions. Targeted analysis completed with no errors and 9 info lints (8 test imports, 1 brace); all 9 corrected. Parent owns final consolidated analysis; no duplicate analyzer left running.
- Final additional lock-card conditional-plan/Monthly-callback test PASSED after the conditional-plan correction (9 + 1 targeted tests passed across the two runs). No all-project test suite or build run by this subtask.
- Final JSON parse: 15 source keys, all 15 have metadata. Targeted diff whitespace check passed. Parent's exact SVG asset declaration verified in pubspec.

## Changed files
- `genesis_app/lib/components/gems/memory_membership_style.dart`
- `genesis_app/lib/components/gems/memory_membership_offer_card.dart`
- `genesis_app/lib/components/gems/memory_membership_carousel.dart`
- `genesis_app/lib/components/gems/memory_membership_wallet_content.dart`
- `genesis_app/lib/components/gems/memory_membership_preview_page.dart`
- `genesis_app/lib/components/gems/pro_subscription_content.dart` (8 added lines only)
- `genesis_app/lib/pages/gems/gem_wallet_page.dart`
- `genesis_app/lib/components/me/user_profile_library.dart`
- `genesis_app/lib/components/me/user_profile_shell.dart`
- `genesis_app/assets/icons/memory_crown_deluxe.svg`
- `genesis_app/test/components/memory_membership_test.dart`
- This checkpoint and `membership-strings.json`.
