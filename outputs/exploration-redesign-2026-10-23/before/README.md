# GenesisApp Local Automation Test Console

This standalone repository is the source of truth for manually maintained
semantic QA cases, generated test scripts, local Git comparisons, and test
reports for GenesisApp. The tested Flutter project remains in a separate
GenesisApp checkout. The browser console uses Next.js App Router and Chakra UI,
while Fastify remains the local-only automation API. Saving a case never runs a test. Case processing and execution require an explicit action.

## Quick start

```bash
cd /Users/you/Works/GenesisAppAutomationTest
nvm use
npm install
npm run dev
```

Use Node.js 22 LTS (the pinned version is in `.nvmrc`). Open
`http://127.0.0.1:4318` in development. The Fastify API listens on
`127.0.0.1:4317`; Next.js proxies same-origin `/api` requests to that service.

By default, the system resolves the Flutter project from the sibling path
`../GenesisApp/genesis_app`. If your checkout is elsewhere, export
`GENESIS_APP_ROOT` before starting the console (the available variables are
documented in `.env.example`). The Flutter harness has the same sibling-path
default, but the service materializes an ignored `.genesis_app` symlink before
each host run so the harness and report always target the configured checkout.
The configured path is the Flutter project directory.

To run the production builds locally:

```bash
npm run build
npm start
```

The production console remains on `127.0.0.1:4318` and the API remains on
`127.0.0.1:4317`.

Useful manual commands:

```bash
npm run qa -- health
npm run qa -- cases
npm run qa -- compare --left HEAD --right working
npm run qa -- run --case ME-002 --level widget --platform host --environment mock
```

Android Appium setup is explicit and is never performed when the service starts:

```bash
npm run drivers:install:android
npm run drivers:status
```

Every operation is explicit. Starting the service, editing/saving a Case, or
fetching Git refs never starts Case processing or a test run.
Fetch uses `GENESIS_QA_GIT_REMOTE` (default `origin`) and returns an actionable
error when that remote has not been configured; it never creates a remote.

## Case authoring flow

Use Cases to create and edit business scenarios, review the V3 checkpoint plan,
and process the complete Case. The plan and any proposed implementation require
review before publishing. Run executes existing test assets; Reports records
the resulting evidence. Saving or confirming a Case does not start a test run.

Existing generated device scripts declare their App-hook file
dependencies (path and expected SHA-256) in `generated/manifest.json`; an empty
list explicitly means no patch is required. The Run page and the service both check
these dependencies before building. Missing/changed hooks block the whole
selected device run with an actionable message. Historical device entries
without a dependency declaration remain blocked by preflight;
host-level and legacy Flutter tests remain available. A finished run job only
means that a report was written, not that the test passed.

Case forms contain business identity and write-risk information; technical
parameters are selected afresh on each RUN. A RUN chooses one client
environment (code test or installed App), one platform (`host` for code tests,
Android or iOS for device tests), and one data environment (`mock` or `real`).
Code RUNs automatically execute the selected Cases' available generated Unit,
Widget, and Golden scripts together; the user does not select a test method.
If a selected Case has no current code script, preflight blocks the whole RUN.
Real-data RUNs require a reviewed HTTPS API origin supplied on the RUN page;
the service blocks a missing or unsafe origin before building. Historical Case
YAML technical fields remain readable for compatibility but
do not constrain RUN choices. A device RUN still needs an approved script for
the selected environment; selecting iOS does not imply its runner is ready.
Android device runs build the `internal` flavor; the per-RUN real-data origin
is passed to App API, gateway, and chatroom endpoints.
The known production API host is rejected for ordinary real-data runs.
`internal` may expose a different
provider set than a public flavor. Reports identify the local App commit,
uncommitted changes, build flavor, data environment, real-data origin when used,
and built APK hash. They do
not imply that the local App matches any remote branch.

## Safety boundaries

- Cases and generated scripts are Git-managed files in this repository. The console never commits, switches branches, or pushes.
- Git comparison uses object reads (`git show`/`git ls-tree`) and never checks out historical refs.
- Case processing verifies candidates before review; App changes require separate review.
- Real payments and account deletion are permanently blocked. Production execution additionally requires `GENESIS_QA_ALLOW_PROD=1` and an explicit confirmation phrase.
- Runtime jobs, reports, credentials, screenshots, build output, and local package caches are ignored by Git.
- Job results are recursively redacted before they are stored, returned by the API, or emitted over SSE.

## Test layers

