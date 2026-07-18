# 凭据与隐私边界

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

QuotaPulse 复用本机 Codex/Claude 已认证状态获取额度，同时最小化凭据、位置和会话数据的访问与暴露。

## 非目标

- 不创建 QuotaPulse 账号、不托管凭据、不提供遥测或远端日志。
- 不承诺第三方凭据格式稳定。

## 需求

- R1：Codex 凭据 MUST 从 `CODEX_HOME/auth.json` 或默认 Codex 目录只读加载，文件超过 256 KiB 时拒绝。
- R2：Claude 凭据 MUST 从支持的环境、配置文件或 Keychain 来源加载；仅官方 refresh 流程需要时才写回原来源。
- R3：Claude access token 在到期前 5 分钟内 SHOULD 刷新；环境来源 MUST NOT 被持久化写回。
- R4：写回 Claude 文件 MUST 原子完成并设置权限 `0600`；Keychain MUST 原地更新对应 service。
- R5：额度和天气请求 MUST 使用 ephemeral URL session，禁用 cookie storage 和 URL cache，并限制负载大小与超时。
- R6：日志、测试、文档和提交 MUST NOT 包含 token、真实用户名、凭据内容、精确坐标、私钥或签名密码。
- R7：活动检测 MUST 只读取会话文件元数据，不读取内容。
- R8：位置坐标 MUST 仅发送给选定天气服务，不与额度凭据组合。
- R9：通知 Python/Shortcut 动作 MUST 直接构造进程及参数，不通过 shell。
- R10：新增网络服务、遥测、远程配置或凭据写入 MUST 先形成独立隐私/安全决策。

## 验收场景

- A1：Given Codex auth 文件过大或无 access token，When 获取额度，Then 安全失败且不记录内容。
- A2：Given Claude token 将在 5 分钟内到期，When 获取额度，Then 先刷新再请求。
- A3：Given Claude 凭据来自环境变量，When 刷新，Then 不写入磁盘或 Keychain。
- A4：Given 活动检测，When 扫描会话目录，Then 仅读文件类型和修改时间。
- A5：Given Python 动作包含特殊字符，When 执行，Then 字符作为单一参数传递而非 shell 解释。

## 技术方案与实现映射

凭据边界位于 `CodexDirectClient.swift` 与 `ClaudeDirectClient.swift`；网络 client 使用独立 ephemeral session；活动隐私位于 `QuotaStore.swift`；动作边界位于 `ReminderActionExecutor.swift`。更广泛政策见 `PRIVACY.md`、`SECURITY.md`。

## 测试计划

- Claude 刷新提前量和动作无 shell 构造已有单元测试。
- 每次提交运行 `./script/security_check.sh`。
- 发布前检查凭据权限、脱敏日志、Codex-only/Claude-only 和干净标准账户安装。

## 未决问题

当前安全脚本会把测试中的通用 `/Users/example/...` fixture 标为个人路径；应另行修正规则或 fixture，使默认检查可通过。
