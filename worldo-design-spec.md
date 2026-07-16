# worldo Design Spec

Date: 2026-06-09
Source: Figma file `stitch trial`, Page 1
Brand note: the logo name is `worldo`.

## 1. Product Direction

worldo is a mobile-first story/world creation and discovery app. The current UI supports browsing worlds, reading origin details, tracking story progress, discussing worlds, messaging users, and signing in to unlock personal Origins and Worlds.

The product tone is lightweight, social, narrative, and game-adjacent. It should feel like a content community with strong fantasy/story imagery, not like a generic productivity app.

## 2. Canvas And Layout

Primary target frame:

- Mobile portrait: `375 x 778`
- Detail scroll page observed at: `375 x 962`
- Status bar: `44`
- Top title/search zone: starts around `45`
- Bottom tab bar: `49`, anchored to bottom
- Main horizontal page margin: `20`
- Primary content width: `335`

Recommended layout rules:

- Use a `20px` left/right safe margin for most content.
- Use `335px` full-width modules inside a `375px` mobile frame.
- Use two-column discovery cards with `162px` width each and `11px` column gap.
- Bottom navigation remains fixed across main app pages.
- Keep most modules visually unframed. The UI relies on image blocks, dividers, tabs, and whitespace rather than heavy cards.

## 3. Brand And Color Tokens

Core palette:

| Token | Hex | Use |
| --- | --- | --- |
| `brand.primary` | `#FF2442` | Selected tab underline, create action, sign-in CTA, notification emphasis |
| `text.primary` | `#111111` | Section titles, active tabs, important labels |
| `text.body` | `#111111` | Body copy and progress text |
| `text.secondary` | `#666666` | Subtitles, summaries, inactive description text |
| `text.tertiary` | `#999999` | Metadata, timestamps, inactive nav labels |
| `text.placeholder` | `#B0B0B0` | Search placeholder |
| `surface.page` | `#FFFFFF` | Page background |
| `surface.subtle` | `#FAFAFA` | Search field background |
| `border.subtle` | `#EBEBEB` | Search border and dividers |
| `link.world` | `#4B6192` | World titles and blue tags |
| `tag.blue.bg` | `#ECEDF5` | Blue tag background |
| `tag.green.bg` | `#ECF5ED` | Green tag background |
| `tag.green.text` | `#338960` | Green tag text |

Usage guidance:

- Red is the primary action and selection color. Do not overuse it in large surfaces.
- Blue `#4B6192` is used for world/entity titles and semantic links.
- Gray hierarchy is important: `#111` for labels, `#111` for paragraphs, `#666` for supporting descriptions, `#999` for metadata.
- Image-heavy areas may use white text over a dark gradient/overlay for metrics.

## 4. Typography

Primary UI font:

- `Inter` for app UI, lists, tabs, labels, cards, body copy.
- `SF Pro Text Semibold` appears in iOS status bar only.

Type scale:

| Style | Size | Weight | Line Height | Use |
| --- | ---: | --- | ---: | --- |
| Nav/title | `16` | Semibold | `22` | Center title, sign-in title |
| Profile tab | `16` | Bold/Medium | normal | Origin/World tabs on Me |
| World title | `14` | Bold | normal | `#Four Kinight`, `#Alpha Empire` |
| Tab label | `14` or `12` | Bold active, Medium inactive | normal | Home and Origin category tabs |
| Body | `12` | Medium | `18` | Progress text, story summaries, descriptions |
| Metadata | `10` or `12` | Medium | normal or `18` | WID/OID, timestamps, stats |
| Bottom nav | `10` | Medium | normal | Home, Origin, Create, Messages, Me |
| Search placeholder | `10` or `12` | Regular | normal | Search fields |

Rules:

- Active tab text uses Bold and `#333`.
- Inactive tab text uses Medium and `#999`.
- Story/body copy should use `12px / 18px`; avoid increasing body size unless the page is long-form reading.
- Keep letter spacing at `0`, except iOS title/status styles already observed in Figma.

## 5. Spacing And Geometry

Common spacing:

- Page margin: `20`
- Header title height: `44`
- Search field height: `28` on Home, `36` on Origin/detail
- Search border radius: `12`
- Active tab underline: `30 x 4`, radius `8`
- Detail Map underline: `42 x 2`, radius `8`
- Bottom nav icon: `24 x 24`
- Create nav icon: `28 x 28`
- Profile avatar: `106 x 106`
- List avatar: `60 x 60`
- Comment avatar: `30 x 30`
- Message shortcut icon: `40 x 40`
- Small inline icons: `10 x 10`, `12 x 12`, `14 x 14`

Radius:

