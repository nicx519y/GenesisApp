# Worldo 首次列表加载

- 用户手动选择 All／Male／Female／Non binary 后，按账号持久保存（匿名设备单独保存）；All 保存为空字符串，未选择用 null 区分。
- 再次进入或重启 App，优先恢复手动选择和对应列表缓存，直接按该值请求第一页。无需等待 personalization，也不读取 userInfo 来决定筛选值。
- 手动选择持续生效，直到用户再次选择其他值；资料或 config 返回不会覆盖它。首屏、下拉刷新、其他分类和分页统一使用该值。
- 没有手动选择时，才走自动逻辑：登录用户读取本地 `userInfo.gender`；匿名用户等待 config／personalization 的现有启动流程。Male 用户请求 Female，Female 用户请求 Male。
- 自动逻辑等待期间先显示上次确认的显示值与列表缓存，资料确认后再请求一次第一页，不先发 All。资料返回空性别／Non_binary、关闭填表或资料请求失败时，按 All 兜底。
- 本地缓存尚未读完时不先显示默认 All；首个网络结果返回前不使用缓存游标分页。
- 切换账号后读取该账号自己的选择，不沿用其他账号的偏好、游标或列表。

热点分类请求和本地缓存读取继续并行；不修改登录、填表和支付流程。

## 验证

在 `genesis_app/` 执行以下命令。35 个 audience／缓存单元测试和 29 个页面回归测试通过；定向静态检查无问题。尚未进行真机联调。

```sh
/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format lib/pages/origin/origin_feed_audience.dart lib/pages/origin/origin_feed_cache_store.dart lib/pages/origin/origin_page.dart test/pages/origin/origin_feed_audience_test.dart test/pages/origin/origin_feed_cache_store_test.dart test/widget_test.dart
/opt/homebrew/share/flutter/bin/flutter test --no-pub test/pages/origin/origin_feed_audience_test.dart test/pages/origin/origin_feed_cache_store_test.dart
/opt/homebrew/share/flutter/bin/flutter test --no-pub test/widget_test.dart --name 'Origin (keeps manual gender|restores manual gender|restores cached gender|waits for guest personalization|keeps cache visible while config and gender resolve|manual All bypasses pending profile|targets |gender filter applies|manual All is not|restarts the cursor|ignores the previous audience|renders cached|starts hot tags|retries |keeps the skeleton)|Initial Worldo '
/opt/homebrew/share/flutter/bin/flutter analyze --no-pub lib/pages/origin/origin_feed_audience.dart lib/pages/origin/origin_feed_cache_store.dart lib/pages/origin/origin_page.dart test/pages/origin/origin_feed_audience_test.dart test/pages/origin/origin_feed_cache_store_test.dart test/widget_test.dart
```
