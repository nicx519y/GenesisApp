# worldo Gems Product Design

Date: 2026-07-05
Branch: `main_gems`
Status: design draft for Figma and Flutter static prototype

## Scope

This phase designs the Gems experience for worldo without backend implementation.
Flutter work should be a high-fidelity static prototype with page-local fixture data only.
Do not add new API resources, repositories, mock services, payment SDKs, or local deduction logic.

## Goals

- Show the user's Gem balance from the Me page.
- Create a Gem Wallet page that combines paid top-up and free Gem tasks.
- Create a Gem Records page for future income and spending history.
- Add a Memory & Model page that controls model and memory choices for world interactions.
- Keep world chat and progress flows visually calm by avoiding per-action cost labels in the main flow.
- Document backend responsibilities so frontend and backend can connect later without a fake client contract.

## Non-Goals

- Real payment channel integration.
- Backend API implementation.
- Local mock service or simulated business repository.
- Subscription entry.
- On-message or on-progress visible cost display in the primary chat/map UI.

## Design System Requirements

Follow `worldo-design-spec.md` strictly:

- Mobile frame: `375 x 778`.
- Page margin: `20px`; content width: `335px`.
- Background: `#FFFFFF`.
- Primary action red: `#F42C47`.
- Text hierarchy: `#333333`, `#444444`, `#666666`, `#999999`.
- Body copy: `12px / 18px`.
- Top title: `16px` semibold.
- Prefer whitespace, dividers, image/icon-led modules, and restrained cards.
- Main app pages reserve bottom navigation space; pushed utility pages use a centered title header and back affordance.

## Information Architecture

### Me Page Entry

Add a compact Gem balance entry near the top account area of the signed-in Me page.

Content:

- Gem icon.
- Current balance, for example `430`.
- Label: `Gems`.
- Chevron or subtle tap affordance.

Behavior:

- Tapping opens `Gem Wallet`.
- If signed out, the entry is hidden or replaced by sign-in guidance, matching existing Me behavior.

### Gem Wallet

Purpose: one page for both buying Gems and earning free Gems, so users see top-up options whenever they claim free rewards.

Module order:

1. Balance
2. Top-up packages
3. Starter tasks
4. Bonus tasks
5. Daily tasks
6. Join us tasks

Header:

- Center title: `Gems`.
- Back icon on the left.
- Records icon/button on the right.
- No subscription entry.

Balance module:

- Shows current Gem balance prominently.
- Uses a subtle red/pink highlight area inspired by the reference, adapted to worldo's white visual system.
- Avoid a dark full-page treatment; this should still feel like worldo.

Top-up packages:

- Six package tiles in a 3-column grid.
- Each tile shows Gem amount, optional promotion tag, and price.
- Example package labels: `+500`, `+1100`, `+4400`, `+8800`, `+16500`, `+55000`.
- Top-up buttons are visual placeholders in this phase.
- Tap behavior: page-local toast or non-persistent pressed feedback, such as `Payment coming soon`.

Starter tasks:

- New-user one-time tasks.
- Example tasks:
  - `Create your first worldo`
  - `Join your first world`
- Reward displayed on the right, for example `+50`.
- CTA uses red pill button.

Bonus tasks:

- Occasional or deeper engagement tasks.
- Example tasks:
  - `Invite a friend to a world`
  - `Write a comment`
  - `Share a worldo`

Daily tasks:

- Repeatable daily tasks.
- Example tasks:
  - `Daily check-in`
  - `Send a message`
  - `Progress a world`
- Claimed tasks show disabled state.

Join us tasks:

- Social/community follows.
- Example entries:
  - `Discord`
  - `Instagram`
  - `TikTok`
  - `YouTube`
  - `X`
- Each row shows platform icon placeholder, reward, and `Follow` CTA.

### Gem Records

Purpose: future transparent ledger for all Gem movement.

Header:

- Center title: `Gem Records`.
- Back icon on the left.

Filters:

- Segmented text tabs: `All`, `Earned`, `Spent`, `Top-up`.
- Active state uses worldo red underline.

Record rows:

- Title: action name, such as `Daily check-in`, `Message in #Moonlit Market`, `World progress`, `Top-up package`.
- Metadata: timestamp and source.
- Amount: positive values in red or strong text with `+`; spent values in neutral/darker text with `-`.
- Empty state uses soft centered copy, not a heavy card.

### Memory & Model

Entry points:

- World map top-right utility icon.
- Location chat top-right utility icon.

Purpose:

- Let users choose max memory limit and model.
- Show next estimated Gem cost inside this settings page.
- Keep chat send and world progress controls free of explicit cost labels.

Header:

- Back icon on the left.
- Center title: `Memory & Model`.
- `Save` text action on the right.

Memory section:

- Current memory usage summary, for example `2K`.
- Max memory limit slider.
- Recommended discrete values for design: `4K`, `32K`, `156K`, `512K`, `1M`.
- `Apply to all characters` toggle.
- `View details` row reserved for future explanation.

