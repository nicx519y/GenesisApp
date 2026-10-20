# MiniPhone Collect 埋点表

更新日期：2026-10-20。此表描述客户端实现；不代表真实 Collect 服务端入库或 Android/iOS 真机已验收。

## 采集方式与范围

所有事件调用 `GenesisTelemetry.collectLog`，复用现有 SQLite 队列和批量上传器。默认端点为 `https://collect.worldo.ai/api/v1/collect`，受公共配置和上传策略控制。默认每 5 秒尝试上传，每批最多 100 条且不超过 256 KiB；未确认成功的事件按原 `event_id` 重试。

本次共 13 个事件名，覆盖核心访问和操作。不采集曝光、停留、刷新、分页、滚动、后台恢复或 AI 回复终态。预览不采集；自动音乐行为不计为用户操作。`collectLogAndWait` 的返回值只表示入队结果，不表示服务端入库。

## 公共字段

### 自动携带

| 字段 | 位置 | 含义 |
| --- | --- | --- |
| `X-UID` | 请求头 | 事件入队时的用户 UID，空值不传 |
| `X-Device-ID` | 请求头 | 事件入队时的设备 ID，空值不传 |
| `X-Platform` | 请求头 | 平台，例如 android / ios |
| `X-App-Version` | 请求头 | App 版本；早期未知版本可由公共上传器补齐 |
| `x-app-environment` | 请求头 | production / test |
| `event_id` | 每条事件 | 唯一 ID，上传重试保持不变 |
| `app_timestamp` | 每条事件 | 入队时的本地 Unix 毫秒时间戳 |

公共上传器按身份和环境快照分批。账号切换不会将队列内旧事件改为新 UID。

### MiniPhone 主动填写

| 字段 | 类型 | 规则 |
| --- | --- | --- |
| `action_type` | string | 页面为 pageview，其他为 event |
| `action` | string | 下表中的固定事件名 |
| `object1` | string | 真实 world_id；无正式世界/数据会话不生成业务事件 |
| `object2` | string | 下表定义的业务目标；无值为空字符串 |
| `object3` | string | 下表定义的阶段或操作；无值为空字符串 |
| `object4` | string | 提交类的 attempt_id；其他为空字符串 |
| `ext_data` | string | JSON 编码的扩展对象；Photos 张次为空字符串 |

所有业务 ID 按完整十进制字符串上报，不转浮点数。布尔值为 JSON boolean，Token 数为 JSON integer。不采集正文、图片 URL、本地路径、原始错误文本或请求/响应正文。

## 事件清单

以下 `object1` 一律为真实 `world_id`。扩展字段中的 `open_id`、`source` 规则见后文。

| action | action_type | 触发时机 | object2 | object3 | object4 | ext_data 关键字段 |
| --- | --- | --- | --- | --- | --- | --- |
| `mini_phone_open` | event | 手机路由首次实际展示；每次打开一次，直达私聊也记录 | 实际首屏 | open | 空 | open_id、source、is_restored |
| `mini_phone_page` | pageview | 页面首次可见、切换或返回后重新可见；聊天角色/评论帖子切换也记录 | 页面枚举 | view | 空 | open_id、source、from_page、navigation_type；chat 带 char_id，comments 带 post_id |
| `mini_phone_dm_send` | event | 有效发送提交及该次 HTTP 返回结果 | char_id | 提交阶段 | attempt_id | open_id、source=chat、client_request_id、is_retry、dm_session_id、peer_type；失败时错误字段 |
| `mini_phone_post_publish` | event | 有效点击 Post，在图片上传前记录 submit；上传/提交返回时记录结果 | new | 提交阶段 | attempt_id | open_id、source=create、has_image、is_retry、client_request_id（已分配时）；失败时错误字段 |
| `mini_phone_comment_send` | event | 有效提交评论或回复，以及该次 HTTP 结果 | post_id | 提交阶段 | attempt_id | open_id、source=comments、client_request_id、is_retry、reply_to_comment_id（回复时）；失败时错误字段 |
| `mini_phone_post_like` | event | 用户有效点击点赞或取消点赞 | post_id | like / unlike | 空 | open_id、source=posts/comments |
| `mini_phone_post_filter` | event | 作者筛选实际改变；重复点击选中作者取消筛选也记录 | char_id / all | select | 空 | open_id、source=posts |
| `mini_phone_photo_view` | event | Photos 大图首张成为当前页，以及后续切换到其他当前页 | 空 | 空 | 空 | 空字符串 |
| `mini_phone_music_control` | event | 用户有效点击播放/暂停/上一首/下一首 | 操作发起时曲目 file | play / pause / previous / next | 空 | open_id（存在时）、source=music/home/dock |
| `mini_phone_music_like` | event | 用户有效点击音乐点赞或取消点赞 | 曲目 file | like / unlike | 空 | open_id、source=music |
| `mini_phone_wallpaper_save` | event | 有效提交保存及保存结果 | wallpaper | 壁纸阶段 | attempt_id | open_id、source=settings、wallpaper_type=preset/custom；失败时错误字段 |
| `mini_phone_model_change` | event | 模型实际写入本地会话且值改变 | model | changed | 空 | open_id、source=models、previous_model、model_code、scope=local_session |
| `mini_phone_memory_change` | event | Token 设置实际写入本地会话且值改变 | memory_tokens | changed | 空 | open_id、source=models、previous_tokens、memory_tokens、scope=local_session |

