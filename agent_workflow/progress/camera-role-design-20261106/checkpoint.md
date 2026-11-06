# 开场页编辑 + 生图描述 + 卡片 Identity · 2026-11-06

基线 869740d1（camera-role-dev-debug-20261106 这个包），分支 feature/camera-role-design-polish-20261106，未提交。设计稿在 `worldo/界面设计/开场页角色编辑`（方案二）和 `worldo/界面设计/聊天生图描述`（方案六 A）。

## 改动

1. 生图描述：`chat_ui_image_message_bubble.dart` 的 `_ChatPhotoDescription`。图下 8 居中，旁白底，圆角 8，内边距 6 / 12，最宽 282，13 / 18，白 95%，前后加「」，首尾已成对的引号或括号先去掉，不限行数。
2. 角色编辑：新文件 `origin_world_role_editor.dart`。卡内编辑和键盘滚动联动已删除，`_OriginRoleEditorHost` 同时铺在浮窗上和全屏 location 页上。全屏页稿子没画，做法是表单铺满整页。返回键和边缘滑动都等同 Cancel。`worldoLaunchProfile` 改为 Your Persona，8 个语言已翻译。
3. 卡片正面 Identity 最多 3 行。点开详情完整显示，去掉了线上详情里名字和字段的 3 行限制（用户 2026-11-06 复核后要求）。

## 稿子没定、我定的

键盘 Done 只收键盘不提交；去掉线上头像的删除按钮；选图后不重新弹键盘。

## 验证

- l10n check 90 项通过。
- origin 相关测试：通过 189，失败 44，失败全部和基线相同。旧键盘几何单测 12 条随功能删除。
- 3 条测试本来就在失败且还引用旧卡内编辑，没有改：Origin profile keyboard hides composer、Origin shows cached signed-in profile、Origin profile editor saves a page-local role。
- 本地用真实 Inter 渲染和设计稿并排比对，图在 `packages/camera-role-design-debug-20261106/`。
- 02:28 装机 14185577…83df，用户自己复核，发现详情也被限成 3 行，已改。我只打开过 App、切过推荐栏和 Me，没有进到编辑页。
- 待看：键盘联动、「」字形、亮背景上的描述气泡。当时 internal 版 Me 页显示未登录，原因未查。

## 不要提交

`genesis_app/pubspec.lock`、`genesis_app/analysis_options.yaml` 是沿用基线包的本地差异。
