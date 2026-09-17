# 全局 VIP 状态

入口：`AppServices.membership`（`MembershipAccessStore`）。复用现有
`GemWalletStore` 请求 `/api/v1/gem/wallet`，只读取其中的 `membership`。

钱包会员模型只解析 `membership_status`、`plan_code`、`expires_at`、
`auto_renew`、`blue_gems_cent` 五个字段。服务端返回这些字段即可解析会员信息，
不依赖额外的重叠订阅标记。Me 页卡片继续使用全局会员状态判断是否有效。

## 业务调用

```dart
final services = AppServicesScope.read(context);
services.membership.checkVip((isVip) {
  if (!context.mounted) return; // 回调需要操作页面时检查页面是否仍存在。
  if (isVip == true) {
    // 已确认会员有效，继续会员操作。
  } else if (isVip == false) {
    // 已确认非会员；按业务需要进入订阅流程。
  } else {
    // 暂时无法确认，保留重试机会，不能当作已确认非会员。
  }
});
```

- 业务方只使用 `checkVip(callback)`，返回类型为 `void`，不需要 `await`。
  回调参数是 `bool?`：`true / false / null` 分别表示有效 / 无会员 / 未知。
- 缓存有效时使用缓存；数据缺失或过期时内部请求钱包。并发调用共用请求，
  每个调用方分别收到一次回调，也复用 Me 页已经发起的钱包请求。
- 无论使用缓存还是请求接口，回调都在 `checkVip` 返回之后执行一次；失败或超时
  会回调 `null`。迟到的网络响应只更新缓存，不再次通知同一次调用。
- 结果送达前发生退出、切换账号或服务释放时，回调 `null`，不交付旧账号权益。
- 原 `isVip` getter 和 `ensureFresh()` 不再作为公开业务入口；
  UI 通过只读 `state` 订阅展示状态，`debugState` 仅用于测试诊断。

### 订阅购买入口

- 未登录用户点击购买时，当前商品响应的 `has_subscription_order=true` 则弹登录窗并结束本次点击，不调用 prepare、商店购买或 report；登录后不自动续购。已登录用户继续原流程。此字段与 `last_account_uuid` 平级，只使用本次接口响应，不写入商品展示磁盘缓存。
- 点击月会员时使用全局 `checkVip` 的缓存/在途钱包请求确认状态；只有当前账号 `membership_status=1`、`expires_at` 未过期且 `plan_code=pro_yearly` 才拦截，沿用不能降级的 Toast。年会员购买不读取会员状态，其余状态不作资格拦截，交给平台回调。不会每次点击强制刷新 wallet。
- 页面打开时的展示刷新及 report/claim 成功后的钱包刷新保持原有流程。同套餐有效会员仅在 `auto_renew=true` 时显示 `Subscribed`；`auto_renew=false` 时恢复 `Monthly: 价格`／`Yearly: 价格`。该字段只影响按钮文案，不作为购买拦截条件，也不改变尚未到期的会员权益。
- 全屏购买页和购买 sheet 在选中 Subscription 时，每次 App `resumed` 都调用 `membership.refresh()` 请求最新 wallet，不受全局 30 秒回前台缓存限制；复用正在进行的钱包请求。刷新后更新按钮，失败保留仍有效的旧展示，下次回前台继续刷新。未登录继续跳过需要登录态的钱包接口，月会员点击复用全局会员查询。
- report 响应仅解析 `data.status`，删除 report_id/membership_id/reason 依赖。网络失败／超时保存原凭据重试，`accepted` 继续补报，`completed`／`rejected` 为终态；补报不重新调起平台购买。

### 商品预加载

- 启动身份及必要的未绑定支付登录检查结束后，后台请求 `/api/v1/membership/products`，与 personalization 请求并行，不阻塞首页或填表。填表开关关闭时也预加载，供 Home 等订阅入口复用。
- 所有订阅入口共用 `MembershipCatalog`：每次打开订阅全屏页或 sheet 都重新请求商品列表，不受 1 分钟缓存限制；已有缓存／预加载结果仅用于先展示。进入时发起的新请求也更新下单凭据，购买点击等待这次请求，不使用旧缓存直接下单。仅后台预加载继续复用进行中的请求或同一账号下 1 分钟内成功取得的结果。
- 购买 report 完成或 claim 状态变化后，先使旧下单凭据失效；仍打开的订阅页面立即静默重新请求商品列表，更新展示与下单凭据。购买成功后原有关闭页面／sheet 的交互保持不变，下次进入仍重新请求。
- 登录、退出、换号以及 report／claim 状态变化使下单缓存失效；旧请求不能覆盖新结果。列表顶层 `last_account_uuid`、`has_subscription_order` 只保留在内存中，不写入商品展示缓存。
- 游客登录成功时，全屏页与底部订阅面板保留原页面、当前月付／年付选择及权益滚动位置；读取登录状态与刷新商品期间不切成整页 Loading、不清空现有展示。商品和会员状态在后台按登录账号刷新，成功后直接更新 UI，商品请求失败保留原展示。Buy Gems 标签动态加入，不重建 Subscription。保留的旧商品仅用于展示，下单快照仍随登录失效并等待新接口响应；退出或切换已有账号继续隔离其 Gems 页面数据。
- 商品预加载失败只记录诊断，不弹 Toast，不改变 Continue 的会员判断，也不提前调用平台购买或 report。