### 扩展参数字典

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| open_id | string | 每次手机实际打开生成的 UUID；本次访问共用；关闭后的 Dock 操作省略 |
| source | string | 固定来源枚举，不能传展示文案 |
| is_restored | boolean | 本次是否按已有会话恢复页面；显式初始页/直达角色为 false |
| from_page | string | 前一个页面枚举；首次进入为空 |
| navigation_type | string | initial / push / back / replace |
| char_id | string | 页面访问目标角色 ID |
| post_id | string | 页面访问目标帖子 ID |
| client_request_id | string | 现有业务写请求 ID；同一业务请求重试保留；新发帖上传前尚未分配时省略 |
| is_retry | boolean | 是否复用现有业务请求 |
| dm_session_id | string | 当前已知私聊会话 ID；虚拟会话为 "0" |
| peer_type | string | ai / player，沿用业务会话判定 |
| has_image | boolean | 是否包含配图；不传图片地址 |
| reply_to_comment_id | string | 真实被回复评论 ID；普通评论省略 |
| wallpaper_type | string | preset / custom；自选图片为 custom |
| previous_model / model_code | string | 原模型代码 / 新模型代码 |
| previous_tokens / memory_tokens | integer | 原 Token 值 / 新 Token 值 |
| scope | string | 模型及 Token 固定为 local_session，不代表后端设置或计费生效 |
| error_stage | string | journal / upload / prepare / validation / request |
| error_kind | string | ApiException.kind.name；非 ApiException 为 local |
| error_code | string | 有业务错误码时携带；无值省略 |

页面枚举：`home / messages / chat / posts / comments / create / photos / music / settings / models`。

外部入口：`world_dock / location_chat_dock / location_chat_avatar / location_chat_roster`。正式调用方必须传入；公开入口为兼容现有调用保留 `unknown` 默认值。

导航来源：`home_icon / home_notification / home_music_card / messages_list / posts_feed / header / back / restore`。初次页面使用外部入口来源，恢复上次页面通过 `is_restored` 区分；用户返回为 back，账号上下文重建可使用 restore。

## 提交与去重口径

| 阶段 | 含义 |
| --- | --- |
| submit | 校验和防重复检查通过；开始一次用户提交，发帖早于图片上传 |
| accepted | 私聊/发帖/评论 HTTP 成功返回且 err_no=0；不代表 AI 完成回复 |
| rejected | 目标业务接口明确拒绝 |
| uncertain | 目标请求调用后超时、断网、无有效响应等，无法确认结果 |
| local_failed | 目标接口调用前失败，例如日志保存或图片上传失败 |
| saved | 仅壁纸使用；保存接口成功返回 |

- 每次有效尝试生成新的 attempt_id；同一次 submit 和结果保持一致。每次尝试最多一个 submit、一个结果。
- 手动重试使用新 attempt_id 和原业务 client_request_id。只统计当前尝试及返回结果，后台恢复、Socket 推送、历史读取不补发终态。
- 以 HTTP 结果定义受理；推送先到但 HTTP 超时，仍统计该次 HTTP 尝试 uncertain，不推断业务最终失败。
- 写成功后的详情/通知刷新失败不改变 accepted；图片上传失败为 local_failed，不能算发帖接口拒绝。
- 提交上下文在开始时保存；关闭手机后仍在运行的请求保留原 open_id。账号/世界失效后不将旧结果归到新用户。
- 进程退出或上下文失效可能只有 submit；结果缺失不计为失败。
- 点赞、音乐控制统计用户意图，不代表服务端成功或实际播放成功。
- 页面预取、组件重建、后台同步不增加 PV。直达私聊不虚增 Home/Messages。
- 手机模型页关闭旧 switch_model_page / switch_model_save，仅上报本表事件；其他模型页面的原 collect 行为不变。

