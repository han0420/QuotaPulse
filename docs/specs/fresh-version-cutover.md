# 纯新版本断代

- Status: Implemented
- Last updated: 2026-08-04
- Owners: project maintainers

## 背景与目标

应用曾为历史版本保留偏好迁移、宽松解码、通知命名空间清理和点击回查分支。这些入口使旧数据可以重新进入当前运行时，增加重复通知、无效动作和错误配置恢复的风险。

本次执行一次明确的破坏性断代：应用只读写当前 v2 schema 与命名空间，首次启动时删除旧应用偏好和本应用可见的全部通知。用户重新配置提醒和其他设置。

## 非目标

- 不删除 Codex / Claude 供应商自己管理的本机登录会话。
- 不删除第三方 API 解析容错、网络降级、天气默认文案或新安装默认值。
- 不降低 macOS 14 部署兼容性。
- 不从旧数据恢复或合并任何字段。

## 用户行为

- 安装本版并首次启动后，语言、额度提醒、周计划、DeepSeek、定时提醒和本机通知 API token 均使用新安装默认值。
- 通知中心内本应用当前身份可见的已投递与待处理通知全部清空。
- 旧备份文件、旧提醒 JSON 和缺少当前必填字段的数据被拒绝，不自动转换。
- 完成一次断代后，后续启动保留用户在 v2 namespace 中新建的配置。

## 需求

- R1：应用 MUST 在访问任何持久化配置之前执行一次性 fresh-start 准备。
- R2：首次 fresh-start MUST 删除应用 UserDefaults 域中的全部现有键，然后只写入 v2 完成标记。
- R3：完成标记存在时 fresh-start MUST NOT 删除任何 v2 配置。
- R4：所有应用偏好 key MUST 使用 `QuotaPulse.v2.` 前缀；生产代码 MUST NOT 读取旧 key。
- R5：定时提醒模型 MUST 要求完整的当前 schedule/action schema，MUST NOT 保留历史 URL 字段或缺字段默认。
- R6：通知 request、category、action 和 payload key MUST 使用 v2 namespace，MUST NOT 识别或清理任何旧 namespace。
- R7：首次 fresh-start 后 MUST 调用系统 API 删除当前应用身份可见的全部待处理与已投递通知，之后只调度 v2 配置。
- R8：配置备份格式 MUST 升为 v2，MUST 拒绝所有其他版本且不部分写入。
- R9：受版本控制的生产源码与测试 MUST NOT 包含旧品牌名称或旧数据迁移分支。
- R10：ad-hoc 本机签名 MUST 继续使用稳定 designated requirement，避免 v2 通知在后续重编译时失去路由身份。
- R11：纯新版应用 MUST 使用 `com.cmsjcm.QuotaPulse.v2` bundle identifier，与所有历史签名来源的通知容器完全隔离。
- R12：安装切换 MUST 停止旧身份应用，并关闭旧 `com.cmsjcm.QuotaPulse` 的系统通知展示；新版 MUST 独立申请通知授权。

## 合法性与边界

- fresh-start 是用户明确授权的破坏性操作；不保留应用偏好备份。
- 新安装默认值仍是合法运行路径，不视为旧版兼容。
- 用户随后导入的 v2 备份可以重建当前配置；非 v2 备份拒绝。
- 无法从当前应用身份枚举的系统孤儿通知不直接修改系统私有数据库；安装流程通过停止、注销和替换旧应用身份做最大限度清理。

## 验收场景

