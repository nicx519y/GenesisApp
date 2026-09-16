# 用户端提交按钮与 Loading

提交中保持原底色，禁止重复提交。已有圆环保留；没有圆环的不新增。普通校验禁用仍用禁用色。保持现有圆环、文字、布局和业务反馈，不改变接口及完成/失败流程。

## 按钮清单

| 页面 / 场景 | 按钮 | 提交中反馈 | 提交中底色 | 实现 |
| --- | --- | --- | --- | --- |
| World 顶部操作 | 加入 / 申请 / Launch 等当前主操作 | 原有 18px 圆环 | 原品牌红 | `world_header.dart` → `GenesisPrimaryButton` |
| 角色选择 Sheet | Launch | 原有 18px 圆环 | 原品牌红 | `origin_role_launch_sheet.dart` → `GenesisPrimaryButton` |
| Location Chat 编辑页 | Save | 原有 18px 圆环 | 原品牌红 | `location_chat_edit_page.dart` → `GenesisPrimaryButton` |
| 强制升级 | Update now | 原有 18px 圆环 | 原品牌红 | `force_upgrade_gate.dart` → `GenesisPrimaryButton` |
| Worldo 基础信息 | Save | `Saving...`，不加圆环 | 原品牌红 | `origin_basics_editor_page.dart` |
| Worldo 角色 | Save | `Saving...`，不加圆环 | 原品牌红 | `origin_characters_editor_page.dart` |
| Worldo 地点 | Save | `Saving...`，不加圆环 | 原品牌红 | `origin_locations_editor_page.dart` |
| Worldo Opening | Save | `Saving...`，不加圆环 | 原品牌红 | `origin_opening_editor_page.dart` |
| Worldo Story Events | Save | `Saving...`，不加圆环 | 原品牌红 | `origin_story_events_editor_page.dart` |
| Worldo 创建 / 发布 | Create / Publish | `Creating...` / `Publishing...` / `Checking...`，不加圆环 | 原品牌红 | `origin_editor_pages.dart` |
| 新用户表单 | Continue | 标准 18px 圆环，线宽 2，提交中隐藏文字 | 原品牌红 | `personalization_sheet.dart` |
| Gems 完整页 / Sheet | 充值卡片购买 | 原有 13px 圆环 | 原品牌红 | `gem_purchase_catalog.dart` |
| 会员完整页 / 独立 Sheet / 新用户订阅 | 套餐购买 | 独立购买进度弹窗，按钮不加圆环 | 原金色渐变 | `pro_subscription_content.dart` |
| 黑名单 | Block / Unblock | 原有 15px 圆环 | 原灰底 / 品牌红 | `settings_page.dart` |
| 用户资料 | Follow / Following | 原有 16px 圆环 | 原品牌红 / 灰底 | `user_profile_actions.dart` |
| 关注 / 粉丝列表、关注通知 | Follow / Following | 原有 15px 圆环 | 原品牌红 / 灰底 | `genesis_follow_user_list_tile.dart` |
| 普通登录 / 新用户登录 / 强制登录 | Google / Apple 登录 | 原有 22px 圆环替换左侧图标，保留文字 | 原登录底色 | `login_provider_button.dart` |
| 聊天输入框 | Send | 保留原有圆环；原调用关闭发送动画时保留图标 / 文字 | 原发送底色 | `chat_ui_composer.dart` |
| Location Chat 回复工具 | Go on / Inspiration / Regenerate / Edit | busy 时原有 17px 圆环 | 原透明底 | `reply_feature_button.dart` |
| 发帖 / 回复编辑弹层 | Send | 原有 18px 品牌红圆环 | 原透明底 | `discuss_composer_panel.dart` |
| Gems 任务 | Check in / 领取等接口下发操作 | 原文字，不加圆环 | 原透明底 | `gem_wallet_state_panels.dart` |
| 图片裁剪 | 确认 | 按钮禁用，原工具栏中间显示 24px 圆环 | 原透明底 | `local_image_crop_page.dart` |

## 不新增加载状态的操作

- 地点选择 Select、L3 地点本地 Save、标准弹窗确认等同步返回结果的按钮，保持原有行为。
- 会员/Gems 购买成功确认、签到确认、删除/拉黑/退出登录等公共确认弹窗，仍按原流程返回结果，由调用方处理后续工作，不为确认按钮新增圆环。
- Retry、页面导航、搜索、筛选、Tab、分页、附件增删及加载更多不是本次提交按钮统一范围；Developer 演示入口不纳入用户端清单。

## 公共控件调用

`GenesisPrimaryButton(isLoading: submitting)` 保留既有圆环；原先只有进度文字的按钮使用 `isLoading: submitting, showLoadingIndicator: false`。加载时保留正常底色；`disabledBackgroundColor` 只用于非加载的普通禁用状态。保留调用方原有的禁用提示回调。
