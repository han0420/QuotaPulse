# QuotaDot 架构概览

## 产品边界

QuotaDot 是 macOS 14+ 原生菜单栏应用，以 Swift 6 和 SwiftUI 构建。它读取本机已有的 Codex/Claude 登录状态，直接请求对应服务的额度信息，并在菜单栏、悬浮窗和系统通知中呈现。项目不包含中转服务器、账号系统、分析服务或远程配置。

## 运行时数据流

```text
Codex / Claude 本机凭据
          │
          ▼
Services 中的额度客户端 ──────┐
                              ▼
本机活动检测 ────────────▶ QuotaStore ───▶ 菜单栏 + 悬浮窗
                              │
天气与位置客户端 ──────────────┘
                              │
                              ▼
                   QuotaNotificationService
```

`QuotaStore` 是额度页面状态的单一汇聚点：并发刷新不同来源、合并 provider、记录上次读数、判断是否跨越提醒阈值，再发布可观察状态。视图不应自行访问额度网络接口。

## 目录职责

| 路径 | 职责 |
| --- | --- |
| `Sources/QuotaDot/App` | 应用生命周期、菜单栏入口、依赖装配 |
| `Sources/QuotaDot/Models` | 可持久化配置、额度和天气领域模型 |
| `Sources/QuotaDot/Services` | 网络、本机凭据、通知、位置、登录项和动作执行 |
| `Sources/QuotaDot/Stores` | 刷新编排、数据合并、状态与提醒触发 |
| `Sources/QuotaDot/Views` | SwiftUI 菜单栏、悬浮窗、设置界面 |
| `Sources/QuotaDot/Support` | 格式化、主题、语言和窗口控制 |
| `Sources/QuotaDot/Resources` | 本地化字符串和图片资源 |
| `Tests/QuotaDotTests` | 模型、策略、解析与关键行为测试 |
| `script` | 构建、运行、安全检查、图标与发布脚本 |

## 关键组件

- `QuotaDotApp` / `AppDelegate`：创建共享服务、store 和窗口控制器，启动刷新循环并恢复定时提醒。
- `QuotaStore`：每 60 秒发起刷新；优先采用 direct client 的成功结果；按 provider/周期跟踪额度变化。
- `CodexDirectClient`、`ClaudeDirectClient`、`OpenUsageClient`：额度来源适配器。新增来源时应保持凭据只读和服务直连原则。
- `QuotaNotificationConfiguration`：额度阈值提醒的配置、合法性、阈值生成与 `UserDefaults` 持久化。
- `QuotaNotificationService`：系统通知权限、额度通知发送、定时提醒调度和稍后提醒动作。
- `SettingsView`：额度提醒、定时提醒、语言和登录项设置入口。
- `LanguageSettings` 与 `*.lproj/Localizable.strings`：运行时中英文切换。新增用户可见文本必须同时提供英文和简体中文键值。

## 持久化与安全边界

- 用户偏好使用 `UserDefaults`；需要迁移时提供向后兼容默认值和测试。
- 不把 token、用户名、凭据文件、精确位置或完整本机路径写入日志、fixture、文档或提交。
- 不通过 shell 拼接执行用户配置的动作；进程参数必须结构化传递。
- 新增网络端点、遥测、远程配置或凭据写入前，必须单独记录隐私与安全决策。

## 测试边界

领域规则应从 SwiftUI 和系统框架中抽离，使其可由 XCTest 直接验证。网络解析需要经过脱敏 fixture 或专门构造的数据测试；UI 改动至少保证 `swift test` 能完整编译应用 target。
