# 仓库工作入口

- 本仓库 Flutter 工程在 `genesis_app/`。处理其中的代码、文档或测试前，读取 [工程指引](genesis_app/AGENTS.md)，按任务选择其中的专项文档入口。
- 涉及 MiniPhone 页面、手机网络接口、相关测试或 World 的手机接入时，再读取 [MiniPhone 指引](genesis_app/lib/pages/mini_phone/AGENTS.md)。目录外的相关文件仍遵循其所属目录指引；此链接是阅读入口，不扩大模块文件的目录作用范围。
- 从仓库根目录启动时，以上子目录文件需要按入口读取；不要假设启动时会自动注入所有子目录的 AGENTS.md。
