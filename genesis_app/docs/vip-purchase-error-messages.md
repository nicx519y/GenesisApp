# VIP 购买按钮与平台错误文案

购买流程更新：2026-09-15。适用 Android Google Play / iOS App Store 的 VIP 订阅购买。Gems 继续使用原有提示；用户可见称谓与取消拼写以 `premium-purchase-copy.md` 为准。

## 1. 商品接口和按钮

`GET /api/v1/membership/products` 提供 `data.list` 商品配置。页面打开时仍可刷新全局会员状态用于展示；点击购买不读取本地会员状态，也不发起或等待 wallet 请求；年转月、月转年、同套餐和无会员等情况统一交给平台购买，由平台决定是否允许。

已有同套餐有效会员且 wallet `membership.auto_renew=true` 时，按钮显示 `Subscribed`；`auto_renew=false` 时恢复 `Monthly: 价格`／`Yearly: 价格`，仍可点击继续平台购买。非同套餐和没有有效会员时沿用套餐金额文案。关闭自动续费只改变按钮文案，不改变尚未到期的会员权益。

全屏页面和购买 sheet 在 Subscription 标签下，每次 App 回到 `resumed` 都刷新 wallet，及时同步商店取消或恢复自动续费后的按钮文案。此刷新不受全局回前台 30 秒缓存限制，复用正在进行的请求；不会重新请求订阅商品列表，也不作为购买前置条件。

| 当前有效会员 | 选择月套餐 | 选择年套餐 | 点击处理 |
| --- | --- | --- | --- |
| 无／已失效 | 原 Monthly + 金额 | 原 Yearly + 金额 | 月付、年付均交给平台 |
| 月会员 | 自动续费开启：`Subscribed`；关闭：原 Monthly + 金额 | 原 Yearly + 金额 | 月付、年付均交给平台，不拦截同套餐购买 |
| 年会员 | 原 Monthly + 金额 | 自动续费开启：`Subscribed`；关闭：原 Yearly + 金额 | 月付、年付均交给平台，不在客户端拦截降级 |
| 未知／wallet 刷新失败 | 原套餐金额或仍有效的原展示状态 | 原套餐金额或仍有效的原展示状态 | 不等待 wallet，月付、年付均交给平台 |

`MembershipAccessStore` 会员快照仅用于页面展示，不参与购买资格判断。允许发起平台购买不代表确认具有会员权益。游客继续原有身份准备、未绑定订单登录提示及 report/claim。

同套餐的 `Subscribed` 只用于展示，点击不再产生客户端 `already_subscribed` 拦截。年转月也不再弹客户端不能降级提示。商品缓存 v3 仅存展示配置；商品及升级凭据仍复用本次页面 API 响应，不因点击购买重复请求，未完成时等待同一商品请求。缺少商品或身份凭据、账号切换、购买进行中等原有流程保护继续生效。

平台返回成功后继续 report 验单，返回取消或失败则走平台错误提示。补报与 Gems 的结果处理规则一致：网络异常、超时或 `accepted` 保存原凭据并重试；`completed` 完成订单并刷新钱包；明确 `rejected` 为终态，不自动反复上报。VIP 保留 15 秒起步、最长 5 分钟的退避重试，以及启动／回前台恢复。Apple `account_mismatch` 仍不 finish 其他账号的交易，沿用原有归属恢复流程。补报只重试 report，不重新发起平台扣款。

## 2. Google Play 主错误码

