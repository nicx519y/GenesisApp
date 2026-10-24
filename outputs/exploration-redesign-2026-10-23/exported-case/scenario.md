# Worldo 前台与无自动播放验收

现有账号和数据；前台包名及至少 5 秒系统音轨观察

前提：用户已授权本次验收截图交给 Codex 模型，使用现有账号与数据；不创建内容，不清空数据。

1. 检查前台包为 com.worldo.ai
   依据：用户要求显式验证前台包名，无需再次重启或导航。
   断言：{"source":"foreground","target":{"kind":"text","value":"","x":0,"y":0},"property":"text","operator":"equals","expected":"com.worldo.ai","timeoutMs":1000,"sampleMs":500}

2. 持续 5 秒检查系统音轨保持 none
   依据：验证观察窗口内没有自动播放；系统音轨状态不代表主观听感。
   断言：{"source":"audio","target":{"kind":"text","value":"","x":0,"y":0},"property":"text","operator":"stable","expected":"none","timeoutMs":5000,"sampleMs":500}

覆盖限制：