## Photos 大图浏览张次

仅 Photos 入口接入共享查看器的 `onImageViewed(int index)`，帖子/评论查看器不接入。首帧展示当前页上报一次，当前索引变化再上报；同索引重复通知不计。

- 打开 A，滑到 B，再滑回 A：3 张次。
- 关闭后重新打开 A：再加 1 张次。
- 缩放、同图拖动、重建、相邻图片预加载：0 张次。
- 按进入大图页面计，不等原图下载成功；不能将该指标解释为图片加载成功数。
- 每条事件代表 1 张次，不按用户或图片去重，不携带 asset_id/post_id/open_id/图片 URL。

```json
{
  "action_type": "event",
  "action": "mini_phone_photo_view",
  "object1": "<world_id>",
  "object2": "",
  "object3": "",
  "object4": "",
  "ext_data": ""
}
```

## 分析与验收

可分析手机打开 UV/PV、入口贡献、应用使用率、访问到发送/发帖/评论的转化、HTTP 受理率、Photos 浏览张次、音乐操作及设置偏好。发送尝试受理率按 attempt_id 配对，业务请求去重统计按 client_request_id；缺失结果单列，不当作 rejected。重试成功不把早先 uncertain 改写为成功。

定向测试覆盖公共字段、最小 Photos payload、张次、导航去重、发送受理/拒绝/超时、重试、上传失败、账号切换与关闭后结果。共享图片查看器、音乐、壁纸、模型和 MiniPhone 原有行为运行相关回归。

真实测试环境 Collect 入库及 Android/iOS 真机验收需分别取证；本地测试不代替这些验收。

### 本次验证记录（2026-10-20）

- 102 项定向测试通过：MiniPhone Collect、页面导航、Photos 查看器、音乐服务/页面、壁纸控制器、发帖草稿、存储失败回归，以及共享大图查看器/动画。
- 模型专项 2 项通过：MiniPhone 本地模型/Token 变更不产生旧 pay_event；其他模型页面仍保留原埋点。合计 104 项定向测试通过。
- 修改涉及的生产代码和测试静态检查通过；`git diff --check` 通过。
- 扩展检查另有 5 个既有失败，已在临时副本使用本次修改前的相关调用链复现，未在此次埋点任务中修改其业务或断言：

| 测试文件 | 失败用例 | 复核结果 |
| --- | --- | --- |
| test/pages/gems/memory_model_page_test.dart | ranges show one decimal gems and whole K memory | 找不到预期的 Estimated next message 文本，基线同样失败 |
| test/pages/gems/memory_model_page_test.dart | save publishes price and memory together after both reads finish | 找不到预期的 Estimated next message 文本，基线同样失败 |
| test/pages/gems/memory_model_page_test.dart | shows cached settings while refreshing every page entry | 找不到预期的 Estimated next message 文本，基线同样失败 |
| test/pages/mini_phone/mini_phone_module_boundary_test.dart | external page integrations use only the public entry | 检查将已有 network/mini_phone 模型导入也算入页面入口导入，基线同样失败 |
| test/pages/mini_phone/mini_phone_music_like_page_test.dart | player fetches server status, updates before POST completes, rolls back, and displays err_msg | 初始点赞选中状态断言失败，基线同样失败 |

未执行真实 Collect 入库、Android/iOS 真机或发布验收；未提交或推送 Git。

可复跑的通过组：

```sh
flutter test --no-pub \
  test/pages/mini_phone/mini_phone_collect_test.dart \
  test/pages/mini_phone/mini_phone_page_navigation_test.dart \
  test/pages/mini_phone/mini_phone_photos_viewer_test.dart \
  test/pages/mini_phone/mini_phone_music_service_test.dart \
  test/pages/mini_phone/mini_phone_music_page_test.dart \
  test/pages/mini_phone/mini_phone_wallpaper_controller_test.dart \
  test/pages/mini_phone/mini_phone_post_draft_test.dart \
  test/pages/mini_phone/mini_phone_crash_regression_test.dart \
  test/components/genesis_image_viewer_overlay_test.dart \
  test/components/genesis_image_viewer_transition_test.dart
flutter test --no-pub test/pages/gems/memory_model_page_test.dart \
  --name 'MiniPhone logs local|reports model page'
```