- Search fields: `12`
- Primary pill button: `18`
- Tags: `4`
- Active underline: `8`
- Image masks are softly rounded, usually using masked rectangular image blocks.

## 6. Navigation System

Bottom navigation is persistent:

1. Home
2. Origin
3. Create
4. Messages
5. Me

Specs:

- Height: `49`
- Background: white
- Icon size: `24`, except Create `28`
- Label size: `10`, Medium
- Active label: black
- Inactive label: `#999`
- Create is visually emphasized by a red circular/plus icon but label remains neutral unless active.

Design rule:

- Every main page should reserve bottom space for the nav.
- Do not add a second floating bottom CTA on main tab pages unless it clearly belongs above the nav.

## 7. Header Patterns

### Logo + Search Header

Used on Home:

- Logo at left, around `97 x 28`
- Search field at right: `224 x 28`, x around `131`
- Placeholder: `Search worlds，stories，people...`
- Search icon: `14`

### Center Title Header

Used on Origin and Messages:

- Header area from y `45` to `89`
- Title centered
- Font: `16` Semibold
- Background: white

### Detail Map Selector

Used on Origin detail:

- Search-like pill: `335 x 36`, x `20`, y `48`
- Contains back arrow on left
- Center segmented control: `Map` active and `Points(8)` inactive
- Active Map text and icon use `#F42C47`
- Active underline: `42 x 2`

## 8. Tabs

Tabs are text-first with a small red underline.

Home tabs:

- `My Worlds`, `Popular`, `Friends`
- Size `14`
- Active underline `30 x 4`

Origin category tabs:

- `For You`, `Billionaire`, `Destroyed`, `End World`, `Vampire`
- Size `12`
- Horizontal, no pill container

Me tabs:

- `Origin`, `World`
- Size `16`
- Divider line beneath tab row

Rules:

- Active tab uses Bold + `#333`.
- Inactive tabs use Medium + `#999`.
- Underline aligns visually under the label center, not full label width.

## 9. Search Fields

Home compact search:

- Size: `224 x 28`
- Radius: `12`
- Background: `#FAFAFA`
- Border: `#EBEBEB`
- Placeholder: `10px #B0B0B0`

Origin full search:

- Size: `335 x 36`
- Radius: `12`
- Background: `#FAFAFA`
- Border: `#EBEBEB`
- Placeholder: `12px #B0B0B0`

Rules:

- Search fields are quiet utility controls, not hero elements.
- Keep icon at `14px`, left padding around `10px`.

## 10. World List Item Pattern

Used on Home list views.

Structure:

- Avatar/image: `60 x 60`, left aligned at x `20`
- Title: `14px Bold #4B6192`
- Metadata row: `12px Medium #999`, e.g. `WID`, `Owner`
- Stats row: `10px Medium #444`, with small icons
- Content block below: progress label, timestamp, description, then one or two image thumbnails
- Divider between world items: `335px` width

Progress section:

- Icon: `14`
- Label: `12px Bold #333`
- Timestamp: `12px Medium #999`
- Body: `12px Medium #444`, line height `18`
- Image thumbnails: two columns, each around `162 x 120`

Rules:

- World titles should always start with `#`.
- Use `WID` for world id and `OID` for origin id.
- Use concise metadata and avoid dense paragraphs above the fold.

## 11. Discovery Card Pattern

Used on Origin page.

Card structure:

- Two-column layout
- Card width: `162`
- Cover image: `162 x 188`
- Bottom overlay on image: `162 x 40`
- Overlay stats use white `10px Medium`
- Title: `14px Bold #4B6192`
- Description: `12px Medium #666`
- Tags: `20px` height, radius `4`, horizontal padding about `4`

Tag variants:

- Blue tags: bg `#ECEDF5`, text `#4B6192`
- Green tags: bg `#ECF5ED`, text `#3D9856`

Rules:

- Keep cover art dominant.
- Text under covers should be concise and may wrap to 2 to 3 lines.
- Use tags sparingly. Two to three tags per card is enough.

## 12. Origin Detail Page Pattern

Detail pages combine map exploration with a bottom sheet.

Map region:

- Full-width illustrated map background.
- Map area height: about `412px` before sheet begins.
- Top selector sits over map at y `48`.
- Zoom controls: `28 x 28`, bottom-right above the sheet.

Bottom sheet:

- Starts around y `412`
- Height in current comp: `550`
- White rounded/curved top surface with grab handle `32 x 3.5`
- Horizontal margin inside sheet: `20`
- Main content width: `335`

Detail header:

- Title: `16px Bold #4B6192`
- Metadata: `10px Medium #999`
- Metadata separators: vertical hairlines
- Copy and chevron icons: `12` or smaller

