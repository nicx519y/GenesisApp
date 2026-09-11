# 用户名会员徽章接入记录

2026-09-11：已在 Apifox 当前项目 `account / 查询用户信息` 的接口说明核对公开目标用户会员状态。采用已有 `GET /api/v1/user/info?uid=...`，读取 `data.user.membership_status`，只接受目标 UID 一致且状态为整数 1。其他状态、删除用户、过期缓存或失败隐藏。Me 的本人钱包链路保留。

## 展示入口

| 入口 | 对应 UID |
| --- | --- |
| Followers / Following、Followers 通知 | 列表用户 uid |
| Search 用户 / Worldo Creator / World Owner | user.uid / origin.owner.uid / world.owner.uid |
| Inbox 私信列表 | peerUid |
| Comments 通知、加入申请通知 | senderUid；原来显示 You 的审核摘要保持原文，不给代词加徽章 |
| Worldo Detail Creator、Discuss 顶部作者 | origin.ownerUid |
| Worldo Discuss、Discuss、Post Detail 作者和回复者 | authorUid / author.uid |
| 回复中的被回复者、Reply to 输入提示 | reply_to_uid |
| World Detail Owner | world.ownerUid |
| World Detail Cast / Status 的其他玩家名 | player_uid；保留自身角色不重复显示账号名的规则 |
| World 新玩家加入提示 | notice.playerUid |
| Me / Profile World 卡片 Owner | 由接口透传 owner_uid，兼容 created_uid |

公共排版：`ProUserName`、`ProUserBadge.span` 和 `GenesisInlineMetaLabel.membershipUid`，统一复用 `ProMembershipBadge`。查询缓存和并发由 `UserMembershipStatusStore` 管理，无按昵称猜 UID，无内部接口调用，无逐页面独立缓存。

## 验证

实际运行（均在 genesis_app 下）：

```sh
# 所有修改的 Dart 文件均执行 dart format；以下为最终相关组件回归。
flutter test --no-pub test/app/membership/user_membership_status_store_test.dart test/components/pro_user_name_test.dart test/components/discuss_page_test.dart test/components/discuss_post_input_test.dart test/pages/world/world_sections_characters_test.dart test/components/profile_collection_list_test.dart
flutter test --no-pub test/app/membership/user_membership_status_store_test.dart
flutter test --no-pub test/app/membership/user_membership_status_store_test.dart test/components/pro_user_name_test.dart test/network/genesis_api_test.dart test/network/local_mock_genesis_transport_test.dart
flutter test --no-pub test/app/membership/user_membership_status_store_test.dart test/components/discuss_page_test.dart test/components/origin_discuss_list_test.dart test/components/discuss_post_input_test.dart test/pages/search/search_page_test.dart
flutter test --no-pub test/components/discuss_page_test.dart test/components/origin_discuss_list_test.dart
flutter test --no-pub test/components/pro_user_name_test.dart
dart analyze lib test/app/membership/user_membership_status_store_test.dart test/components/pro_user_name_test.dart test/components/discuss_page_test.dart test/components/origin_discuss_list_test.dart
dart analyze lib/app/membership/user_membership_status_store.dart lib/components/gems/pro_user_name.dart lib/app/bootstrap/service_registry.dart lib/components/common/copyable_id_label.dart test/app/membership/user_membership_status_store_test.dart test/components/pro_user_name_test.dart
git diff --check
```

- 最终相关组件回归 48 项通过；会员缓存过期的单独复测通过。
- 核心查询覆盖合法枚举、未知/异常/删除/UID 不匹配、缓存、重复请求、并发上限、会话切换、销毁；排版覆盖长用户名、省略、居中、系统文字缩放，以及没有徽章时无预留间距。
- API / mock transport 回归通过；搜索、Discuss 和发帖组件回归通过。
- 初次引入行内 WidgetSpan 后，旧测试纯文本定位包含了占位符；已仅对相应回复断言改用忽略组件占位符的文字匹配。新增排版测试的测试环境平台恢复顺序已修正，单独复测通过。
- origin_discuss_list_test 仍有 6 项历史失败：4 项来自旧 world progress 请求未结束的定时器，2 项为 progress 数字断言。已在独立 worktree 的修改前 f2e166d3 复现相同 6 项失败（21 项通过）。未为本次徽章修改扩展处理旧 progress 逻辑。
- 核心改动及新增测试的静态检查无问题；全 lib 检查仍有既有的未使用参数/声明、条件块和 cacheExtent 弃用提示。本次未进行真机视觉验收。
