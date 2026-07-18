# 定时提醒与点击动作

- Status: Implemented
- Last updated: 2026-07-19
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

## 验收场景

- A1：Given 未来一次性提醒，When 保存，Then 创建一个不重复日历通知。
- A2：Given 五个工作日，When 保存每周提醒，Then 创建五个重复通知。
- A3：Given `javascript:` URL 或相对脚本路径，When 保存，Then 拒绝配置。
- A4：Given Python 动作，When 用户点击通知，Then 以参数数组运行 `python3` 且使用指定工作目录。
- A5：Given 旧版提醒偏好，When 首次加载，Then 迁移为一条每日提醒。

## 技术方案

`DailyReminderConfiguration` 负责规范化、验证、计划生成和迁移；`QuotaNotificationService` 注册类别并同步 `UNNotificationRequest`；`ReminderActionExecutor` 执行点击动作；`SettingsView` 提供编辑器。

## 测试计划与实现映射

- 自动化覆盖计划、验证、迁移、payload 往返、稍后动作和无 shell 进程构造，位于 `QuotaModelsTests.swift`。
- 实现：`Models/DailyReminderConfiguration.swift`、`Services/QuotaNotificationService.swift`、`Services/ReminderActionExecutor.swift`、`Views/SettingsView.swift`。
- 手动检查通知权限拒绝、一次性触发、每周触发、点击动作及稍后提醒。

## 未决问题

无。
