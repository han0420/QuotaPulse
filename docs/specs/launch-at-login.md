# 登录后自动启动

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

用户可以通过设置控制 QuotaDot 是否随 macOS 登录启动，并理解系统待批准状态。

## 非目标

- 不绕过 macOS 登录项审批，不安装额外 helper daemon。

## 需求

- R1：功能 MUST 使用 `SMAppService.mainApp` 注册或注销主应用登录项。
- R2：设置 MUST 显示 enabled、disabled、requires approval 和未知状态的本地化文本。
- R3：`requiresApproval` MUST 视为用户已请求启用，并提供打开系统登录项设置的入口。
- R4：应用进入 active scene 时 MUST 刷新系统状态。
- R5：注册/注销失败 MUST 显示错误，且随后重新读取系统真实状态。
- R6：重复启用或禁用 MUST 是安全的幂等操作。

## 验收场景

- A1：Given 未注册，When 用户开启，Then 调用注册并刷新状态。
- A2：Given 系统要求批准，When 显示设置，Then toggle 保持开启并提供系统设置按钮。
- A3：Given 操作失败，When 返回设置，Then 显示错误且不伪造成功状态。

## 技术方案、测试与映射

`LoginItemManager` 封装 `SMAppService` 状态与操作，`SettingsView` 绑定 toggle、状态和审批入口。该功能依赖 macOS 系统服务，主要通过手动检查启用、审批、重启登录和卸载流程验证。

## 未决问题

无。
