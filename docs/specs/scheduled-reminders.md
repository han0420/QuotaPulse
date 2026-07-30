# 定时提醒与点击动作

- Status: Implemented
- Last updated: 2026-07-30
- Owners: project maintainers

## 背景与目标

用户可以建立多条一次性、每日或每周系统通知，并选择点击通知后的安全动作。

## 非目标

- 不提供云同步、复杂日历表达式或后台 shell 脚本。
- 不替代可配置额度阈值提醒。

## 用户行为与需求

- R1：用户 MUST 能新增、启用、禁用、删除并一次保存多条提醒。
- R2：提醒 MUST 支持未来一次性时间、每日时分、每周一个或多个星期。
- R3：启用的提醒 MUST 有非空消息、合法计划和合法点击动作。
- R4：点击动作 MUST 支持无动作、HTTP/HTTPS URL、绝对文件/应用路径、快捷指令名称、绝对 `.py` 路径加绝对工作目录。
- R5：URL MUST 限制为有 host 的 HTTP/HTTPS；路径型动作 MUST 使用绝对路径。
- R6：快捷指令与 Python MUST 通过 `Process` 参数数组直接执行，不得经过 shell 拼接。
- R7：通知 MUST 提供稍后 10 分钟和 1 小时动作。
- R8：保存后 MUST 移除旧待处理请求并按当前有效配置重新同步。
- R9：旧单提醒偏好和旧 URL 配置 MUST 迁移为兼容的新模型。
- R10：通知点击动作 MUST 在向系统报告响应处理完成前发起，避免菜单栏应用进入非活动状态时丢失打开 URL 等动作。
- R11：新增提醒 MUST 插入编辑列表顶部，使用户无需滚动到列表末尾。
- R12：已到期的一次性提醒 MUST 保留在列表中、显示“已完成”状态并在加载编辑列表时自动关闭；用户 MAY 删除它，或修改到未来时间后重新启用。
- R13：应用启动或保存提醒时 MUST 清理当前 `QuotaPulse` 与历史 `QuotaDot` 命名空间下的待处理定时提醒，再按当前配置重新同步；即使当前配置为空也 MUST 执行清理，且 MUST NOT 删除其他通知请求。
- R14：通知点击处理 MUST 记录从系统响应接收、payload 解析到动作执行结果的本机诊断日志；日志 MUST NOT 记录提醒正文、完整 URL、文件路径、快捷指令名称、脚本参数或其他用户内容。

## 验收场景

- A1：Given 未来一次性提醒，When 保存，Then 创建一个不重复日历通知。
- A2：Given 五个工作日，When 保存每周提醒，Then 创建五个重复通知。
- A3：Given `javascript:` URL 或相对脚本路径，When 保存，Then 拒绝配置。
- A4：Given Python 动作，When 用户点击通知，Then 以参数数组运行 `python3` 且使用指定工作目录。
- A5：Given 旧版提醒偏好，When 首次加载，Then 迁移为一条每日提醒。
- A6：Given 含有 URL 动作的通知，When 用户点击通知，Then 先发起 URL 打开，再调用系统响应完成回调。
- A7：Given 已有多条提醒，When 用户新增提醒，Then 新提醒出现在列表第一项。
- A8：Given 一条已启用但时间已过去的一次性提醒，When 设置页加载，Then 该提醒仍在列表中、已关闭且显示完成状态。
- A9：Given 系统中同时存在 `QuotaDot` 遗留提醒、`QuotaPulse` 提醒和无关通知，When 应用启动或保存提醒，Then 两个本应用提醒命名空间均被清理并仅重建当前有效配置，无关通知保留。
- A10：Given 一个带 URL、路径或脚本动作的通知，When 用户点击通知，Then 统一日志包含回调、解析和执行结果以及非敏感动作类别，但不包含动作目标值。

## 技术方案

`DailyReminderConfiguration` 负责规范化、验证、计划生成、完成状态判断和迁移；`QuotaNotificationService` 注册类别、识别当前及历史提醒请求并同步 `UNNotificationRequest`，并记录点击响应边界；`ReminderActionExecutor` 执行点击动作、记录结果并使用不含目标值的动作类别标签；`SettingsView` 提供编辑器，并通过可测试的列表规则将新增项置顶、把过期的一次性提醒准备为关闭状态。启动恢复流程无论当前配置是否为空都调用同步，以便清除系统中遗留的提醒。

## 测试计划与实现映射

- 自动化覆盖计划、验证、迁移、payload 往返、稍后动作、点击动作与系统完成回调顺序、无 shell 进程构造、新增置顶和一次性提醒完成状态，位于 `QuotaModelsTests.swift`。
- 实现：`Models/DailyReminderConfiguration.swift`、`Services/QuotaNotificationService.swift`、`Services/ReminderActionExecutor.swift`、`Views/SettingsView.swift`。
- R11 / A7：`ReminderListPolicy.prepending(_:to:)` 与 `SettingsView.addReminder()`。
- R12 / A8：`DailyReminderConfiguration.isCompleted(at:)`、`ReminderListPolicy.preparingForDisplay(_:at:)` 与 `DailyReminderEditor` 完成状态标签。
- R13 / A9：`ReminderNotificationIdentifierPolicy`、`QuotaNotificationService.synchronizeReminders` 与 `AppDelegate.restoreDailyReminders()`。
- R14 / A10：`QuotaNotificationService.userNotificationCenter(_:didReceive:withCompletionHandler:)`、`ReminderClickAction.diagnosticLabel` 与 `ReminderActionExecutor.perform(_:)`。
- 验证（2026-07-24）：列表策略 RED 已确认，聚焦测试转绿；完整 `swift test` 61 项通过；`QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify` 通过。当时安全检查被仓库已有的个人主目录格式 fixture 阻断，该 fixture 已于 2026-07-30 修正。
- 验证（2026-07-30）：旧 `QuotaDot` 与当前 `QuotaPulse` 提醒标识清理策略的 RED 已确认，聚焦测试与完整 `swift test` 62 项通过；`QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify` 通过。当时安全检查仍被同一 fixture 阻断。
- 验证（2026-07-30）：点击诊断标签隐私测试的 RED 已确认，聚焦测试与完整 `swift test` 63 项通过；`QUOTAPULSE_ALLOW_ADHOC=1 ./script/build_and_run.sh --verify` 通过。诊断改动未新增安全告警。
- 手动检查：设置页已有多条提醒时新增一条，确认无需滚动且新卡片位于顶部；分别在中英文下确认过期一次性提醒显示完成状态、保持关闭，并可修改未来时间后重新启用。
- 手动检查通知权限拒绝、一次性触发、每周触发、点击动作及稍后提醒。
- 手动检查升级迁移：使用曾调度过 `QuotaDot` 提醒的系统启动新版，确认旧提醒不再重复触发，当前提醒仍可点击执行动作。

## 未决问题

无。
