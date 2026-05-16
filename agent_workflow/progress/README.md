# 长任务 Checkpoint

这个目录保存长任务的可恢复上下文。它解决的问题是：当 agent 上下文过长、发生压缩、换 agent、OMX worker 中断或需要隔天继续时，新的执行者可以通过文件恢复任务状态，而不是依赖聊天记录。

每个 feature 一个目录：

```text
agent_workflow/progress/<feature>/
  checkpoint.md
```

`checkpoint.md` 是该任务的当前状态源。任何长任务在以下时机必须更新：

- 完成一个阶段后。
- 开始 coding 前。
- 测试失败或遇到 blocker 时。
- 交给另一个 agent 前。
- 上下文可能不足或即将压缩前。
- 最终完成前。

常用命令：

```bash
bash agent_workflow/scripts/init_checkpoint.sh <feature>
bash agent_workflow/scripts/update_checkpoint.sh <feature> --stage "..." --done "..." --next "..."
bash agent_workflow/scripts/show_checkpoint.sh <feature>
```
