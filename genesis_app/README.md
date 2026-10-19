# Worldo Flutter 客户端

本目录是 GenesisApp / Worldo 的 Flutter 主工程。完整的环境准备、运行参数、服务环境、主要功能模块和构建说明统一维护在 [仓库 README](../README.md)。

已完成环境与签名配置后，在本目录执行：

```sh
flutter pub get
flutter devices
flutter run --debug --flavor production -d <device-id>
```

将 `<device-id>` 替换为实际设备 ID。当前锁定依赖要求 Flutter ≥ 3.44.0、Dart ≥ 3.12.0 且 < 4.0.0；Debug / Profile 默认使用 dev 服务，Release 默认使用生产服务，Developer 面板保存的地址覆盖优先。`production` 是包类型，不代表强制连接生产环境。

开始修改前阅读 [工程指引](AGENTS.md)；涉及 MiniPhone 时继续阅读 [MiniPhone 指引](lib/pages/mini_phone/AGENTS.md)。
