# 全局记忆与 Deluxe · 第一版页面

基线：2026-11-03 拉取的 `origin/main`，`8d0062581117513aeefe9dc507759e4347a4cd18`。
独立本地分支：`feature/global-memory-deluxe-20261103`。
设计依据：`C:/Project/worldo/界面设计/全局记忆`。订阅采用用户确认的 `Subscribe` 左右滑动双卡方案。

## 页面与交互

- World 底部新增 Cast、Bonds，顺序为 Detail / Recap / Cast / Bonds / History / Events / Locations。
- Recap 内切换 Timeline 与 Summary；时间轴展示事件、参与者和更新标签，最多显示最新 10 条。Summary 展示完整摘要。
- Cast 展示角色动态、分组档案及退场状态；World 中单人展开，小手机中进入详情。
- Bonds 分为角色对你的看法和角色之间的关系。
- 小手机第二屏增加 Recap、Cast、Bonds，沿用现有应用打开、返回和关闭路径。
- Me 会员区与 Subscription 增加 Premium / Deluxe 双卡，支持左右滑动及各自的会员状态、月付/年付选择。
- 新增独立 Developer → Global memory preview，可切换无会员、Premium、Deluxe、双会员，以及故事进行中、新故事、角色退场状态；Membership cards 可查看订阅和 Me 会员展示。
- 新增文案完成 8 种目标语言的增量翻译，译文为 AI 状态，未宣称人工母语审校。

## 数据和购买边界

- Premium 与 Deluxe 是独立权限；Deluxe 不自动包含 Premium Summary。
- 正常页面的 Premium 状态、商品价格和购买继续使用现有服务。月付/年付选择会传给原购买页面；订单与商店处理没有重写。
- Summary 复用现有 recent-summary API，显示最新一份完整摘要；保留进入刷新和更新通知，缓存按账号/会话隔离。
- 结构化 Timeline / Cast / Bonds 和 Deluxe 尚未接正式数据/商品接口；正常页面显示锁定结构，Deluxe 操作提示尚未开放。
- 设计中的 Deluxe 价格、宝石额度及示例角色/关系仅在独立预览中展示，不写入线上 World、History、账号权益或订单。
- 旧相机分支和其他工作区保留；本轮未合并此前不在 main 中的相机改动。

## 交付范围

本轮只在本地开发与打包，不安装手机、不提交、不推送。构建及验证的最终结果见同目录 `checkpoint.md` 和 APK 归档中的 `BUILD.md`。
