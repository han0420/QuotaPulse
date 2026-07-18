# Provider 额度数据

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

应用需要同时或独立展示 Codex、Claude 的当前额度窗口，并在服务数据不完整、窗口暂时隐藏或某个来源失败时保持可用。

## 非目标

- 不提供账号登录、token 输入或远端中转。
- 不把不同 provider 的额度合并成一个额度值。
- 不保证第三方未公开接口永久兼容。

## 用户行为

已登录的 provider 出现在悬浮窗和菜单栏；未登录 provider 不占位。展示可用的短周期和周周期剩余比例、重置时间、套餐信息；Codex 在接口提供时展示可用 reset credits 及有效期。没有任何可用数据时显示本地化错误，已有数据不会因单次刷新失败立即清空。

## 需求

- R1：应用 MUST 每 60 秒触发一次额度刷新，并支持用户手动刷新。
- R2：Codex、Claude 与 OpenUsage 刷新 MUST 独立执行，单一来源失败不得阻止其他来源更新。
- R3：某 provider 的 direct client 一旦成功，后续 OpenUsage 结果 MUST NOT 覆盖该 provider。
- R4：provider MUST 按 Codex 优先、其余显示名排序。
- R5：剩余比例 MUST 由 `1 - used/limit` 得到并限制在 0～100%。
- R6：Codex 短窗口依据时长或重置距离识别；异常长的 Session MUST 被隐藏或重分类为 weekly。
- R7：reset credits MUST 与普通 credits 分离，仅展示未兑换、未过期的有效期。
- R8：首次读数 MUST 仅建立提醒基线，不产生额度阈值通知。

## 合法性与边界

`limit <= 0` 或缺少 used/limit 时没有百分比。direct 响应必须为 HTTP 200、负载不超过 1 MiB 且包含至少一个合法窗口。失败仅在当前没有 provider 数据时设置额度不可用错误。

## 验收场景

- A1：Given Codex 和 Claude 均可用，When 刷新完成，Then 两者独立展示且 Codex 排在前面。
- A2：Given Codex direct 已成功，When OpenUsage 返回旧 Codex 数据，Then 保留 direct 结果。
- A3：Given Codex Session 重置时间远超短周期，When 解析，Then 不把它显示为短周期。
- A4：Given 仅一个来源失败且已有缓存，When 刷新，Then 继续显示已有数据。
- A5：Given 第一次成功读取，When 建立状态，Then 不发送阈值通知。

## 技术方案

`QuotaStore` 并发调度三个 client，并按 provider id 替换合并。`ProviderUsage` 负责窗口识别、百分比和异常 reset 修正。direct client 使用 ephemeral `URLSession`，不保留 cookie 或 URL cache。

## 测试计划与实现映射

- 模型/窗口测试：`Tests/QuotaDotTests/QuotaModelsTests.swift`。
- 编排：`Sources/QuotaDot/Stores/QuotaStore.swift`。
- 模型：`Sources/QuotaDot/Models/QuotaModels.swift`。
- 来源：`Sources/QuotaDot/Services/CodexDirectClient.swift`、`ClaudeDirectClient.swift`、`OpenUsageClient.swift`。
- 手动检查：Codex-only、Claude-only、双 provider、未登录和服务暂时失败。

## 未决问题

direct endpoint 与本机凭据格式由第三方控制，兼容变化需要新 spec 或本规格修订。
