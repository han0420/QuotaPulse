# 运行时本地化

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

应用支持简体中文和英文即时切换，且不要求重启。

## 非目标

- 当前不支持更多语言或按 provider 单独选择语言。

## 需求

- R1：首次启动 MUST 根据系统首选语言选择简体中文或英文。
- R2：用户选择 MUST 保存到 `UserDefaults`，并在下次启动恢复。
- R3：悬浮窗快捷按钮和设置页 MUST 修改同一个共享 `LanguageSettings`。
- R4：切换 MUST 立即更新使用 `language.text` 的界面，不要求重启。
- R5：所有新增用户可见字符串 MUST 同时存在于 `en.lproj` 与 `zh-Hans.lproj`，并使用相同 key。
- R6：格式化字符串 MUST 使用当前语言 locale。
- R7：天气地点 MUST 优先使用当前语言对应名称；缺失时使用通用名称。

## 验收场景

- A1：Given 中文系统且无偏好，When 首次启动，Then 使用简体中文。
- A2：Given 用户切换英文，When 重新启动，Then 仍为英文。
- A3：Given 正在显示悬浮窗和设置页，When 切换语言，Then 两处同步更新。

## 技术方案、测试与映射

`LanguageSettings` 是 MainActor 可观察共享对象，按选择加载资源 bundle；资源位于 `Resources/en.lproj` 与 `zh-Hans.lproj`。已有提醒字段中文键测试；完整键一致性和实时 UI 切换目前依赖人工检查。

## 未决问题

无。
