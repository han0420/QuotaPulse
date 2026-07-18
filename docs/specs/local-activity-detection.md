# 本机活动检测

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

在不读取对话内容的前提下，用本机会话文件最近写入时间提示当前正在使用 Codex 或 Claude。

## 非目标

- 不解析 JSONL 内容、不上传活动、不统计使用时长。
- 活动状态不是额度消费的权威证明。

## 需求

- R1：应用 MUST 每秒检测一次活动。
- R2：Codex MUST 只扫描当天 `.codex/sessions/yyyy/MM/dd` 下的 JSONL；Claude MUST 扫描 `.claude/projects` 下的 JSONL。
- R3：只有普通 `.jsonl` 文件的修改时间在过去 4 秒内（允许最多 1 秒未来时钟偏差）才视为活跃。
- R4：Codex 与 Claude MUST 能同时处于活跃状态。
- R5：检测 MUST 仅使用文件元数据，不读取会话内容。
- R6：活跃 provider MUST 在紧凑 badge 和展开 card 中独立高亮，并在窗口过期后快速取消。

## 验收场景

- A1：Given 文件 3 秒前更新，When 检测，Then provider 活跃。
- A2：Given 文件 5 秒前更新，When 检测，Then provider 不活跃。
- A3：Given 两个 provider 均有最近写入，When 检测，Then 两者均高亮。

## 技术方案、测试与映射

`QuotaStore.detectLocalActivity` 枚举文件元数据，`ActivityDetectionPolicy` 提供可测试时间窗口，视图读取 `activeProviderIds`。时间边界已有单元测试；目录扫描和双 provider 显示需手动验证。

## 未决问题

大型 Claude projects 目录采用递归枚举，未来若出现性能问题应先建立性能规格。
