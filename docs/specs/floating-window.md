# 悬浮窗与菜单栏

- Status: Implemented
- Last updated: 2026-08-13
- Owners: project maintainers

## 背景与目标

用户应能以低干扰方式持续看到最低剩余额度，并在需要时展开查看各 provider 详情。

## 非目标

- 不提供任意窗口尺寸、固定展开或自定义主题。
- 不在 Dock 中显示普通应用窗口。
- 不提供美国城市或时区选择；本次只显示用于对齐 OpenAI 美国西海岸工作日的太平洋时间。

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
- R13：周额度圆环 MUST 在实际剩余额度之外附加显示当前时间的计划剩余额度，使两个百分比可在同一尺度上直接比较。
- R14：计划剩余额度 MUST 使用 provider 返回的周期时长与有效重置时间连续计算，不按自然日取整；周期尚未开始、已经结束或缺少必要数据时 MUST 隐藏。
- R15：展开态 MUST 在标题区与 provider 详情之间显示一条 24pt 高的双时钟栏，并同时显示“当地时间”和“美国时间”。
- R16：当地时间 MUST 跟随 macOS 当前时区；美国时间 MUST 使用 IANA 时区 `America/Los_Angeles`，以便自动处理美国太平洋标准时间和夏令时。
- R17：两个时钟 MUST 使用本地化短星期加 `HH:mm` 24 小时制，并至少每分钟自动刷新；星期 MUST 分别按照各自时区计算，紧凑态不显示时钟。

## 验收场景

- A1：Given 两个 provider，When 窗口折叠，Then 显示两个独立 badge。
- A2：Given 指针进入紧凑窗体，When hover 被检测，Then 展开且右上锚点保持稳定。
- A3：Given Session 60%、Weekly 8%，When 渲染，Then菜单栏显示 8%，两个环分别使用其自身颜色。
- A4：Given provider 数量变化，When 紧凑态同步，Then 窗口宽度随数量变化。
- A5：Given 指针位于悬浮窗内或外，When 用户按住主鼠标键并拖动跨过窗口边界，Then 拖动期间不触发紧凑/展开切换，松开后再进行一次判定。
- A6：Given 用户将悬浮窗拖到任一屏幕可见区域外，When 从菜单栏选择“显示额度窗口”，Then 窗口以展开尺寸出现在主屏幕 visible frame 的右上安全边距内。
- A7：Given 用户将悬浮窗拖到屏幕边界外，以至于可见区域小于 32×32pt，When 松开鼠标，Then 窗口自动回弹到主屏幕右上默认位置；正常贴边的窗口保持当前位置。
- A8：Given 七天周期第一天结束且周额度剩余 90%，When 渲染周额度，Then 主值显示 90%，圆环附加显示计划剩余约 86%。
- A9：Given 七天周期第四天结束且周额度剩余 80%，When 渲染周额度，Then 主值显示 80%，圆环附加显示计划剩余约 43%。
- A10：Given 周额度缺少周期时长，When 渲染周额度，Then 只显示实际剩余额度，不显示计划值。
- A11：Given Mac 当地时区为 `Asia/Shanghai` 且时间为冬季 `2026-01-15T12:00:00Z`，When 渲染双时钟，Then 当地时间显示 `20:00`，美国时间显示 `04:00`。
- A12：Given 同一当地时区且时间为夏季 `2026-07-15T12:00:00Z`，When 渲染双时钟，Then 当地时间仍显示 `20:00`，美国时间显示 `05:00`，证明太平洋夏令时自动生效。
- A13：Given Mac 当地时区为 `Asia/Shanghai` 且时间为 `2026-08-13T00:15:00Z`，When 以简体中文渲染双时钟，Then 当地显示 `周四 08:15`，美国显示 `周三 17:15`，分别反映跨日后的星期。

## 技术方案

`FloatingWindowController` 管理无边框 `NSPanel`、锚点、hover 监控和紧凑/展开尺寸；hover 状态转换由可测试策略决定，主鼠标键按住时不转换，避免与 AppKit 窗口拖动同时改写 frame。`FloatingWindowPlacementPolicy` 根据屏幕 `visibleFrame` 和窗口尺寸计算默认右上落点，并判定 frame 是否保留最小可抓取区域；菜单栏恢复和拖动后的自动回弹均采用此策略。`WeeklyQuotaBudget` 以有效重置时间减去周期时长得到周期起点，并计算连续时间下的计划剩余额度。`QuotaRing` 在周额度主环内附加计划百分比，并在环上标记计划位置。`WorldClockDisplay` 使用显式时区生成可测试的当地与美国太平洋星期和时间文本，`FloatingQuotaView` 通过分钟级 `TimelineView` 渲染双时钟栏，`FloatingWindowController` 同步为展开窗口增加 24pt 高度。`ProviderCard` 与 `QuotaRing` 展示 provider 细节；`MenuBarQuotaGlyph` 和 `QuotaPulseApp` 构成菜单栏入口。