每次进入刷新改动的本地验证命令（2026-09-16，95 项相关测试、4 项 Home 入口测试及静态检查通过，未重新安装真机验证）：

```sh
flutter test --no-pub test/app/membership/membership_catalog_test.dart test/components/pro_subscription_content_test.dart test/components/personalization_gate_test.dart
flutter test --no-pub test/widget_test.dart --plain-name 'Home crown'
flutter analyze --no-pub lib/app/membership/membership_catalog.dart test/app/membership/membership_catalog_test.dart test/components/pro_subscription_content_test.dart test/components/personalization_gate_test.dart test/widget_test.dart
git diff --check
```

预加载改动的本地验证命令（2026-09-15）：

```sh
flutter test --no-pub test/app/membership/membership_catalog_test.dart test/components/personalization_gate_test.dart test/components/pro_subscription_content_test.dart
flutter test --no-pub test/widget_test.dart --plain-name 'Home crown'
flutter test --no-pub test/components/personalization_gate_test.dart --plain-name 'startup waits for guest check; Continue never checks again'
flutter analyze --no-pub lib/app/membership/membership_catalog.dart lib/components/gems/pro_subscription_content.dart lib/components/onboarding/personalization_gate.dart lib/app/genesis_app.dart lib/app/bootstrap/service_registry.dart test/app/membership/membership_catalog_test.dart test/components/pro_subscription_content_test.dart test/components/personalization_gate_test.dart test/widget_test.dart
```

前两组共 95 项通过；补充的身份顺序断言单独复测通过。覆盖 Apple／Google 商品缓存、并发请求合并、失效和失败重试、填表及 Home 实际路由复用；不代表真机支付联调。

## 判断与刷新

1. 未登录不请求需要登录态的钱包接口；当前账号权益返回 `inactive`。
   已有 UID 但后端 token 缺失时返回 `unknown`，不清除登录态。
2. `membership_status=0/2` 是已知无效；`membership` 缺失或解析失败是 `unknown`。
3. `membership_status=1` 且已知到期时间晚于服务器时间时有效。
   缓存显示已到期时重新请求确认；仍返回已过期时间时维持 `unknown`，
   等服务端同步完成，不能单凭本地缓存推断自动续费失败。
4. `expires_at=null` 或服务器时间尚未校准时，采用刚拉取的服务端状态，
   有效会员缓存缩短至 30 秒。其他缓存最长 5 分钟。
5. 服务器时间来自现有 Gateway 时间校准，之后按单调计时推进，
   到期比较不直接使用设备 `DateTime.now()`。
6. 启动时恢复会话后后台预取，不阻塞首页；缺失后端 token 时先尝试原有恢复流程。
   登录/换号后刷新，退出登录立即清空会员缓存并隔离旧请求。
7. 返回前台时，距上次有效响应不足 30 秒不重复请求；已过期时重新确认。
   不设置会员到期定时器，不因到达 `expires_at` 自动刷新页面或请求 wallet。
   接口刷新、调用会员判断和返回前台时仍校验有效期；普通缓存计时及状态发布保留，不持续轮询接口。
8. 购买、恢复、claim 完成后，复用原有 `refreshAfterMembershipChanged()` 的最新
   钱包响应更新全局状态，不额外再发一次钱包请求。
9. 单次查询最多等待 20 秒。没有可用信息时失败返回 `unknown`；后续调用经过
   2、4、8、16、30 秒（上限）冷却后可重试。没有无限后台重试任务；
   已知且仍有效的旧缓存不会因一次刷新失败被清空。

现有 Gems 金额计算、购买、UI 和 VIP 订单/claim 重试逻辑不作调整。
这里的缓存用于客户端业务判断，购买及权益的最终确认仍来自服务端。

## 验证

在项目目录执行，Flutter SDK 路径为 `/opt/homebrew/share/flutter/bin`：

```sh
dart format lib/app/membership/membership_access_store.dart test/app/membership/membership_access_store_test.dart test/widget_test.dart
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test --no-pub test/app/membership/membership_access_store_test.dart test/app/gems/gem_wallet_store_test.dart
PUB_HOSTED_URL=https://pub.flutter-io.cn flutter test --no-pub test/widget_test.dart --plain-name 'membership '
dart analyze lib/app/membership/membership_access_store.dart lib/app/bootstrap/app_bootstrap.dart lib/app/bootstrap/service_registry.dart test/app/membership/membership_access_store_test.dart test/widget_test.dart
git diff --check
```

2026-09-09 回调接口验证结果：会员状态及回调 24 项、钱包 9 项、启动/登录 2 项均通过；
静态分析和差异检查通过。此前全局服务实现还通过了时钟、Gateway、购买/恢复/claim
及 Gems 页面相关测试。
覆盖失败重试、并发合并、缓存与到期、时钟、登录隔离、迟到响应、启动及登录接入。
真机弱网、后台挂起及服务端真实续费场景仍需联调验证。

### 购买身份（2026-09-16）

- 商品项删除 can_purchase、purchase_block_reason、purchase_action、account_uuid、purchase_token。`last_account_uuid` 与 list 平级，非空时登录/游客均优先使用。为空时游客 prepare，登录用户读取本人 UUID。
- base_plan_id / offer_id 仍用于选中 Google 套餐；同一商品的套餐切换由 Play 默认替换配置决定。不再依赖商品接口的旧 token。
