# 周计划额度与工作日预算

- Status: Accepted
- Last updated: 2026-07-24
- Owners: project maintainers

## 背景与目标

周额度圆环已显示按周期连续计算的计划剩余比例。用户需要选择计划是否排除周六、周日，使额度预算可按七个自然日或五个工作日推进。

## 非目标

- 不支持自定义节假日、调休或任意工作日。
- 不改变 provider 返回的额度周期、实际余额或重置时间。
- 不改变额度提醒阈值。

## 用户行为

- 设置页提供“周计划额度”分区和“排除周六、周日”开关。
- 开关默认关闭，计划按额度周期内全部时间连续推进。
- 开启并保存后，计划只在本地日历的周一至周五推进，周六、周日冻结在最近工作日结束时的进度。
- 保存后当前浮窗立即采用新规则。

## 需求

- R1：配置 MUST 默认不排除周末，并通过 `UserDefaults` 持久化。
- R2：设置页 MUST 使用本地编辑状态和显式保存按钮，并显示本地化保存反馈。
- R3：关闭排除周末时，计划剩余 MUST 等于周期剩余时间除以完整周期时间。
- R4：开启排除周末时，分母 MUST 是额度周期内所有周一至周五时间，分子进度 MUST 只累计截至当前的周一至周五时间。
- R5：周末查看时计划进度 MUST 冻结，不累计周六、周日时间。
- R6：工作日判断 MUST 使用用户当前日历与时区。
- R7：周期无有效时长、当前时间不在周期内或周期内没有工作日时 MUST 隐藏计划值。
- R8：保存 MUST 立即更新共享 store 中的计划配置，使浮窗重新渲染。

## 合法性与边界

配置只有一个布尔字段，旧安装或无效持久化数据回退为关闭。跨夏令时的日期边界由 `Calendar` 计算，不假设每天固定 24 小时。周期恰好开始时继续隐藏计划值，避免把尚未推进的计划误认为有效读数。

## 验收场景

- A1：Given 新安装，When 打开设置，Then “排除周六、周日”关闭。
- A2：Given 七天周期且排除周末关闭，When 第四天结束查看，Then 计划已推进 `4/7`。
- A3：Given 周三 1 号至下周三 8 号的周期、4 号周六、5 号周日且排除周末开启，When 在 4 号或 5 号查看，Then 计划均已推进 `3/5`，计划剩余为 40%。
- A4：Given 用户开启选项，When 点击保存，Then偏好持久化且浮窗立即使用五工作日计划。

## 技术方案

`WeeklyQuotaPlanConfiguration` 与 `WeeklyQuotaPlanPreferences` 负责配置及持久化。`WeeklyQuotaBudget` 在普通模式按连续总时长计算，在排除周末模式按 `Calendar` 的本地日区间累计工作日交集。`QuotaStore` 持有共享配置；`SettingsView` 保存后更新 store；`ProviderCard` 把配置传入周额度计划计算。

## 测试计划

- 配置默认值、往返持久化和无效数据回退。
- 七天连续计划保持既有结果。
- 周三至下周三周期在周六、周日均冻结为 `3/5` 已推进。
- 无工作日或无效周期返回空值。
- 运行 `swift test`、`./script/security_check.sh` 与 `QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify`。
- 手动在中英文设置页保存开关，并确认浮窗计划标记立即变化。

## 实现映射

- R1：`Sources/QuotaPulse/Models/WeeklyQuotaPlanConfiguration.swift`；默认值、持久化与无效数据回退由 `QuotaModelsTests.testWeeklyQuotaPlanConfigurationDefaultsToSevenDaysAndPersistsWeekendChoice` 覆盖。
- R3–R7：`Sources/QuotaPulse/Models/QuotaModels.swift` 中的 `WeeklyQuotaBudget`；连续七天与周末冻结场景由 `QuotaModelsTests` 覆盖。
- R2、R8：`Sources/QuotaPulse/Views/SettingsView.swift`、两份 `Localizable.strings`、`Sources/QuotaPulse/Stores/QuotaStore.swift`。
- 圆环接入：`Sources/QuotaPulse/Views/FloatingQuotaView.swift`、`ProviderCard.swift`、`QuotaRing.swift`。
- 用户与架构文档：`README.md`、`docs/README.md`、`docs/ARCHITECTURE.md`。

## 验证记录

- 2026-07-24：先确认配置与周末算法测试因目标 API 缺失而 RED；实现后聚焦测试通过。
- `swift test`：59 项通过。
- `QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify`：通过。
- `./script/security_check.sh`：当时失败；由仓库已有的个人主目录格式 fixture 与既有文档记录触发，该 fixture 已于 2026-07-30 修正。
- 待人工检查：中英文设置页开关、保存反馈，以及保存后浮窗计划标记即时变化。

## 未决问题

无。节假日与调休不在本次范围内。
