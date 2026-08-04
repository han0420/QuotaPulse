# 单实例运行与配置备份

- Status: Accepted
- Last updated: 2026-08-04
- Owners: project maintainers

## 背景与目标

QuotaPulse 的菜单栏、悬浮窗、刷新循环和通知服务均为全局能力，同时运行多个实例没有产品价值，还会造成重复刷新、重复通知和多个悬浮窗。本次改动限制应用为单实例，并在菜单栏菜单提供配置导入、导出入口，方便迁移和备份非敏感设置。

## 非目标

- 不导出 Codex、Claude 登录会话、Keychain 内容或任何 provider 凭据。
- 不导出 DeepSeek API Key、本机通知 API Bearer token、天气缓存、额度读数或运行时状态。
- 不提供云同步、自动备份、备份加密或跨设备凭据迁移。
- 不合并两份配置；导入的已知字段覆盖当前对应设置。

## 用户行为

- 正常启动 QuotaPulse 时，若已有实例运行，新启动的实例激活已有实例后退出，不再创建另一套菜单栏、窗口和后台服务。
- 菜单栏菜单在“设置…”下方显示“导出配置…”和“导入配置…”。
- 导出使用系统保存面板生成带版本号的 JSON 文件。
- 导入使用系统打开面板选择 JSON 文件；成功后立即应用语言、额度提醒、DeepSeek 展示设置和定时提醒，并刷新额度；失败时显示本地化错误提示且不改动现有配置。

## 需求

- R1: 组装后的应用包 MUST 声明禁止多个实例。
- R2: 应用启动时 MUST 检测相同 bundle identifier 的其他运行中实例；发现既有实例时 MUST 激活它并终止当前实例，且 MUST NOT 启动刷新、HTTP 监听、提醒恢复或悬浮窗。
- R3: 菜单栏菜单 MUST 提供本地化的导入、导出入口。
- R4: 备份 MUST 使用 UTF-8 JSON，包含格式版本与明确字段，不得序列化整个偏好域。
- R5: 备份 MUST 包含应用语言、额度提醒配置、DeepSeek 非敏感配置和定时提醒。
- R6: 备份 MUST NOT 包含 DeepSeek API Key、本机通知 API token、Codex/Claude 凭据或其他未列入白名单的数据。
- R7: 导入 MUST 先完整解码并验证版本及字段，再执行任何写入；无效文件 MUST NOT 造成部分写入。
- R8: 导入成功后 MUST 更新当前语言、重新同步定时提醒并触发额度刷新。
- R9: 导入/导出结果 MUST 使用当前语言给出成功或失败反馈。

## 合法性与边界

- 当前格式版本为 `2`；其他版本全部拒绝导入，不提供迁移。
- 额度提醒配置必须通过现有 `isValid` 校验；提醒配置使用现有 Codable 结构校验。
- 文件取消选择不是错误，不显示失败提示。
- 导入采用整体校验、随后逐项持久化；仅写入 R5 所列偏好。
- 单实例运行时检测以非当前 PID 的同 bundle identifier 进程为既有实例；若 bundle identifier 不可用，则依赖应用包声明。

## 验收场景

- A1 — Given 一个 QuotaPulse 已运行，When 再次打开应用，Then 既有实例被激活且第二个实例在创建后台服务前退出。
- A2 — Given 组装后的 `QuotaPulse.app`，When 检查 `Info.plist`，Then `LSMultipleInstancesProhibited` 为 `true`。
- A3 — Given 已保存四类非敏感配置，When 导出再导入至空偏好域，Then这些配置完整往返。
- A4 — Given UserDefaults 同时含 API Key 和本机 token，When 导出，Then JSON 中不出现这些键和值。
- A5 — Given 不支持版本、损坏 JSON 或无效额度配置，When 导入，Then返回失败且偏好域保持不变。
- A6 — Given 用户取消打开或保存面板，When 操作结束，Then应用保持原状态且不报错。
- A7 — Given 中文或英文界面，When 打开菜单或操作完成，Then菜单项和反馈使用当前语言。

## 技术方案

`SingleInstancePolicy` 提供可单测的 PID 判定；`AppDelegate` 在 `applicationDidFinishLaunching` 的第一步查询 `NSRunningApplication`，必要时激活既有实例并退出。`script/assemble_app.sh` 同时写入 Launch Services 单实例声明。

`AppConfigurationBackup` 是版本化 Codable 文档，引用现有配置模型；`AppConfigurationBackupService` 只读取和写入四个白名单配置，并把误写进 curl 模板的当前 DeepSeek API Key 替换为 `<API_KEY>`。`ConfigurationBackupController` 负责 AppKit 文件面板和错误提示，菜单视图仅发送用户意图。成功导入后由应用层更新共享语言、同步提醒并刷新 store。

安全影响：备份明确排除凭据和本机 API token；不新增网络、遥测或后端。

## 测试计划

- 单元测试单实例 PID 判定，包括仅当前进程、存在其他进程和重复列表。
- 单元测试备份往返、秘密排除、不支持版本/损坏数据/无效配置的原子失败。
- `swift test`。
- `./script/security_check.sh`。
- `./script/build_and_run.sh --verify`，并检查组装后 plist。
- 手动：连续打开应用两次，确认仅一个菜单栏项和进程；分别在中英文下导出、导入与取消面板，确认反馈和实时应用。

## 实现映射

- R1：`script/assemble_app.sh` 写入 `LSMultipleInstancesProhibited`。
- R2：`Sources/QuotaPulse/Support/SingleInstancePolicy.swift`、`Sources/QuotaPulse/App/QuotaPulseApp.swift`。
- R3、R8、R9：`Sources/QuotaPulse/App/QuotaPulseApp.swift`、`Sources/QuotaPulse/Support/ConfigurationBackupController.swift`、两份 `Localizable.strings`。
- R4–R7：`Sources/QuotaPulse/Models/AppConfigurationBackup.swift`。
- 自动化测试：`Tests/QuotaPulseTests/QuotaModelsTests.swift`。

验证记录（2026-07-20）：`swift test` 51 项通过；中英文 key 集合一致，`git diff --check` 通过。ad-hoc 调试应用完成组装、严格签名校验和 `/Applications/QuotaPulse.app` 安装；安装包的 `LSMultipleInstancesProhibited` 为 `true`，连续再次打开后进程数仍为 1。`security_check.sh` 被仓库既有的通用示例用户路径测试 fixture 规则拦截，因此 spec 暂保持 `Accepted`；导入、导出文件面板及双语反馈仍需人工交互确认。

## 未决问题

无。采用安全默认：备份只包含非敏感配置，不包含任何令牌或 API Key。
