# History UI implementation plan

Goal: apply the user's four History changes on d3eabb35 and preview on the phone.
Architecture: History-only projection filters and controls; shared live chat stays unchanged.
Tech stack: Flutter, existing WorldHistoryController, projection and anchored chat viewport.

- [x] Keep lightweight per-page Tick/user-location summaries across page eviction. Each Tick belongs to locations with user messages after it and before the next Tick, as confirmed by the user. Preserve server order and never invent location associations.
- [x] Remove Character movements from History Tick projection only.
- [x] Add a bottom-centered double-down action matching the Chatroom new-message surface; hide at bottom, preserve folds, return to newest cached page if evicted, then use the shared scroll coordinator.
- [x] Investigate true Tick numbering. Current History contract explicitly omits tick_no/subtick_no; never infer numeric labels from page position. Document any backend dependency.
- [x] Format/analyze modified Dart files. Before publishing, user requested verification: 33 Posts/feed/store/preview tests and 2 existing avatar-navigation tests passed.
- [x] Build and install the first full History internal Debug APK (2026-10-20 00:19); subsequent MiniPhone refinements previewed with persistent Flutter attach.
- [x] Build/install the combined History + MiniPhone internal Debug version after removing the declined role-directory fallback. Installed with existing data retained on 2026-10-20.
- [ ] Publish a new team branch, as explicitly requested on 2026-10-20. Existing branches must remain unchanged. Target: feature/history-miniphone-ui-20261020.

Known limits: the earlier History red-screen assertion remains unresolved; true Tick labels depend on server-provided numbers. No full automated regression was requested for this publishing step. See the checkpoint for the MiniPhone changes, targeted static checks and actual build/install results.
