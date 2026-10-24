# Me 进入设置并返回

现有账号下的页面导航、页面断言与截图留证

前提：使用手机上现有账号、当前安装 App 和已有数据；仅进行导航与页面检查，保留账号和缓存。不登录、不编辑资料、不发送内容、不购买、不清除数据；如缺少必要前提则报告阻塞。

1. 点击 Me 进入个人页面
   依据：当前页面树中存在唯一 description 为 Me 的入口；进入后再根据实际页面明确断言。
   断言：{"source":"foreground","target":{"kind":"text","value":"","x":0,"y":0},"property":"text","operator":"equals","expected":"com.worldo.ai","timeoutMs":1000,"sampleMs":500}

2. 从 Me 点击右上角设置齿轮
   依据：页面树未提供设置按钮的 id、text 或 description；截图中的齿轮位于右上角，属于授权导航范围。
   导航／操作，无独立通过判定

3. 重新断言 Settings 页面并留存截图
   依据：s4 的实际采样为 true，但最终判定失败，可能与页面树采集超过原 1 秒窗口有关；使用当前唯一标题重新核验，不改变业务预期。
   断言：{"source":"ui","target":{"kind":"description","value":"設定","x":0.5,"y":0.5},"property":"exists","operator":"equals","expected":"true","timeoutMs":15000,"sampleMs":1000}

4. 点击返回并检查 Me 页面显示
   依据：当前页面树存在唯一「返回」控件；按目标返回 Me，并显式检查 Me 入口。
   断言：{"source":"ui","target":{"kind":"description","value":"Me","x":0.5,"y":0.5},"property":"exists","operator":"equals","expected":"true","timeoutMs":15000,"sampleMs":1000}

5. 断言返回后 Me 个人页主体正常显示并截图
   依据：s6 已验证 Me 入口存在；进一步检查当前账号 UID，避免仅凭底部导航判断个人页已正常显示。
   断言：{"source":"ui","target":{"kind":"description","value":"UID: u_OEJET4","x":0.5,"y":0.5},"property":"exists","operator":"equals","expected":"true","timeoutMs":15000,"sampleMs":1000}

覆盖限制：
- 设置齿轮使用截图坐标定位，固化发布前需验证截图模板定位可靠性。