来源：[BillingResponseCode 官方定义](https://developer.android.com/reference/com/android/billingclient/api/BillingClient.BillingResponseCode)。以下覆盖当前 BillingClient 的 13 个响应值（含成功和已弃用超时码）；SDK 包装使用 camelCase 名，客户端统一映射。

| 数值 | 平台码 | 显示文案 / 处理 |
| --- | --- | --- |
| -3 | `SERVICE_TIMEOUT` | Google Play took too long to respond. Please try again. |
| -2 | `FEATURE_NOT_SUPPORTED` | Subscriptions are not supported by Google Play on this device. |
| -1 | `SERVICE_DISCONNECTED` | The connection to Google Play was lost. Please try again. |
| 0 | `OK` | 不显示错误。launch 返回 OK 只表示支付窗口已启动，继续等待支付回调和 report 确认。 |
| 1 | `USER_CANCELED` | VIP purchase cancelled. |
| 2 | `SERVICE_UNAVAILABLE` | Google Play is temporarily unavailable. Please try again later. |
| 3 | `BILLING_UNAVAILABLE` | Google Play billing is unavailable. Please check your Play account and payment settings. |
| 4 | `ITEM_UNAVAILABLE` | This VIP plan is currently unavailable on Google Play. |
| 5 | `DEVELOPER_ERROR` | Premium purchase canceled. |
| 6 | `ERROR` | Google Play could not complete this VIP purchase. Please try again. |
| 7 | `ITEM_ALREADY_OWNED` | You already own this subscription on Google Play. Please check Manage subscriptions. |
| 8 | `ITEM_NOT_OWNED` | Google Play could not find the subscription to change. Please check Manage subscriptions. |
| 12 | `NETWORK_ERROR` | Could not connect to Google Play. Please check your internet connection and try again. |

`DEVELOPER_ERROR=5` 不能单独证明是 UUID 冲突，也不能证明订阅未过期。具体参数问题看原始 `debugMessage`，例如之前的账号标识不匹配信息。客户端不根据可变的英文 debugMessage 推断订阅状态，也不自动更换 UUID 或重复发起扣款。

当 Google 返回 `DEVELOPER_ERROR`，且原始 `debugMessage`（或发起购买／查询商品异常的原始 message）去除首尾空白后完全等于 `Account identifiers don't match the previous subscription.` 时，直接显示该句原文。其他 `DEVELOPER_ERROR` 使用取消文案 `Premium purchase canceled.`；已知子错误码仍优先。仅替换展示文案，错误分类仍为失败，不视为用户主动取消，也不参与会员状态、购买身份或重试决策。

### Google 子错误码

来源：[OnPurchasesUpdatedSubResponseCode 官方定义](https://developer.android.com/reference/com/android/billingclient/api/BillingClient.OnPurchasesUpdatedSubResponseCode)。子码用于进一步说明回调失败；非成功、非用户取消时，已知子码文案优先于主码。没有子码或未知子码回退主码。

| 数值 | 子码 | 显示文案 / 处理 |
| --- | --- | --- |
| 0 | `NO_APPLICABLE_SUB_RESPONSE_CODE` | 使用主码文案 |
| 1 | `PAYMENT_DECLINED_DUE_TO_INSUFFICIENT_FUNDS` | Your payment method has insufficient funds. Please update it in Google Play and try again. |
| 2 | `USER_INELIGIBLE` | Your Google Play account is not eligible for this subscription offer. |

## 3. Apple StoreKit 2 错误

StoreKit 2 返回具名 Error case，不能把它们当作 Google 数字码。桥接保留 `storeKitCode`、NSError `domain/nativeCode` 和底层错误。来源：[StoreKitError](https://developer.apple.com/documentation/storekit/storekiterror)、[Product.PurchaseError](https://developer.apple.com/documentation/storekit/product/purchaseerror)。

| 错误类型 | case | 显示文案 |
| --- | --- | --- |
| StoreKitError | `unknown` | The App Store could not complete this VIP purchase. Please try again. |
| StoreKitError | `userCancelled` | VIP purchase cancelled. |
| StoreKitError | `networkError` | Could not connect to the App Store. Please check your internet connection and try again. |
| StoreKitError | `systemError` | The App Store encountered a system error. Please try again later. |
| StoreKitError | `notAvailableInStorefront` | This VIP plan is not available in your App Store region. |
| StoreKitError | `notEntitled` | This app cannot make this App Store request. Please contact support. |
| StoreKitError | `unsupported` | This purchase is not supported on this device or system version. |
| StoreKitError | `invalidPresentationContext` | The App Store purchase window could not open. Please return to the app and try again. |
| Product.PurchaseError | `invalidQuantity` | The App Store could not accept this purchase quantity. Please contact support. |
| Product.PurchaseError | `productUnavailable` | This VIP plan is currently unavailable on the App Store. |
| Product.PurchaseError | `purchaseNotAllowed` | Purchases are not allowed on this device. Please check your Apple Account and purchase restrictions. |
| Product.PurchaseError | `ineligibleForOffer` | Your Apple Account is not eligible for this subscription offer. |
| Product.PurchaseError | `invalidOfferIdentifier` | This subscription offer is unavailable. Please refresh the page and try again. |
| Product.PurchaseError | `invalidOfferPrice` | The App Store could not accept this offer price. Please refresh the page and try again. |
| Product.PurchaseError | `invalidOfferSignature` | The App Store could not verify this subscription offer. Please contact support. |
| Product.PurchaseError | `missingOfferParameters` | This subscription offer could not be prepared. Please refresh the page and try again. |
| Product.PurchaseError | `paymentMethodBindingConfigurationRequired` | Please add a payment method to your Apple Account, then try again. |

`notEntitled` 指 App 缺少平台能力授权，不是“用户没有 VIP”。`invalidPresentationContext` 在 Apple 文档标为 Beta，本机 SDK 尚无此枚举成员；保留未来错误名称的兼容映射，未知值走兜底。`paymentMethodBindingConfigurationRequired` 在本机 SDK 标注 iOS 26.5+，提示用户添加支付方式，本次不新增 PaymentMethodBinding 原生流程。底层 `systemError` 若包含明确 SKError 或网络码，优先显示对应提示。

## 4. Apple SKErrorDomain 数字码

兼容 StoreKit 1 支付回调，以及 StoreKit 2 底层 NSError。数字只有与 `SKErrorDomain` 组合时才按本表解释；其它 domain 不套用此表。来源：[SKError.Code](https://developer.apple.com/documentation/storekit/skerror/code) 和本机 Xcode SDK 的 `StoreKit.framework/Headers/SKError.h`（0–21）。部分 cloud/overlay 错误通常不来自普通订阅购买，仍提供映射，不代表订阅具有这些“异常状态”。

| 数值 | SKError.Code | 显示文案 |
| --- | --- | --- |
| 0 | `unknown` | The App Store could not complete this VIP purchase. Please try again. |
| 1 | `clientInvalid` | This app cannot make purchases on the App Store. Please contact support. |
| 2 | `paymentCancelled` | VIP purchase cancelled. |
| 3 | `paymentInvalid` | The App Store could not accept this purchase request. Please try again or contact support. |
| 4 | `paymentNotAllowed` | Purchases are not allowed on this device. Please check your Apple Account and purchase restrictions. |
| 5 | `storeProductNotAvailable` | This VIP plan is not available in your App Store region. |
| 6 | `cloudServicePermissionDenied` | Apple cloud service access was denied. Please check your Apple Account permissions. |
| 7 | `cloudServiceNetworkConnectionFailed` | Could not connect to Apple services. Please check your internet connection and try again. |
| 8 | `cloudServiceRevoked` | Apple cloud service access was revoked. Please check your Apple Account settings. |
| 9 | `privacyAcknowledgementRequired` | Please accept the latest Apple privacy terms in your Apple Account, then try again. |
| 10 | `unauthorizedRequestData` | This app cannot make this App Store request. Please contact support. |
| 11 | `invalidOfferIdentifier` | This subscription offer is unavailable. Please refresh the page and try again. |
| 12 | `invalidSignature` | The App Store could not verify this subscription offer. Please contact support. |
| 13 | `missingOfferParams` | This subscription offer could not be prepared. Please refresh the page and try again. |
| 14 | `invalidOfferPrice` | The App Store could not accept this offer price. Please refresh the page and try again. |
| 15 | `overlayCancelled` | VIP purchase cancelled. |
| 16 | `overlayInvalidConfiguration` | The App Store window could not be configured. Please contact support. |
| 17 | `overlayTimeout` | The App Store window took too long to open. Please try again. |
| 18 | `ineligibleForOffer` | Your Apple Account is not eligible for this subscription offer. |
| 19 | `unsupportedPlatform` | This purchase is not supported on this device or system version. |
| 20 | `overlayPresentedInBackgroundScene` | Please return to the app and try your purchase again. |
| 21 | `paymentMethodBindingConfigurationRequired` | Please add a payment method to your Apple Account, then try again. |

### Apple 网络底层错误

来源：[Apple Handling errors](https://developer.apple.com/documentation/storekit/handling-errors)。网络域按连接问题处理，不根据某个网络错误认定付款成功或失败到账。

| 域 / 码 | 显示文案 |
| --- | --- |
| `NSURLErrorDomain / -1001` | The App Store took too long to respond. Please try again. |
| `NSURLErrorDomain` 其它码（如 -1003/-1004/-1005/-1009/-1012/-1200） | Could not connect to the App Store. Please check your internet connection and try again. |

## 5. 客户端及插件准备错误

这些是本项目/Flutter 插件错误，不是商店订阅生命周期状态。仅针对当次购买显示，不新增旧订单缓存或阻止后续购买的历史状态。

| 本地错误码 | 显示文案 |
| --- | --- |
| `store_unavailable` | Google Play is unavailable. Please check that it is installed and you are signed in. |
| `membership_product_not_found` | This VIP plan is currently unavailable in the store. Please refresh the page and try again. |
| `invalid_membership_product` | This VIP plan could not be prepared. Please refresh the page and try again. |
| `membership_launch_rejected` | The store could not open this VIP purchase. Please try again. |
| `membership_upgrade_purchase_missing` | The original subscription was not found in Google Play. Please check Manage subscriptions. |
| `membership_upgrade_account_mismatch` | This subscription uses a different purchase identity. Please refresh the page or contact support. |
| `membership_upgrade_not_ready` | Google Play cannot change this subscription yet. Please check Manage subscriptions. |
| `storekit_duplicate_product_object` | An App Store purchase for this plan is still being processed. Please wait for it to finish. |
| `storekit2_failed_to_fetch_product` | This VIP plan is currently unavailable on the App Store. |
| `storekit2_products_error` | Could not load VIP plans from the App Store. Please try again. |
| `purchase_preparation_expired` | Purchase preparation expired. Please try again. |
| `storekit2_unknown_purchase_result` | The App Store returned an unknown purchase result. Please check your subscription before trying again. |

## 6. 不是错误的购买结果与兜底

| 结果 | 显示 / 后续处理 |
| --- | --- |
| Google `PENDING`、Apple `.pending` | `VIP payment is pending.`，等待后续平台结果，按原逻辑处理凭据 |
| 用户主动取消 / Apple `.userCancelled` | `VIP purchase cancelled.`，关闭购买 Loading，不上报支付成功 |
| 平台返回已支付 / Apple `.success` | 继续原 report 验单，不能只凭 launch OK 或商店成功回调就显示服务端已确认 |
| report accepted | `Your VIP purchase is being confirmed.`，原有补报逻辑继续 |
| report/确认延迟 | `VIP purchase confirmation is delayed. Please check again later.` |
| report completed | 原 VIP 成功弹窗 |
| 未识别 Google 错误 | `Google Play could not complete this VIP purchase. Please try again.` |
| 未识别 Apple 错误 | `The App Store could not complete this VIP purchase. Please try again.` |

Apple 购买结果来源：[Product.PurchaseResult](https://developer.apple.com/documentation/storekit/product/purchaseresult)。服务端 report/claim 业务错误仍走原业务提示，不套平台码表。会员到期、宽限、扣款重试、暂停等是订阅生命周期状态，不能与本表的购买调用错误一一对应；客户端不根据会员状态拦截购买，年转月也以平台结果为准。

## 7. 错误传递和验证

- Google：VIP opt-in 保留 launch 返回的主码/子码/debugMessage；商品查询仅查询 SUBS，避免 INAPP 查询错误掩盖订阅错误；购买回调保留原始 details。Gems 未开启该 opt-in。
- Apple：商品查询和 purchase 抛错经过 Swift → Pigeon → Dart，保留具体 Error case、原生域/码与底层错误；旧 StoreKit 回调从交易对象提取 SKError。
- VIP 三个阶段（查商品、发起购买、支付回调）共用一张映射表，错误关闭当前购买弹窗并显示居中 Toast，不自动再次购买。
- Debug 日志 `[Membership][store_error]` 保留平台原始 code/message/details，不脱敏；Google 原生调试日志也继续保留。Release 不打印这些日志，用户提示为上述可读文案；既有 Debug Toast 的诊断前缀不属于英文正文。
- 代码入口：`lib/app/membership/membership_store_failure.dart`；测试覆盖接口状态、按钮矩阵、缓存刷新、平台错误传递及原生 StoreKit Error 编码。真机真实付款、不同账号/地区/支付方式的商店弹窗仍需商店环境验证；测试不进行真实扣款。

原生错误桥接回归命令（macOS + Xcode）：

```sh
xcrun swiftc -module-cache-path /private/tmp/vip-swift-module-cache third_party/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/StoreKit2/StoreKitPurchaseError.swift test/native/storekit_purchase_errors/main.swift -o /private/tmp/vip-storekit-errors
/private/tmp/vip-storekit-errors
```

## 8. 取消本地会员资格拦截验证（2026-09-15）

会员服务、平台适配与按钮回归 425 项通过；修正弹窗测试的注入参数及计时器清理后，单独重跑弹窗测试 23 项通过，合计 448 项。静态检查 12 个相关文件无问题。未进行真机商店支付联调。

```sh
flutter test --no-pub test/app/membership test/platform/billing/membership_pending_store_test.dart test/platform/billing/membership_checkout_platform_test.dart test/components/pro_subscription_content_test.dart test/components/membership_purchase_presentation_test.dart
flutter test --no-pub test/components/membership_purchase_presentation_test.dart
flutter analyze --no-pub lib/app/bootstrap/service_registry.dart lib/app/membership/membership_access_store.dart lib/app/membership/membership_purchase_eligibility.dart lib/app/membership/membership_purchase_service.dart lib/components/gems/pro_subscription_content.dart lib/components/gems/membership_purchase_presentation.dart test/app/membership/membership_purchase_service_test.dart test/app/membership/membership_purchase_eligibility_test.dart test/app/membership/membership_purchase_identity_test.dart test/platform/billing/membership_pending_store_test.dart test/components/pro_subscription_content_test.dart test/components/membership_purchase_presentation_test.dart
git diff --check
```

## 9. 历史验证记录

此前错误文案与原生桥接改动执行了以下命令（项目根目录），当时相关回归测试 **643 项通过**；静态检查无问题；原生 StoreKit 错误桥接检查通过。未进行真实扣款测试。

```sh
flutter test --no-pub test/app/membership test/platform/billing test/components/pro_subscription_content_test.dart test/components/membership_purchase_presentation_test.dart test/network/models/membership_product_list_test.dart test/network/membership_api_test.dart test/network/genesis_api_test.dart test/network/local_mock_genesis_transport_test.dart test/network/membership_request_privacy_test.dart --reporter expanded

flutter analyze --no-pub lib/app/bootstrap/service_registry.dart lib/app/membership lib/components/gems/pro_subscription_content.dart lib/components/gems/membership_purchase_presentation.dart lib/network/models/membership_product.dart lib/network/membership_request_privacy.dart lib/network/local_mock_genesis_transport.dart lib/platform/billing test/app/membership test/platform/billing test/components/pro_subscription_content_test.dart test/components/membership_purchase_presentation_test.dart test/network/models/membership_product_list_test.dart test/network/genesis_api_test.dart test/network/local_mock_genesis_transport_test.dart
```

原生桥接另外通过 iOS arm64（最低 iOS 15）模块编译：

```sh
xcrun swiftc -module-cache-path /private/tmp/vip-ios-swift-cache -sdk /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk -target arm64-apple-ios15.0 -parse-as-library -emit-module -module-name VipStoreKitError -emit-module-path /private/tmp/VipStoreKitError.swiftmodule third_party/in_app_purchase_storekit/darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/StoreKit2/StoreKitPurchaseError.swift
```

整包验证执行了两次 `flutter build ios --debug --no-codesign --no-pub --flavor production`，均停在 Xcode 启动的 `clang -v -E -dM ... /dev/null` 编译器探测阶段；同一探测命令单独运行正常。已停止无响应构建，**没有取得整包编译通过的结果**。没有安装或执行真实商店付款。

## 购买 Toast 调试信息开关

- Debug Page → switch → Purchase → Show debug toast details，仅 Debug 包显示，默认关闭。设置持久化，重启后沿用用户选择。
- 关闭时 Gems / Premium 购买 Toast 只显示正常文案；开启时第一行显示原有 `debug：阶段/状态/错误`。Profile/Release 始终不显示调试首行。该开关不改变购买、上报、重试和成功弹窗行为。
