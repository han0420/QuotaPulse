# QuotaPulse 图标系统

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

现有应用图标与菜单栏图标使用不同的造型语言，且应用图标在 Dock 中辨识度不足。本次建立统一的 QuotaPulse 图标系统：以 Codex 类开发工具的简洁、柔和蓝紫视觉为参考，但使用原创的额度循环与脉冲节点图形，避免与第三方品牌标志混淆。

## 非目标

- 不复制 Codex 或其他第三方的商标图形。
- 不改变应用名称、bundle identifier、功能或数据。
- 不新增用户设置、动画或图标主题切换。

## 用户行为

- 用户在 Finder、Dock 和应用切换器中看到白色圆角底、蓝紫循环标志的 QuotaPulse 应用图标。
- 用户在菜单栏中看到同一循环与脉冲节点的单色简化图标；图标自动适配系统菜单栏的深浅外观。

## 需求

- R1：应用图标 MUST 使用原创的三段额度循环与独立脉冲圆点作为核心轮廓。
- R2：应用图标 MUST 使用白色圆角方形底和蓝紫色主体，并在 16、32、128、256、512、1024 像素表示中保持可识别。
- R3：应用图标资源 MUST 提供 1024×1024 PNG 与完整 macOS ICNS。
- R4：菜单栏图标 MUST 使用与应用图标一致的三段循环和脉冲圆点，但 MUST 作为 macOS template image 渲染。
- R5：资源生成脚本 MUST 从受版本控制的母版生成 PNG/ICNS，且不得恢复旧图标设计。
- R6：图标外部角落 MUST 保持透明，应用包 MUST 继续引用 `AppIcon.icns`。

## 合法性与边界

- 图标仅参考第三方产品常见的柔和蓝紫材质与 macOS 圆角图标布局，不复用第三方标志的具体路径、终端符号或字形。
- imagegen 生成的原始母版保存在项目中；发布资源通过 chroma-key 去除和标准尺寸缩放生成。
- 菜单栏图标不使用彩色位图，以符合 macOS 状态栏可访问性与外观切换规则。

## 验收场景

- A1：Given 新资源，When 检查 `AppIcon.png`，Then 尺寸为 1024×1024 且四角透明。
- A2：Given 图标生成脚本，When 执行脚本，Then 生成有效的 `AppIcon.png` 和 `AppIcon.icns`。
- A3：Given 系统处于浅色或深色菜单栏，When QuotaPulse 运行，Then 菜单栏图标随系统前景色渲染且轮廓清晰。
- A4：Given 16px 与 32px 图标预览，When 与 Dock 大图标比较，Then 均能辨认出循环缺口和脉冲圆点。
- A5：Given 组装后的应用，When 读取 `Info.plist` 并验证签名，Then图标仍指向 `AppIcon` 且应用包通过签名检查。

## 技术方案

- `script/assets/QuotaPulse-AppIcon-Source.png` 保存 imagegen 输出的原始母版。
- `script/generate_app_icon.swift` 读取已移除纯色外部背景的母版，生成发布 PNG，并将标准尺寸 PNG 表示写入 ICNS 容器。
- `MenuBarQuotaGlyph` 使用 AppKit 路径绘制三段圆弧与脉冲圆点，并标记为 template image。

## 测试计划

- 自动验证 PNG 尺寸、alpha 通道与透明角。
- 执行图标生成脚本，并使用系统 `iconutil` 反向解包验证 ICNS 可读。
- 运行 `swift test`、`./script/security_check.sh` 与 `./script/build_and_run.sh --verify`。
- 手动查看 16px、32px 和 1024px 图标；在深浅菜单栏各检查一次模板渲染。

## 实现映射

| 规格 | 实现/验证 |
| --- | --- |
| R1–R3、R6 | `script/assets/QuotaPulse-AppIcon-Master.png`、`Sources/QuotaPulse/Resources/AppIcon.png`、`Sources/QuotaPulse/Resources/AppIcon.icns` |
| R4 | `Sources/QuotaPulse/Views/MenuBarQuotaGlyph.swift` |
| R5 | `script/generate_app_icon.swift` |
| A1 | `Tests/QuotaPulseTests/BrandIconAssetTests.swift` |
| A2、A5 | `script/generate_app_icon.swift`、`iconutil --convert iconset`、`codesign --verify` |
| A3–A4 | 1024px 与 32px 资产人工预览；深浅菜单栏实机切换仍需人工确认 |

## 未决问题

无。`swift test` 41 项通过，`./script/build_and_run.sh --verify` 通过，生成的 ICNS 可由系统 `iconutil` 反向解包。当时安全检查受仓库既有个人主目录格式 fixture 阻断，该 fixture 已于 2026-07-30 修正。