- A1：Given 偏好域包含多个旧配置键，When 首次执行 fresh-start，Then 这些键全部消失且只留下 v2 完成标记。
- A2：Given v2 完成标记与用户新配置已存在，When 再次启动，Then 新配置保留。
- A3：Given 只有旧提醒 key 或缺少当前必填字段的 JSON，When 加载，Then 返回空配置或解码失败，且不产生迁移写入。
- A4：Given 一条完整 v2 提醒，When 持久化、调度和点击，Then 只使用 v2 key 与 identifier 并正常执行动作。
- A5：Given 一份非 v2 备份，When 导入，Then 返回不支持版本且当前偏好不变。
- A6：Given fresh-start 刚完成，When 应用启动通知服务，Then 当前身份可见的 pending/delivered 通知全部清除并且没有旧配置被重建。
- A7：Given 两个不同内容的本机 ad-hoc 构建，When 检查 designated requirement，Then 两者使用同一稳定 identifier requirement。
- A8：Given 系统通知数据库仍有旧 bundle 的重复请求，When 安装并授权 v2 bundle，Then 新应用只接收 v2 容器通知，旧 bundle 请求不再展示。

## 技术方案

`FreshStartPolicy` 在 `AppDelegate` 的任何配置依赖初始化之前清空偏好域并写入 v2 marker。需要偏好的 AppDelegate 属性延迟初始化。`QuotaNotificationService` 在该次启动清空所有可见通知，随后只同步 v2 request。所有偏好存储和备份服务共享 v2 namespace 约定，不提供任何转换器。应用 bundle identity 断代为 `com.cmsjcm.QuotaPulse.v2`；旧 identity 的系统通知权限在安装切换时关闭。

## 测试计划

- fresh-start 首次清空、二次保留和 marker 行为。
- 每类 v2 偏好的默认、往返、无效数据和旧 key 忽略。
- 提醒完整 schema 往返与缺字段解码失败。
- v2 通知 identifier/payload 与点击解析。
- 备份 v2 往返与非 v2 原子拒绝。
- 全仓库受控源码与测试的旧品牌零匹配。
- 完整 `swift test`、`./script/security_check.sh`、稳定签名集成验证与应用启动验证。

## 实现映射

- `FreshStartPolicy`：主实例首次启动前清空应用偏好域并写入 v2 marker；重复实例无权执行清理。
- `AppDelegate`：fresh-start 后同步清空通知，再启动 HTTP API、额度刷新与提醒恢复。
- 各偏好存储：统一使用 `QuotaPulse.v2.*`，不读取或迁移旧 key。
- `DailyReminderConfiguration` / `DailyReminderPreferences`：严格校验当前提醒结构，拒绝缺少条件必填字段的读取与写入。
- `QuotaNotificationService`：只生成和识别 v2 notification/category/action/payload identifier。
- `AppConfigurationBackup`：只导出和接受版本 2，非 v2 导入保持原子拒绝。
- `script/assemble_app.sh`：ad-hoc 构建固定 designated requirement 为 `identifier "com.cmsjcm.QuotaPulse.v2"`。
- `AppBrand`、构建/运行脚本与 OSLog subsystem：统一使用 `com.cmsjcm.QuotaPulse.v2`，禁止复用历史通知容器。
- macOS 通知设置：旧 `com.cmsjcm.QuotaPulse` 身份关闭，新 `.v2` 身份独立授权。

## 验证记录

- `swift test`：68 tests passed。
- `./script/security_check.sh`：passed。
- `./script/build_and_run.sh --verify`（允许本机 ad-hoc）：构建、签名与启动验证通过。
- 两个不同 build number 的 `.v2` ad-hoc bundle：designated requirement 均为 `identifier "com.cmsjcm.QuotaPulse.v2"`。
- 生产源码与测试：旧品牌名、旧提醒字段和旧提醒单项 key 零匹配。
- 本机安装后偏好域：只包含 `QuotaPulse.v2.freshStart.completed` 与新生成的 `QuotaPulse.v2.localNotificationHTTP.token`。
- 本机安装后 bundle identity：`com.cmsjcm.QuotaPulse.v2`；新版授权成功且 pending notification 数量为 0，旧身份通知已关闭。

## 未决问题

无。用户已明确选择不保留任何旧版本配置或提醒，并接受重新配置。
