# 天气背景与定位

- Status: Implemented
- Last updated: 2026-07-19
- Owners: project maintainers

## 背景与目标

悬浮窗可根据当前位置天气呈现环境背景和摘要；定位或天气失败不得影响额度功能。

## 非目标

- 不保存位置历史，不提供城市搜索或天气预报。
- 不将位置与 provider 凭据组合发送。

## 需求

- R1：天气监控 MUST 与额度刷新独立运行，并约每 10 分钟刷新。
- R2：未授权时 MUST 请求 macOS When-In-Use 定位权限；拒绝或系统服务关闭时显示对应状态。
- R3：定位 MUST 忽略超过 30 秒、未来超过 5 秒、无效精度或精度差于 10 km 的结果，并优先最准确结果。
- R4：达到 250 m 精度时可立即完成；否则最多等待约 12 秒后使用最佳有效结果。
- R5：地点显示名 MUST 优先区/县，其次市、再省，并移除常见行政后缀。
- R6：存在 `AMAP_WEBSERVICE_KEY` 时 SHOULD 优先高德；高德失败或无 key 时 MUST 回退 Open-Meteo。
- R7：网络请求 MUST 使用 ephemeral session、禁用 cookie/cache，并设置超时。
- R8：天气代码 MUST 映射为本地化文案、图标和 clear/cloud/fog/rain/snow/storm 背景情绪。
- R9：天气不可用时 MUST 保留额度界面并退回额度健康背景。

## 验收场景

- A1：Given 多个新鲜定位，When 选择位置，Then 使用精度最高者。
- A2：Given 区、市、省名称，When 生成显示名，Then 优先区级并移除行政后缀。
- A3：Given 雨、雪、雾、雷暴代码，When 渲染，Then 使用不同动画情绪。
- A4：Given 权限拒绝，When 天气刷新，Then 显示定位关闭状态且额度继续更新。

## 技术方案、测试与映射

`LocationClient` 处理 CoreLocation 和反地理编码；`WeatherClient` 选择服务；`WeatherSnapshot` 负责表现映射；`QuotaStore` 编排周期；`WeatherBackdrop` 渲染。位置选择、名称优先级和天气情绪已有单元测试；权限、fallback 和视觉效果需手动验证。

## 未决问题

高德服务依赖可选环境变量，公开构建默认可仅使用 Open-Meteo。
