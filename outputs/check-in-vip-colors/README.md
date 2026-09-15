# 签到弹窗文字样式

- Get 100 与 Check in 均复用公共操作组件：Inter、15 逻辑像素、w600、行高 1.2。
- 非会员：Get 100 为 redSecondary；Check in 保持 darkTextPrimary 白色。
- 会员：Check in 为 redSecondary；Cancel 保持原有白色和字重。

截图使用实际 showDailyCheckInDialog、GenesisTheme.dark、Inter 字体与 SVG 资源，由 Flutter 渲染生成。预览注入会员状态，奖励使用预览默认值 +50；不是线上接口数据或真机支付截图。

验证基线：HEAD a7703c5ca1f81e5a165b899bf5a4fa7324638af4 加本次签到组件和对应测试改动，隔离目录 /tmp/check-in-unified-style-x59u8z7b/genesis_app。

当前工作区首次运行测试因其他未完成改动编译失败（ProUserName 参数与 Discuss 调用不匹配）。隔离副本内 23 项签到相关测试及截图渲染全部通过，当前工作区最终相关文件静态检查通过，git diff --check 通过。

实际运行命令：

```sh
# 先在当前工作区运行；随后在上述隔离副本运行同一命令
flutter test --no-pub test/check_in_color_preview_tmp_test.dart test/components/daily_check_in_dialog_test.dart test/components/daily_check_in_guest_claim_test.dart
# 当前工作区
flutter analyze --no-pub lib/components/gems/daily_check_in_dialog.dart test/components/daily_check_in_dialog_test.dart
/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format lib/components/gems/daily_check_in_dialog.dart test/components/daily_check_in_dialog_test.dart
git diff --check
```

日志：/tmp/check-in-unified-style-tests.log、/tmp/check-in-unified-style-isolated-tests.log、/tmp/check-in-unified-style-analyze.log。
截图脚本保留在本目录 render_preview_test.dart，未加入日常测试套件。未安装到设备验证。
