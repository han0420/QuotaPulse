# QuotaPulse 品牌身份

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

产品名称、代码标识、应用身份和工程目录统一使用 `QuotaPulse`，准确表达实时额度、活动状态与提醒能力，并消除品牌命名分裂。

## 非目标

- 不改变现有功能、用户数据或视觉图标。
- 不提供旧偏好 key 或旧通知 identifier 的兼容迁移。

## 需求

- R1：应用显示名、应用包名和可执行文件名 MUST 为 `QuotaPulse`。
- R2：SwiftPM package、executable product 和主 target MUST 使用 `QuotaPulse`；测试 target MUST 使用 `QuotaPulseTests`。
- R3：英文副标题 MUST 为 `A private, native quota, activity, and alert companion for Codex and Claude on macOS.`。
- R4：中文定位 MUST 为“Codex 与 Claude 的本地额度、活动状态与提醒伴侣”。
- R5：菜单、通知、登录启动说明、安装文档、发布文档、隐私和贡献文档中的用户可见旧名称 MUST 更新为 `QuotaPulse`。
- R6：bundle identifier、OSLog subsystem、通知 identifier、通知 action identifier 和所有偏好 key MUST 统一使用 `QuotaPulse` 命名空间。
- R7：构建脚本 MUST 产出 `QuotaPulse.app`，且资源 bundle 能被运行时正确定位。
- R8：源码目录、测试目录、应用入口文件和文档路径 MUST 统一使用 `QuotaPulse`。
- R9：受版本控制的源码、测试、脚本和文档中 MUST 不再出现任何旧品牌名称。

## 验收场景

- A1：Given 当前源码，When 执行 `swift test`，Then `QuotaPulse` target 编译且全部现有测试通过。
- A2：Given 本机构建，When 组装应用，Then 生成 `QuotaPulse.app/Contents/MacOS/QuotaPulse` 并通过签名验证。
- A3：Given 安装 QuotaPulse，When macOS 读取应用身份，Then bundle ID 为 `com.cmsjcm.QuotaPulse`。
- A4：Given 用户查看 README 或应用文案，When 读取产品定位，Then 看到新名称和更新后的额度/活动/提醒副标题。

## 技术方案

`AppBrand` 作为代码内品牌与应用身份的单一来源；源码和测试目录同步改名。构建脚本、通知、偏好和日志全部采用同一命名空间，不添加旧 key 迁移。

## 测试计划

- 品牌常量单元测试。
- 全仓库旧名称零匹配检查。
- 完整 `swift test`。
- 组装应用并检查 plist、可执行路径和 codesign。
- 手动检查菜单退出项、定时提醒标题、设置登录项说明和 README 首页。

## 实现映射

| 规格 | 实现/验证 |
| --- | --- |
| R1–R4 | `Sources/QuotaPulse/Support/AppBrand.swift`、`Package.swift`、`README.md` |
| R5 | `Sources/QuotaPulse/Resources/*.lproj/Localizable.strings`、根目录及 `docs/` 文档 |
| R6 | `Sources/QuotaPulse/Models`、`Sources/QuotaPulse/Services`、`Sources/QuotaPulse/Stores`、构建脚本 |
| R7–R8 | `script/`、`Sources/QuotaPulse`、`Tests/QuotaPulseTests` |
| R9 | 全仓库大小写不敏感旧名称零匹配检查 |
| A1–A4 | `Tests/QuotaPulseTests/QuotaModelsTests.swift`、`swift test`、本机 app 组装与 plist/codesign 检查 |

## 未决问题

仓库托管平台上的远端仓库重命名需在平台侧独立完成。
