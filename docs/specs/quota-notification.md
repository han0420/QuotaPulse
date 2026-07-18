# 可配置额度提醒

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

额度阈值原先固定为每消耗 10% 提醒。用户需要在设置中自定义提醒间隔，并可将一次额度周期最多划分为两段，为后半程设置更密集的提醒。

## 非目标

- 不支持三段或更多分段。
- 不按 provider 或 session/weekly 周期分别配置。
- 不在额度剩余 0% 时额外通知。
- 不改变定时提醒与通知点击动作功能。

## 用户行为

设置页提供“额度提醒”：

- “固定间隔”按统一的已消耗百分比提醒；默认值为 10%。
- “分两段”允许设置第一段结束位置及两段各自的提醒间隔。
- 用户保存后，配置从下一次额度刷新起生效。
- 输入不合法时显示错误且不覆盖已保存配置。

## 需求

- R1：系统 MUST 默认每消耗 10% 额度提醒一次。
- R2：用户 MUST 能把固定提醒间隔设置为 1～99 的整数。
- R3：用户 MUST 能启用两段策略，并把分段位置设置为已消耗额度的 1～99%。
- R4：两段各自的提醒间隔 MUST 为 1～99 的整数。
- R5：两段模式 MUST 在分段位置产生一次提醒，即使第一段间隔不能整除分段位置。
- R6：提醒阈值 MUST 大于 0% 剩余额度。
- R7：一次刷新跨越多个阈值时 MUST 只发送当前跨过的最低剩余额度阈值通知。
- R8：额度向上重置时 MUST NOT 发送阈值通知。
- R9：有效配置 MUST 持久化；缺失、损坏或非法的持久化数据 MUST 回退到默认配置。
- R10：设置界面 MUST 同时提供英文和简体中文文案。
- R11：百分比输入行 MUST 使用左侧字段名、右侧紧凑数字输入框和 `%` 单位，且不得在输入区域重复渲染字段名。
- R12：固定间隔和分两段模式的输入行 SHOULD 与“提醒与自动化”编辑器保持一致的水平对齐、常规行高和分隔节奏。

## 合法性与边界

“前 50%”按已消耗进度 0%～50% 理解。例如分段位置 50%、第一段间隔 10%、第二段间隔 5%，对应剩余额度阈值为：90、80、70、60、50、45、40、35、30、25、20、15、10、5%。

间隔 100% 会只对应剩余 0%，与 R6 冲突，因此被视为非法。配置保存失败不会修改之前已持久化的值。

## 验收场景

- A1：Given 无已保存配置，When 加载设置，Then 固定间隔为 10%。
- A2：Given 固定间隔 7%，When 剩余额度从 94% 降至 92%，Then 在 93% 阈值提醒。
- A3：Given 50%/10%/5% 两段配置，When 生成阈值，Then 得到 90% 至 50% 每 10%、45% 至 5% 每 5% 的剩余阈值。
- A4：Given 上述两段配置，When 剩余额度一次从 52% 降至 44%，Then 只通知 45% 阈值。
- A5：Given 任一输入为 0、100、负数或大于 100，When 保存，Then 显示非法输入且不持久化。
- A6：Given 剩余额度向上恢复，When 刷新，Then 不通知。
- A7：Given 固定间隔或分两段模式，When 设置页以 620 点宽度显示，Then 字段名保持水平可读，右侧仅显示数字输入和 `%`，不存在逐字换行的重复标签。

## 技术方案

`QuotaNotificationConfiguration` 保存模式、分段位置与间隔，负责验证和阈值生成；`QuotaNotificationPreferences` 通过 `UserDefaults` 编解码配置。`QuotaStore` 在比较前后读数时加载配置，`QuotaNotificationPolicy` 只负责判断跨过的最低阈值，`SettingsView` 提供编辑和保存反馈。

## 测试计划

- 单段自定义间隔及跨越判断。
- 两段阈值序列与跨越多个阈值行为。
- 数值合法性、默认值和持久化往返。
- 额度向上重置不提醒。
- 完整执行 `swift test` 和 `./script/security_check.sh`。
- 手动检查设置页两种模式、双语切换、非法输入提示以及重启后配置恢复。
- 手动检查固定间隔和分两段模式的输入行在中英文下均无重复标签、竖排文字或异常增高。

## 实现映射

| 规格 | 实现/测试 |
| --- | --- |
| R1–R6、R9 | `Sources/QuotaPulse/Models/QuotaNotificationConfiguration.swift` |
| R7–R8 | `Sources/QuotaPulse/Services/QuotaNotificationService.swift`、`Sources/QuotaPulse/Stores/QuotaStore.swift` |
| R10–R12 | `Sources/QuotaPulse/Views/SettingsView.swift`、`Sources/QuotaPulse/Resources/*.lproj/Localizable.strings` |
| A1–A6 | `Tests/QuotaPulseTests/QuotaModelsTests.swift` |

## 未决问题

无。