- `runners/flutter_harness`: independent Flutter unit, widget, and golden package with a path dependency on the external GenesisApp checkout.
- `runners/appium`: WebdriverIO specs for Android UiAutomator2 and the iOS XCUITest scaffold.
- `runners/maestro`: compatibility smoke flows only.
- Existing tests under `$GENESIS_APP_ROOT/test` are discovered as a legacy suite and are not copied into this repository.
- Host runs emit a redacted execution log and JUnit XML. Widget/device screenshot evidence and golden-run golden evidence are mandatory when declared by the Case; a missing required artifact changes the report to `failed`.

## Case revision contract

- IDs cannot be renamed; use Copy to create a new permanent ID.
- A business expectation change must increase `revision` by exactly one.
- Driver/locator/test refactors only update generated artifacts and do not change Case revision.
- Both `real_payment` and `delete_account` must remain in every Case's forbidden actions.


## Bug List 与连续验证

控制台的 **Bug List** 管理 App 功能问题，**Issues / 平台问题与修复** 管理测试框架、执行器、证据和清理故障。有效业务失败需要本次运行身份、独立断言观测及成功清理；前提不满足和设备不可用分别展示，不触发 App 业务代码自动修复。

- 功能 Bug：待修复 → 人工标记已修复 → 待复测。标记只保存时间、说明和可选目标构建 SHA-256 / 源码指纹，不启动运行。
- 只有标记之后启动的完整 Case，在相同业务断言和环境下通过、实际构建与目标源码一致且清理成功，才自动关闭。再次失败重新打开；设备故障、跳过和中断保留处理状态并记为复测受阻。
- Bug 详情保留复现步骤、预期/实际结果、每次原报告与附件、版本身份、人工处理及复测历史。展示文案和 App 版本变化不单独创建重复 Bug；业务预期变化不能用于关闭原 Bug。
- 首次建设发现 Bug 会保留候选。人工修复后重新处理原 Case，继续使用保留候选；无需先发布失败实现。
- **批量验证** 固定所选方案版本与环境，复用完整 Case 队列。已发布方案走回归，其他已确认方案走建设验证；未确认方案单独等待。
- 功能 Bug 或前提失败在清理成功后继续其他 Case。资源故障等待；执行中断且清理不明时保留资源隔离。服务重启只恢复进程与资源已核对的任务，用户主动停止不自动恢复。
- 批次记录区分通过、功能 Bug、前提未满足、平台受阻、等待资源和未执行；“批次结束”不代表全部通过。

本地接口：

| 接口 | 用途 |
| --- | --- |
| `GET /api/bugs`、`GET /api/bugs/:id` | 搜索、筛选及详情 |
| `POST /api/bugs/:id/mark-fixed` | 人工标记；传 `revision`、唯一 `requestId`、`note` 和可选 `version` |
| `GET /api/bugs/events/stream` | 列表更新事件 |
| `POST /api/bugs/import-history` | 幂等导入证据完整的历史失败；保留原报告，不推断当前仍失败或已经修复 |
| `GET/POST /api/case-batches` | 持久化批次查询与提交 |
| `GET /api/case-batches/options` | 当前可选方案及已有环境元数据；不扫描历史候选源码 |
| `POST /api/case-batches/:id/stop`、`.../resume` | 版本校验后的停止与安全恢复 |
| `GET /api/checkpoint-plans/:id/workflow?profile=device:android:mock` | 当前方案、环境、运行的统一状态与实际阶段耗时 |
| `GET /api/qa-metrics?batchId=...` | 能力新增/复用、构建、阶段耗时、重复平台问题与无进展修复轮次 |

Bug、批次和结果分别持久化于 `.runtime/bugs`、`.runtime/batches`、`.runtime/checkpoints/outcomes`。缺失的历史性能数据保留为空；无进展统计来自独立修复未新增通过证据的轮次，不把重复日志算作进展。平台不提供人工强制“验证通过”或直接关闭 Bug 的接口。


## 分支与测试轮次

控制台围绕当前 App 分支和测试轮次组织：本轮概览、Cases、Bug List、Reports；分支 Case 库、QA 埋点库、测试历史；平台 Issues 与设置。分支资产物理隔离，显式继承后独立维护。创建轮次不会启动测试，同一轮可以覆盖修复前后的多个提交，每次运行固定实际版本。

完整数据关系、接口与迁移说明见 [分支与测试轮次](docs/branch-round-workspaces.md)。持久数据根目录继续支持 `GENESIS_QA_DATA_ROOT`。