Model section:

- Section title: `Choose model`.
- Optional `View details` link.
- Grouping:
  - `Recommended`
  - `Basic`
- Each model card shows:
  - Model name.
  - Optional `Hot` or `New` badge.
  - Estimated next message cost.
  - Short description.
  - Cost range based on memory, for example `4-320 gems`.
  - Radio selected/unselected state.

Example models for static design:

- `Top Pick V3` with `Hot`, estimated next message `4 gems`.
- `Top Pick V3.5`, estimated next message `4 gems`.
- `Luxury Selection V4.0` with `New`, estimated next message `9 gems`.
- `Sake Pro` with `New`, estimated next message `3 gems`.
- `Sake Max`, estimated next message `4 gems`.
- `Sake V2` with `Hot`, estimated next message `1 gem`.
- `Water` with `New`, estimated next message `1 gem`.

Save behavior in this phase:

- Updates only page-local selected state while the page is open.
- Shows non-persistent confirmation feedback.
- Does not write to a service or API.

## Product Logic

### Gem Acquisition

Users can get Gems from:

- Top-up packages.
- Starter tasks.
- Bonus tasks.
- Daily tasks.
- Join us tasks.

Top-up in this phase:

- Visible as package tiles.
- Payment channel is not connected.
- Product copy should avoid promising successful purchase.

Task reward logic for future backend:

- Backend decides eligibility, progress, claimability, reward amount, cooldown, and final grant.
- Frontend displays returned states.
- Frontend should never grant authoritative balance locally.

Task states:

- `available`: user can act.
- `in_progress`: progress count shown, such as `0/3`.
- `claimable`: task can be claimed.
- `claimed`: task completed for its period or forever.
- `locked`: unavailable until a condition is met.

### Gem Spending

Gem spending applies to:

- Each location chat message.
- Each world progress action.

Cost inputs:

- Selected model.
- Selected max memory limit.
- Actual current memory usage.
- Action type: message or progress.
- Future backend pricing rules.

User-facing rule:

- The main chat and progress UI do not show cost on every action.
- The Memory & Model page shows estimated next cost.
- If the backend rejects an action due to insufficient Gems, show a clear shortage prompt and route to Gem Wallet.

Authority:

- Backend is the source of truth for balance checks, pricing, and deduction.
- Frontend estimates are informational.

### Balance States

The UI should support:

- Normal positive balance.
- Low balance.
- Insufficient balance.
- Loading balance.
- Balance unavailable.

For this static prototype, use normal balance only, with visual placeholders for future states in the MD and Figma annotations if needed.

### Error Handling For Future Integration

Expected future backend errors:

- Insufficient Gems.
- Task not claimable.
- Task already claimed.
- Payment order unavailable.
- Pricing changed.
- Model unavailable.
- Memory limit unavailable.

Recommended frontend handling:

- Show concise toast or bottom sheet depending on severity.
- For insufficient Gems, lead to Gem Wallet.
- For pricing changed, refresh estimate and ask the user to retry.
- For unavailable model/memory, reset to backend recommended default.

## Future Backend Contract Notes

These are product contract notes, not current frontend implementation tasks.

Wallet:

- Fetch balance.
- Fetch top-up packages.
- Fetch task groups and task states.
- Claim task reward.
- Fetch Gem records.

Pricing:

- Fetch model catalog.
- Fetch current memory/model setting for a world or character.
- Estimate next message cost.
- Estimate next progress cost.
- Save memory/model setting.

Spending:

- Message send endpoint performs authoritative balance check and deduction.
- World progress endpoint performs authoritative balance check and deduction.
- Responses should include updated balance when possible.

Records:

- Each grant or spend should create an immutable ledger item.
- Records should include amount, type, source, world/location context when available, timestamp, and balance after transaction if backend supports it.

## Figma Deliverables

Create high-fidelity mobile frames in the `G设计` Figma file:

- `Gem Wallet`
- `Gem Records`
- `Memory & Model`
- Optional small Me page entry component/sample frame if space allows.

Frame requirements:

- `375px` width.
- Use `20px` horizontal margins and `335px` content width.
- Follow worldo white/red/gray design system, not the dark competitor palette.
- Use competitor references for structure and hierarchy only.

## Flutter Prototype Rules

When implementation starts after Figma approval:

- Add route entries and pages.
- Use static fixture data local to the page or a UI-only fixture file.
- Do not create backend API classes.
- Do not create mock service/repository abstractions.
- Keep action handlers local and clearly replaceable.
- Add tests only for routing and stable page rendering if needed.

## Acceptance Criteria

- Me page has a visible Gem balance entry for signed-in users.
- Gem Wallet page matches the approved Figma layout and module order.
- Gem Records page is reachable from Wallet header.
- Memory & Model page is reachable from world map and location chat.
- Main chat and progress controls do not show per-action cost labels.
- Static prototype does not add backend API, repository, mock service, or payment SDK code.
- Product logic document explains future backend authority for pricing, balance, and deduction.
