# 悬浮窗与菜单栏

- Status: Implemented
- Last updated: 2026-07-21
- Owners: project maintainers

## 背景与目标

用户应能以低干扰方式持续看到最低剩余额度，并在需要时展开查看各 provider 详情。

## 非目标

- 不提供任意窗口尺寸、固定展开或自定义主题。
- 不在 Dock 中显示普通应用窗口。

## 用户行为与需求

- R1：应用 MUST 以菜单栏应用运行，不在 Dock 中显示。
- R2：菜单栏 MUST 显示双环图标和所有可见额度窗口中的最低剩余比例。
- R3：悬浮窗 MUST 位于屏幕右上区域、浮于普通窗口之上、可跨 Space 并可拖动。
- R4：紧凑态 MUST 按 provider 显示独立 badge；provider 数量变化时调整宽度。
- R5：指针进入窗口附近或点击紧凑态时 MUST 展开；离开后 MUST 折叠。
- R6：展开态 MUST 为每个 provider 显示可用额度周期、重置、套餐和活动状态。
- R7：额度健康 MUST 取所有可见周期最低值：大于 50% 健康，10%～50% 警告，10% 及以下危急。
- R8：各额度环 MUST 独立按自身剩余比例着色，而不是共享最低健康色。
- R9：provider 无数据时 MUST 提供加载或错误状态，而非崩溃或空白窗口。
- R10：用户按住主鼠标键拖动悬浮窗时，窗口 MUST 保持拖动开始时的紧凑/展开状态；松开后 MUST 立即根据指针位置恢复 hover 判定。
- R11：菜单栏右键菜单的“显示额度窗口”MUST 将悬浮窗展开并恢复到主屏幕可见区域右上角的默认安全位置，不能仅将当前 frame 置前。
- R12：用户松开拖动后的悬浮窗若未在任一屏幕可见区域保留至少 32×32pt 的可抓取部分，MUST 自动回弹至主屏幕右上默认位置。

## 验收场景

- A1：Given 两个 provider，When 窗口折叠，Then 显示两个独立 badge。
- A2：Given 指针进入紧凑窗体，When hover 被检测，Then 展开且右上锚点保持稳定。
- A3：Given Session 60%、Weekly 8%，When 渲染，Then菜单栏显示 8%，两个环分别使用其自身颜色。
- A4：Given provider 数量变化，When 紧凑态同步，Then 窗口宽度随数量变化。
- A5：Given 指针位于悬浮窗内或外，When 用户按住主鼠标键并拖动跨过窗口边界，Then 拖动期间不触发紧凑/展开切换，松开后再进行一次判定。
- A6：Given 用户将悬浮窗拖到任一屏幕可见区域外，When 从菜单栏选择“显示额度窗口”，Then 窗口以展开尺寸出现在主屏幕 visible frame 的右上安全边距内。
- A7：Given 用户将悬浮窗拖到屏幕边界外，以至于可见区域小于 32×32pt，When 松开鼠标，Then 窗口自动回弹到主屏幕右上默认位置；正常贴边的窗口保持当前位置。

## 技术方案

`FloatingWindowController` 管理无边框 `NSPanel`、锚点、hover 监控和紧凑/展开尺寸；hover 状态转换由可测试策略决定，主鼠标键按住时不转换，避免与 AppKit 窗口拖动同时改写 frame。`FloatingWindowPlacementPolicy` 根据屏幕 `visibleFrame` 和窗口尺寸计算默认右上落点，并判定 frame 是否保留最小可抓取区域；菜单栏恢复和拖动后的自动回弹均采用此策略。`FloatingQuotaView` 选择布局；`ProviderCard` 与 `QuotaRing` 展示 provider 细节；`MenuBarQuotaGlyph` 和 `QuotaPulseApp` 构成菜单栏入口。

## 测试计划与实现映射

- 健康边界由 `QuotaModelsTests.testHealthThresholds` 覆盖。
- UI：`Sources/QuotaPulse/Views/`。
- 窗口行为：`Sources/QuotaPulse/Support/FloatingWindowController.swift`。
- 拖动与 hover 互斥策略：`Tests/QuotaPulseTests/FloatingWindowInteractionPolicyTests.swift`。
- 默认恢复位置策略：`Tests/QuotaPulseTests/FloatingWindowInteractionPolicyTests.swift`。
- 拖动后可见性策略：`Tests/QuotaPulseTests/FloatingWindowInteractionPolicyTests.swift`。
- 手动检查紧凑态和展开态拖动不漂移、松开后 hover 恢复，以及全屏 Space、单/双 provider、不同健康等级和菜单栏刷新；将窗口拖出可见区域后，从菜单栏选择“显示额度窗口”或松开鼠标，确认其回到主屏幕右上。

## 未决问题

窗口交互目前主要依赖手动验证，尚无 UI 自动化测试。

## 实施记录

- Assumption: “显示额度窗口”是恢复入口，因此每次调用都重置位置；日常 hover 展开和手动拖动不改变。
- Test plan: 先为默认右上定位写入纯几何 XCTest 并确认 RED，再接入 AppKit 面板恢复流程；运行完整测试、安全检查和启动验证。
- Verification (2026-07-21): `swift test` passed (54 tests). `QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify` passed. `./script/security_check.sh` remains blocked by pre-existing `/Users/example/...` placeholder-path findings in unrelated tests and specs.
