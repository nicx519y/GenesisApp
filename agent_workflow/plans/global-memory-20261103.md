# Global memory and Deluxe UI — 2026-11-03

Goal: implement supplied B/C/D screens on origin/main 8d006258 in an isolated local branch. Subscription uses Subscribe.dc.html sliding cards, explicitly selected by user.

## Scope and data boundary
- World: Detail / Recap / Cast / Bonds / History / Events / Locations; shared memory content with MiniPhone.
- Recap has Timeline (Deluxe) and Summary (Premium); independent entitlements, never infer Deluxe from Premium.
- Cast forms grouped Basics/About/Story, updated fields, departed/deceased group; Bonds to-you/between-them.
- Unknown/locked content reveals structure only. Empty states preserve structure and show no update indicators.
- Frontend first: preserve production Premium purchase and existing summary requests. No invented Deluxe SKU, billing, backend writes or memory APIs.
- Examples are explicit Developer preview only, cannot populate real World stores. Normal new memory screens use locked/empty state until adapter exists.
- Me carousel and subscription double cards: Premium gold, Deluxe iridescent. Draft Deluxe prices/benefits are preview only; unavailable real checkout stays disabled with clear feedback.
- Original camera worktree, branch and source changes untouched.

## Execution
- [ ] Build/archive untouched main Internal Debug in separate baseline worktree.
- [ ] Shared memory model/access and localized view components with tests for entitlement combinations, hidden locked content, empty/departed.
- [ ] Shared membership styles/cards and sliding Subscription + Me integration; preserve existing Premium checkout.
- [ ] World/MiniPhone integration and explicit Developer preview. Maintain route lifecycle/account isolation.
- [ ] Translate only added source keys using project prepare/import workflow; generate l10n and run checks.
- [ ] Analyze changed files; focused layout/navigation tests at narrow widths/large text; render representative screens; build final local Debug.
- [ ] Record source/package paths and limits. No push/install requested in this turn.

## Validation
Test independent ownership; blocked Deluxe purchase does not call Premium service; changing slide changes plan context; locked Cast/Bonds expose no story content; newest-first capped timeline; character fields omit empties; route navigation and close preserve MiniPhone behavior. Existing summary remains accessible to Premium. Review 350/390px and 1.5x text layout.

## 2026-11-04 source-design correction

Original implementation/build milestones above were completed as recorded in checkpoint. User requested a systematic visual correction, not a new backend scope.

- Render Caps/Phone/Subscribe/MeMember from the authoritative local HTML and compare actual Flutter screenshots.
- Align shared memory typography, rows, groups, timeline, field forms, lock presentation, profile navigation/actions and linear icons.
- Align Subscribe carousel geometry, gradients, watermark, benefit typography, plan cards and Me subscription cards.
- Import four short text keys and two revised offer descriptions via the required incremental localization workflow.
- Validate targeted UI, ownership, Summary/cache boundaries, large text and source-sized screenshots. Device installation remains paused at the user's request; this visual revision is not in the old archived APK.
