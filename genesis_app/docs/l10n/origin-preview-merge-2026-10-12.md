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
