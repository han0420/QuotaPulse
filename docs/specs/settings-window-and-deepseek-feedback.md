# 设置窗口与 DeepSeek 保存反馈回归

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

修复菜单栏应用打开设置窗口时未置前、DeepSeek 保存没有反馈，以及合法 curl 模板被错误拆分导致余额请求失败的问题。

## 非目标

- 不让设置窗口永久浮在其他应用之上。
- 不支持 shell 管道、重定向或任意 shell 执行。

## 用户行为

- 点击菜单中的设置后，QuotaPulse 被激活，设置窗口出现在当前桌面最前方。
- DeepSeek 保存时校验开关、API Key 和 curl 模板，显示成功或具体错误。
- 保存成功后立即刷新余额，无需等待下一轮定时刷新。

## 需求

- R1: 设置入口 MUST 激活应用并打开设置 Scene，设置窗口不能永久设置为 floating level。
- R2: curl 模板解析 MUST 保留单引号或双引号包裹参数中的空格。
- R3: DeepSeek 保存 MUST 显示本地化成功/失败状态。
- R4: 启用查询时 API Key 不能为空，模板必须能生成受限的 DeepSeek curl 命令。
- R5: 保存成功 MUST 请求 `QuotaStore` 立即刷新。

## 合法性与边界

关闭开关时允许保存配置；开启时必须同时具备 API Key、`<API_KEY>` 占位符和固定 DeepSeek balance URL。

## 验收场景

- A1 — Given 其他应用在前台，When 点击 QuotaPulse 设置，Then 设置窗口成为前台窗口。
- A2 — Given 官方 curl 模板，When 构造参数，Then Header 分别为单一参数 `Accept: application/json` 与 `Authorization: Bearer …`。
- A3 — Given 开关开启但 API Key 为空，When 保存，Then 显示缺少 API Key 且不保存。
- A4 — Given 有效配置，When 保存，Then 显示已保存并立即查询余额。

## 技术方案

新增纯策略 `DeepSeekSettingsValidation`；`SettingsView` 持有保存状态并接收共享 `QuotaStore`；菜单设置入口使用 `openSettings` 后激活 `NSApp`。curl tokenizer 只处理参数和引号，不调用 shell。

## 测试计划

XCTest 覆盖模板参数和保存校验；运行完整 `swift test`。设置置前和保存反馈进行编译与手动检查。

## 实现映射

- `Sources/QuotaPulse/App/QuotaPulseApp.swift`: 激活应用并置前设置窗口。
- `Sources/QuotaPulse/Services/DeepSeekBalanceClient.swift`: 引号感知参数解析与设置校验策略。
- `Sources/QuotaPulse/Views/SettingsView.swift`: 保存状态、校验和立即刷新。
- `Sources/QuotaPulse/Stores/QuotaStore.swift`: 可等待的 DeepSeek 单独刷新入口。
- `Tests/QuotaPulseTests/QuotaModelsTests.swift`: Header 参数与保存校验回归测试。

## 未决问题

无。`swift test` 39 项通过，`./script/build_and_run.sh --verify` 通过；设置窗口置前仍需从菜单进行人工交互确认。安全检查受仓库既有 `/Users/example/...` fixture 规则问题阻断。
