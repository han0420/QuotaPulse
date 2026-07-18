# QuotaPulse 文档地图

本文档目录是 QuotaPulse 的工程知识入口。安装和发布面向使用者与维护者；架构和规格文档面向开发者及 AI 编码代理。

## 从哪里开始

| 目标 | 文档 |
| --- | --- |
| 了解系统边界和代码职责 | [ARCHITECTURE.md](ARCHITECTURE.md) |
| 开发或修改功能 | [SPEC_WORKFLOW.md](SPEC_WORKFLOW.md) |
| 查看已有功能规格 | [specs/](specs/) |
| 本地安装 | [INSTALL.md](INSTALL.md) |
| 签名、 notarization 与发布 | [RELEASING.md](RELEASING.md) |

根目录的 [`AGENTS.md`](../AGENTS.md) 是 AI 代理的第一入口，包含项目地图、命令、安全边界和强制 spec-first 流程。

## 已实现功能规格

| 模块 | Spec |
| --- | --- |
| Codex/Claude 额度获取与合并 | [specs/provider-quota-data.md](specs/provider-quota-data.md) |
| 悬浮窗与菜单栏呈现 | [specs/floating-window.md](specs/floating-window.md) |
| 可配置额度阈值提醒 | [specs/quota-notification.md](specs/quota-notification.md) |
| 定时提醒与点击动作 | [specs/scheduled-reminders.md](specs/scheduled-reminders.md) |
| 天气背景与定位 | [specs/weather-background.md](specs/weather-background.md) |
| 本机活动检测 | [specs/local-activity-detection.md](specs/local-activity-detection.md) |
| 运行时中英文本地化 | [specs/localization.md](specs/localization.md) |
| 登录后自动启动 | [specs/launch-at-login.md](specs/launch-at-login.md) |
| 凭据与隐私边界 | [specs/credential-and-privacy.md](specs/credential-and-privacy.md) |
| 品牌名称与兼容迁移 | [specs/brand-identity.md](specs/brand-identity.md) |

## 文档维护原则

- 行为变化必须同步更新对应 spec；没有 spec 的新功能先创建 spec。
- 架构职责或数据流变化必须更新 `ARCHITECTURE.md` 和 `AGENTS.md` 中受影响的地图。
- 用户可见功能变化应同步更新根目录 `README.md`。
- 安装、权限、隐私或发布流程变化必须同步更新相关专项文档。
- 文档中的命令应在仓库根目录可直接运行。
