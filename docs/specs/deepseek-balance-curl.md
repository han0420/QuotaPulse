# DeepSeek 余额与 curl 动作

- Status: Implemented
- Last updated: 2026-07-21
- Owners: project maintainers

## 背景与目标

允许用户在面板底部查看 DeepSeek API 余额，并允许每日提醒通知点击后执行固定的余额 curl 请求。

## 非目标

- 不支持任意 shell 命令或 shell 管道。
- 不新增服务端中转、遥测或账户登录。
- 本次只解析 DeepSeek `/user/balance` 响应。

## 用户行为

- 设置中新增“查询 AI API Key 额度”开关，默认关闭。
- 开启后用户可配置 API Key 和 curl 模板；模板中的 `<API_KEY>` 由应用安全替换。
- API Key 输入框默认遮罩显示，用户可用眼睛按钮临时切换为明文查看。
- 开关开启且模板/API Key 有效时，面板最下方显示各币种 `total_balance`；失败时显示本地化错误状态。
- 通知点击执行固定的 DeepSeek 余额 curl 请求。

## 需求

- R1: 配置默认关闭，并可持久化开关与模板。
- R2: 经用户接受明文风险后，API Key 必须保存到应用的 `UserDefaults` 偏好域，不写入日志或通知内容，也不得访问 macOS Keychain。
- R3: curl 通过 `/usr/bin/curl` 和结构化参数执行，不能把用户模板拼接进 shell。
- R4: 解析 `is_available` 与 `balance_infos[].currency/total_balance`。
- R5: 网络刷新不阻塞现有额度刷新。
- R6: API Key 输入默认 MUST 使用遮罩显示，并提供一个可切换的明文查看控件；切换只影响当前设置窗口的可见性，不改变已保存内容。

## 合法性与边界

模板必须是 curl 命令，且包含 `<API_KEY>` 占位符；仅支持 `-L`、`-X`、`-H` 等参数的结构化解析。API Key 为空或响应非法时不展示余额。

从钥匙串存储切换到明文偏好时不自动迁移旧 Key，避免升级后的首次启动仍触发钥匙串授权；用户需要重新输入并保存一次。

## 验收场景

- A1 — Given 默认安装，When 打开设置，Then 开关关闭且不执行 DeepSeek 请求。
- A2 — Given 有效配置和官方示例响应，When 刷新，Then 面板底部显示 `CNY 110.00`。
- A3 — Given 通知点击，When 处理响应，Then 执行固定 DeepSeek curl 动作且不执行通知中传入的命令。
- A4 — Given 非法响应，When 刷新，Then 保留其他额度并显示 DeepSeek 查询失败状态。
- A5 — Given 新安装或升级，When 加载或保存 API Key，Then 只访问指定的 `UserDefaults`，不访问 Keychain。
- A6 — Given DeepSeek 设置页，When 用户点击眼睛按钮，Then API Key 在遮罩与明文之间切换且保存内容不变。

## 技术方案

新增 `DeepSeekBalanceClient`、`DeepSeekBalanceModels` 和 `DeepSeekBalanceConfiguration`。`QuotaStore` 协调刷新，`FloatingQuotaView` 仅渲染状态，`SettingsView` 编辑配置。通知动作新增 `.deepSeekBalance`。

## 测试计划

解析、配置默认值/往返、curl 参数构造和固定通知动作使用 XCTest；运行 `swift test` 与 `./script/security_check.sh`。

## 实现映射

- Implemented: `Sources/QuotaPulse/Services/DeepSeekBalanceClient.swift`, `Sources/QuotaPulse/Models/DeepSeekBalanceConfiguration.swift`, `Sources/QuotaPulse/Models/DailyReminderConfiguration.swift`, `Sources/QuotaPulse/Views/FloatingQuotaView.swift`, `Sources/QuotaPulse/Views/SettingsView.swift`, `Sources/QuotaPulse/Stores/QuotaStore.swift`, `Sources/QuotaPulse/Services/ReminderActionExecutor.swift`; tests in `Tests/QuotaPulseTests/QuotaModelsTests.swift`。

## 未决问题

无。API Key 明文偏好存储与 curl Header 参数已验证；`swift test` 40 项通过。当时安全检查受仓库既有个人主目录格式 fixture 阻断，该 fixture 已于 2026-07-30 修正。
