# 本机通知 HTTP API

- Status: Implemented
- Last updated: 2026-07-20
- Owners: project maintainers

## 背景与目标

允许其他本机程序通过 HTTP 请求触发 QuotaPulse 的 macOS 系统通知，并复用现有通知服务。

## 非目标

- 不监听局域网或公网地址。
- 不提供远程通知中转、账号系统或跨设备访问。
- 不支持定时通知、通知点击动作或附件。

## 用户行为

应用启动后在 loopback 地址启动 HTTP 服务。调用方使用本机端口和认证令牌发送 JSON 请求，成功后显示系统通知。端口和令牌通过应用日志以外的本机配置接口获取；本版本先提供固定端口和 UserDefaults 持久化令牌。

## 需求

- R1：服务 MUST 仅绑定 `127.0.0.1`。
- R2：服务 MUST 使用持久化的随机认证令牌，缺失时生成 32 字节随机值。
- R3：请求 MUST 是 `POST /v1/notifications`，并携带 `Authorization: Bearer <token>`。
- R4：请求 JSON MUST 包含非空 `title` 和 `body` 字符串，单字段最多 1,000 个字符。
- R5：成功请求 MUST 返回 HTTP 202，并调用 `QuotaNotificationService.send(title:body:)`。
- R6：认证失败返回 401，路径或方法不匹配返回 404/405，JSON 或字段非法返回 400。
- R7：请求体 MUST 限制在 16 KiB 以内；服务 MUST 不记录令牌、标题或正文。
- R8：应用退出时 MUST 停止监听。
- R9：服务 MUST 支持浏览器 CORS 预检，并返回 Private Network Access 所需的允许头；认证仍 MUST 生效。

## 验收场景

- A1：合法本机请求返回 202，并发送标题和正文。
- A2：缺失或错误令牌返回 401，且不发送通知。
- A3：非 POST 或错误路径返回对应 404/405。
- A4：空字段、超长字段、非法 JSON 或超大请求体返回 400。
- A5：服务只绑定 loopback，应用退出后端口停止监听。
- A6：Given 浏览器从安全上下文发起请求，When 发送 OPTIONS 预检，Then 返回 204 及 CORS/PNA 允许头，随后合法 POST 返回 202。

## 技术方案

`LocalNotificationHTTPAPI` 使用 `NWListener` 监听固定 loopback 端口；`LocalNotificationHTTPRequest` 负责纯请求解析和校验；通过注入的异步发送闭包调用 `QuotaNotificationService`。令牌使用 `UserDefaults` 保存，使用 `SecRandomCopyBytes` 生成。

## 测试计划

- 纯请求解析、认证、字段和大小边界测试。
- `swift test`、安全检查和应用构建验证。
- 手动用 curl 验证成功、401、400，并确认通知中心实际出现通知。

## 实现映射

`Sources/QuotaPulse/Services/LocalNotificationHTTPAPI.swift`、`Sources/QuotaPulse/App/QuotaPulseApp.swift`、`Sources/QuotaPulse/Views/SettingsView.swift`；解析和边界测试位于 `Tests/QuotaPulseTests/QuotaModelsTests.swift`。

## 未决问题

无。
