# Search Page UI Spec

## Scope
- Page: `SearchPage`
- File: `lib/pages/search/search_page.dart`
- Search bar component reuse: `lib/components/search_bar.dart` (`SearchBarPlaceholder`)

## Color And Frame Consistency
- Search page scaffold background: `#FFFFFF`
- Search bar background: reuse component default `#F2F2F2`
- Search bar radius: reuse component default `10`
- Do not redefine per-page search bar frame/background unless all pages are updated together.

## Typography
- Search input text: `14`
- Search input placeholder: `14`
- Cancel button text: `18`
- Tabs (`All / Origin / World / User`): `14`
- Result section title (`Origin / World / User`): `12`
- Result item title: `14`
- Result item subtitle: `12`
- Empty hint (`No search history yet...`): `14`
- Empty result (`No results.`): `14`

## Empty-State Layout
- For query length `< 2`, show:
  - `No search history yet.`
  - `Type at least 2 characters to search.`
- This hint is bottom-aligned and sits above keyboard/safe inset.
