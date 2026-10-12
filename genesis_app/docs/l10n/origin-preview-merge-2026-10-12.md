# Origin preview UI merge and localization

Merged `origin/feature/origin-preview-ui-20261011` (65d734ee) into `feature/translate` from 76d4f16c.

Conflict resolutions retain language-aware Origin data refresh, localized labels, and the incoming preview/role/keyboard layout and membership debug override. Destination cards use complete localized sentences with styled placeholders; dynamic character/location values are unchanged. The rich-text placeholder map includes only values present in the selected template.

English catalog: 13 new keys and one changed key (`developerRecapOff`). Eight target language catalogs were updated through the incremental translation workflow. Recap Off now follows current membership, including the developer override, rather than claiming to always use real membership.

Feishu translation sheet: row 845 updated; rows 850–862 contain the 13 new keys; row 863 additionally supplies the previously missing `chatEditFreeUsesExhausted` record. Every key has its own row. Cloud-save status and a fresh XLSX export were checked; all 135 English/target-language cells for these 15 rows match the ARBs. Newline characters use the sheet's literal `\n` representation. Translations are AI generated and await native-speaker review.

https://my.feishu.cn/wiki/UuK0whQptiTiCRkyNy5cQDQln2N?sheet=cd7861

Validation:

- Localization check: 855 keys per catalog; 42 tests passed.
- Membership and incoming Origin layout regression selection: 16 tests passed.
- New rich-text card regression: 10 generated supported-locale variants passed, covering singular/plural occupants, empty opening, and movement templates.
- Launch error/retry test passed; expected Toast updated to the server-provided `Launch rejected`, preserving existing translated-branch error handling.
- Related broad Origin/opening selection exposes 12 failures on the source branch itself, including obsolete role/layout expectations, handoff send assertions, disposed notification state, and an opening-scroll boundary. These remain known limitations; this merge is not a claim that the full widget suite passes.
- No physical-device, backend, or store verification was performed.

## Follow-up: location preview consistency

The merge review reproduced a newly introduced compatibility regression: a second destination with legacy tick opening dialogue was rendered using the first destination's dialogue lookup and appeared blank. Each location preview now converts its own supplied opening messages with the same converter as the Opening Sheet.

The review also reproduced an older refresh defect: Origin detail changed while the open location descriptor retained the old title, background, opening messages, and entities. Successful detail refresh now replaces the descriptor from the fresh Origin data while retaining the location widget identity, composer controller, and unsent draft. If the destination no longer exists, its obsolete preview closes.

Permanent regression tests cover a second destination, refreshed title/background/characters/dialogue, retained composer/draft, and empty-to-populated opening transition. The movement-card and Tick-inset expectations were updated to the incoming card layout, preserving the existing story-event assertions.

Follow-up validation: 5 targeted fix/layout assertions, 4 Origin keyboard/role/launch-retry tests, 50 membership/language-refresh/rich-text tests, and 52 localization checks passed. Static analysis of the changed code and tests reported no issues. Existing unrelated broad-suite failures and the synchronous-send test hang are not resolved by this patch. No user-facing copy or ARB keys changed; the synchronized Feishu translation rows remain applicable. Device validation is still pending.

Background fallback follow-up: refresh now matches map-point entry behavior, preferring a non-empty location image and otherwise using the location map image. The regression test failed before the fix and passed afterward. Four scoped preview tests (including image priority, map fallback, opening refresh and retained draft) and static analysis passed. No localization copy changed.