Detail content sections:

- Section icon: `14`
- Section label: `12px Bold #333`
- Body: `12px Medium #444`, line height `18`
- Media preview: `335 x 120`, play icon `36`
- Progress metadata row: `10px #999`

Rules:

- Use the bottom sheet for dense detail rather than navigating to a separate plain article page.
- Keep map imagery visible above the sheet to preserve the world-exploration feeling.

## 13. Messages Page Pattern

Top shortcut row:

- Three equally spaced shortcuts:
  - Notifications
  - New followers
  - Comments
- Icon: `40 x 40`
- Label: `14px Medium #333`
- Row starts around y `99`

Direct messages list:

- Section title: `16px Bold #333`
- Divider above list: `335px`
- Message row height: about `80`
- Avatar: `60 x 60`
- Sender name: `14px Bold #333`
- Preview: `12px Medium #666`, line height `18`
- Timestamp: `12px Medium #999`
- Unread dot: `8px`, brand red

Rules:

- Keep notifications and social interactions separate from direct messages.
- Use red dots only for unread/new states.

## 14. Me And Empty States

Me page account area:

- Settings icon: top-right, `24`
- Profile avatar: `106 x 106`, x `20`, y around `108`
- Sign-in title/link: black, Semibold
- Supporting copy: `14px Medium #666`
- Primary sign-in button:
  - Size: `146 x 32`
  - Radius: `18`
  - Background: `#F42C47`
  - Text: `14px Medium #FFFFFF`

Empty state:

- Illustration: about `200 x 181`
- Empty text: `14px Medium #999`
- Copy observed: `Sign in to see your Origins and Worlds.`

Rules:

- Empty states should be soft and centered, not framed in cards.
- When signed out, keep the page useful but clearly locked.

## 15. Imagery And Icons

Imagery:

- Covers should be vivid, story-rich, and genre-specific.
- Current examples lean fantasy, romance, werewolf/vampire, empire/drama.
- Use imagery to define the world mood before text does.

Icons:

- Navigation icons are simple line/filled glyphs.
- Section icons are small, mostly `14px`.
- Stats icons are `10px`.
- Use icon + number pairs for plays, links/heat, followers, and participants.

Rules:

- Avoid generic stock-like art for world covers.
- Keep image masks consistent and crop art deliberately.
- Icons should not introduce new colors unless they represent status or category.

## 16. Content And Naming Rules

Brand:

- Always refer to the product/logo as `worldo`.

Entity naming:

- World or Origin title format: `#Title Case Name`
- Use `WID` for world identifiers.
- Use `OID` for origin identifiers.
- Use `Owner` for world owner.
- Use `Originator` for origin creator. The Figma currently has a typo `Origginator`; future UI should correct it to `Originator`.

Copy style:

- Short UI labels use sentence case or title case depending on category.
- Progress copy can be narrative and longer, but should be truncated in list views.
- Placeholder: `Search worlds，stories，people...`; consider normalizing punctuation to `Search worlds, stories, people...` in future implementation.

Observed typos to fix in future pages:

- `#Four Kinight` should likely be `#Four Knight`
- `Origginator` should be `Originator`
- `wrld` should be `world`
- `Werewolf ad Vampire` should likely be `Werewolf and Vampire`
- `Vammpire` should be `Vampire`

## 17. Recommended Component Inventory

Create these reusable components for future pages:

- `AppStatusBar`
- `TopLogoSearchHeader`
- `CenteredTitleHeader`
- `BottomTabBar`
- `TextTabGroup`
- `SearchField`
- `WorldListItem`
- `ProgressBlock`
- `DiscoveryWorldCard`
- `Tag`
- `MetricPill` or `MetricInline`
- `MapSelector`
- `MapControlButton`
- `OriginDetailSheet`
- `SectionHeader`
- `MediaPreview`
- `MessageShortcut`
- `MessageListItem`
- `ProfileSignInBlock`
- `EmptyState`

## 18. Future Page Design Checklist

Before designing a new worldo page:

- Use `375px` mobile canvas first.
- Preserve `20px` page margin and `335px` content width.
- Keep bottom tab bar fixed on main app pages.
- Use `#F42C47` only for selected states, CTAs, unread/new states, and Create emphasis.
- Use `#4B6192` for world titles and world/entity links.
- Keep body copy at `12px / 18px`.
- Prefer image-led modules over card-heavy layouts.
- Use dividers and whitespace instead of nested containers.
- Reuse tabs, search field, stats row, and section header patterns before inventing new controls.
- Make empty states illustration-led and quiet.
- Confirm brand spelling as `worldo`.

