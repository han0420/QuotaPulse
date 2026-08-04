# QuotaPulse 架构概览

## 产品边界

QuotaPulse 是 macOS 14+ 原生菜单栏应用，以 Swift 6 和 SwiftUI 构建。它读取本机已有的 Codex/Claude 登录状态，直接请求对应服务的额度信息，并在菜单栏、悬浮窗和系统通知中呈现。项目不包含中转服务器、账号系统、分析服务或远程配置。

## 运行时数据流

```text
Codex / Claude 本机凭据 ──▶ Provider 额度客户端 ─┐
                                                 │
DeepSeek API Key + curl 模板 ─▶ DeepSeekBalanceClient ─▶ QuotaStore ─▶ 菜单栏 + 悬浮窗
                                                 │             │
本机 HTTP 通知请求 ─▶ LocalNotificationHTTPAPI ─▶ QuotaNotificationService
本机活动检测 ────────────────────────────────────┤             ▼
天气与位置客户端 ────────────────────────────────┘   QuotaNotificationService
```

`QuotaStore` 是额度页面状态的单一汇聚点：并发刷新不同来源、合并 provider、维护可选 DeepSeek 余额、记录上次读数、判断是否跨越提醒阈值，再发布可观察状态。视图不应自行访问额度网络接口。

## 目录职责

| 路径 | 职责 |
| --- | --- |
| `Sources/QuotaPulse/App` | 应用生命周期、菜单栏入口、依赖装配 |
| `Sources/QuotaPulse/Models` | 可持久化配置、额度和天气领域模型 |
| `Sources/QuotaPulse/Services` | 网络、本机凭据、通知、位置、登录项和动作执行 |
| `Sources/QuotaPulse/Stores` | 刷新编排、数据合并、状态与提醒触发 |
| `Sources/QuotaPulse/Views` | SwiftUI 菜单栏、悬浮窗、设置界面 |
| `Sources/QuotaPulse/Support` | 格式化、主题、语言和窗口控制 |
| `Sources/QuotaPulse/Resources` | 本地化字符串和图片资源 |
| `Tests/QuotaPulseTests` | 模型、策略、解析与关键行为测试 |
| `script` | 构建、运行、安全检查、图标与发布脚本 |
| `skills` | 项目级 Codex UI 与构建安装工作流 |

## 关键组件

- `QuotaPulseApp` / `AppDelegate`：创建共享服务、store 和窗口控制器，启动刷新循环并恢复定时提醒。
- `SingleInstancePolicy`：为 AppDelegate 提供可测试的进程判定；应用包同时通过 Launch Services 声明禁止多实例。
- `AppConfigurationBackupService` / `ConfigurationBackupController`：分别负责版本化非敏感配置的白名单编解码，以及菜单栏系统文件面板交互。
- `QuotaStore`：每 60 秒发起刷新；优先采用 direct client 的成功结果；按 provider/周期跟踪额度变化；保存 DeepSeek 设置后支持立即刷新。
- `WeeklyQuotaPlanConfiguration` / `WeeklyQuotaBudget`：持久化周计划是否排除周末，并按真实额度周期与本地日历计算计划剩余额度；配置由 `QuotaStore` 共享给设置页和浮窗。
- `CodexDirectClient`、`ClaudeDirectClient`、`OpenUsageClient`：Codex/Claude 额度来源适配器。新增来源时应保持凭据只读和服务直连原则。
- `DeepSeekBalanceClient`：把受限 curl 模板解析为结构化 `/usr/bin/curl` 参数，执行余额请求并解析官方响应；不通过 shell。
- `QuotaNotificationConfiguration`：额度阈值提醒的配置、合法性、阈值生成与 `UserDefaults` 持久化。
- `QuotaNotificationService`：系统通知权限、额度通知发送、定时提醒调度和稍后提醒动作。
- `LocalNotificationHTTPAPI`：仅监听 `127.0.0.1` 的本机通知 HTTP 入口，校验 Bearer 令牌和 JSON 后复用通知服务。
- `SettingsView`：额度提醒、DeepSeek API 余额、定时提醒、语言和登录项设置入口；保存 DeepSeek 设置后触发 store 刷新。
- `LanguageSettings` 与 `*.lproj/Localizable.strings`：运行时中英文切换。新增用户可见文本必须同时提供英文和简体中文键值。

## 持久化与安全边界

- 当前应用身份为 `com.cmsjcm.QuotaPulse.v2`；它与历史 `com.cmsjcm.QuotaPulse` 通知容器完全隔离，禁止重新复用旧 bundle identity。
- 用户偏好使用 `UserDefaults` 的 `QuotaPulse.v2.*` namespace；只解码当前 schema，旧 schema 直接拒绝，不自动迁移。
- 经用户明确接受风险后，DeepSeek API Key 以明文保存在应用偏好中；不得写入日志。Codex/Claude 凭据不适用此例外。
- 不把 token、用户名、凭据文件、精确位置或完整本机路径写入日志、fixture、文档或提交。
- 配置备份只包含语言、提醒和非敏感功能设置，明确排除 provider 凭据、DeepSeek API Key 与本机通知 API token。
- 不通过 shell 拼接执行用户配置的动作；进程参数必须结构化传递。
- 新增网络端点、遥测、远程配置或凭据写入前，必须单独记录隐私与安全决策。

## 测试边界

领域规则应从 SwiftUI 和系统框架中抽离，使其可由 XCTest 直接验证。网络解析需要经过脱敏 fixture 或专门构造的数据测试；UI 改动至少保证 `swift test` 能完整编译应用 target。
