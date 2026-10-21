# Wallet 每日任务刷新倒计时

Buy Gems 页在 `group_code=daily` 的 Daily 标题下显示每日任务统一刷新倒计时，文案为 `Resets in {time}` / `距離重置還有 {time}`，时间格式 `HH:mm:ss`。标题间距 4；倒计时与任务条目说明正文一致：字号 12、行高 14/12、字重 w400、三级文字色 `darkTextTertiary`；任务卡片前间距仍为 10。

数据来自 GET `/api/v1/gem/tasks` 的 `list[]` 分组对象 `next_claim_countdown_seconds`，仅读取 `group_code=daily` 分组，不再从任务对象读取或汇总。接口规定 Daily 分组必返 1–86400 的整数，与签到领取状态无关；其他分组省略。字段缺失、非整数或越界时不展示，刷新瞬间服务端返回 86400。最新 Apifox 将此值定义为签到刷新（UTC−4 零点）的剩余秒数，其他每日任务仍按 UTC 日；界面继续按已确认要求显示在 Daily 下方，不据此修改任务状态。

接口成功返回时建立单调计时基准。页面停留时每秒更新该行，不每秒请求接口，也不推算客户端时区或午夜。切后台暂停 UI 定时器，回前台按已过去时间校正，并沿用钱包页面的接口刷新重新同步。

归零显示 00:00:00，静默刷新任务；请求失败时不循环重试。收到新的正数后允许下一轮归零刷新。领取资格仍以服务端任务状态为准。

新增 `gemsDailyResetsIn`，同步 zh-TW、es、pt、fr、de、it、ja、ko；飞书目标表 https://my.feishu.cn/wiki/UuK0whQptiTiCRkyNy5cQDQln2N?sheet=cd7861 。本次浏览器未开启远程调试，云端同步尚未完成。
