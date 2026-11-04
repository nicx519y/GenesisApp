# Camera concurrent preview

Approved: user requested camera branch, concurrent frontend simulated generation,
camera remains usable, task progress/results in Photos, hot restart on phone.

Base f33f1148; feature/camera-multishot-preview-20261103; preserve previous branch.

- [x] Add isolated session-owned preview job store, immutable capture snapshots,
  independent timers, rapid-tap debounce, retry and unread results. Test parallel
  jobs, draft edits, account/world invalidation, disposal and retry.
- [x] Wire camera confirmation to enqueue, retain composition and show progress
  count/latest result on Photos entry; keep existing adapter contract unchanged.
- [x] Add separate labelled preview grid above real Photos; task remains in place
  on completion; open sample result via existing viewer; failed tile retries.
- [x] Translate preview notice/start/count through existing 8-language pipeline.
- [x] Run scoped tests/analyze and hot restart existing Internal Debug session.

Simulation: local template sample assets only, no transport, billing, History or
server album changes. Jobs owned by World session, persist through Camera/phone
close but clear when World session is disposed, account/environment changes or
app restarts. Every third initial task simulates failure; retry succeeds. Timing
is independent per job. Submit stores selected people, prompt and style asset.
Notice explicitly distinguishes sample results from actual generated images.

## 最终交付说明（2026-11-04）

最终界面不提供失败重试；失败卡片只保留说明并在重入相册时清理。比例已扩展为5项、落定后提交且高亮跟手。相册贴文入口复用原发布页的隔离预览草稿。最终范围以docs/changes/2026-11-03-camera-multishot-preview.md为准。