## 测试计划与实现映射

- 健康边界由 `QuotaModelsTests.testHealthThresholds` 覆盖。
- 周计划剩余额度的正常与无效边界由 `QuotaModelsTests` 覆盖。
- UI：`Sources/QuotaPulse/Views/`。
- 窗口行为：`Sources/QuotaPulse/Support/FloatingWindowController.swift`。
- 拖动与 hover 互斥策略：`Tests/QuotaPulseTests/FloatingWindowInteractionPolicyTests.swift`。
- 默认恢复位置策略：`Tests/QuotaPulseTests/FloatingWindowInteractionPolicyTests.swift`。
- 拖动后可见性策略：`Tests/QuotaPulseTests/FloatingWindowInteractionPolicyTests.swift`。
- 当地与美国太平洋时间格式、冬夏令时边界及跨日星期由 `Tests/QuotaPulseTests/WorldClockDisplayTests.swift` 覆盖。
- 手动检查紧凑态和展开态拖动不漂移、松开后 hover 恢复，以及全屏 Space、单/双 provider、不同健康等级和菜单栏刷新；将窗口拖出可见区域后，从菜单栏选择“显示额度窗口”或松开鼠标，确认其回到主屏幕右上。
- 手动检查双时钟栏位于标题与首个 provider 之间、没有裁切或挤压，并确认中英文标签及分钟跳变正确；紧凑态不得出现时钟。

## 未决问题

窗口交互目前主要依赖手动验证，尚无 UI 自动化测试。

## 实施记录

- Assumption: “显示额度窗口”是恢复入口，因此每次调用都重置位置；日常 hover 展开和手动拖动不改变。
- Test plan: 先为默认右上定位写入纯几何 XCTest 并确认 RED，再接入 AppKit 面板恢复流程；运行完整测试、安全检查和启动验证。
- Verification (2026-07-21): `swift test` passed (54 tests). `QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify` passed. The security check was then blocked by pre-existing personal-home-style fixture findings, corrected on 2026-07-30.
- Assumption (2026-07-24): “计划额度”采用连续时间预算，并以与主环相同的“剩余百分比”显示在周额度圆环上。
- Implementation (2026-07-24): `WeeklyQuotaBudget` 计算计划剩余比例；`ProviderCard` 只为周周期传入计划值；`QuotaRing` 在主值下方显示计划百分比，并以橙色环上标记表示计划位置；中英文资源同步。
- Verification (2026-07-24): RED confirmed for missing `plannedRemaining`; focused tests and full `swift test` passed (57 tests). `QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify` passed. The security check was then blocked by the documented personal-home-style fixture findings, corrected on 2026-07-30. Manual visual comparison of actual and planned markers in both languages remains required.
- Assumption (2026-08-13): “美国时间”用于观察 OpenAI 美国西海岸工作日，因此固定采用 `America/Los_Angeles`，不新增设置项；当地时间使用系统自动更新时区。
- Test plan (2026-08-13): 先用固定冬季、夏季与跨日日期为双时钟文本写入 XCTest 并确认 RED，再接入 24pt 双时钟栏、展开窗口尺寸与中英文本地化；最后运行完整测试、安全检查和启动验证。
- Implementation (2026-08-13): `WorldClockDisplay` 分别计算本机自动更新时区与 `America/Los_Angeles` 的本地化短星期和 24 小时时间；`FloatingQuotaView` 在标题与 provider 详情间显示分钟级更新的双时钟栏；`FloatingWindowLayout` 为展开面板增加 24pt；中英文资源与 README 同步。
- Verification (2026-08-13): RED confirmed for the missing world-clock formatter, expanded-height reservation, localization keys, and cross-date weekday fields. `swift test` passed (73 tests); `./script/security_check.sh` passed (87 publishable files); `QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify` passed after the unsigned local environment lacked an Apple Development identity. Manual expanded-panel inspection passed in Simplified Chinese with the live cross-date output `当地时间 周四 00:28` and `美国时间 周三 09:28`; the row was correctly positioned without clipping or crowding. English labels are covered by localization tests.
