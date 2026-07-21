# 通过 HTTP 触发 QuotaPulse 系统通知

QuotaPulse 提供了一个仅限本机访问的 HTTP 接口。其他程序、脚本或网页可以向它发送请求，让 macOS 显示系统通知。

## 基本信息

| 项目 | 内容 |
| --- | --- |
| 地址 | `http://127.0.0.1:37821/v1/notifications` |
| 方法 | `POST` |
| 请求格式 | `application/json` |
| 认证方式 | `Authorization: Bearer <令牌>` |
| 访问范围 | 当前 Mac 本机 |

接口只监听本机地址，不接受局域网或互联网连接。

## 获取令牌

1. 打开 QuotaPulse 设置。
2. 找到“本机通知 API”区域。
3. 复制“Bearer 令牌”。

令牌只保存在本机应用设置中，不要提交到代码仓库、公开网页或聊天记录中。下面示例中的令牌是占位符：

```text
YOUR_QUOTAPULSE_TOKEN
```

## 请求格式

请求正文必须包含两个非空字符串字段：

```json
{
  "title": "通知标题",
  "body": "通知正文"
}
```

标题和正文各最多 1,000 个字符，请求体最大 16 KiB。

## Shell / curl

```bash
curl -X POST http://127.0.0.1:37821/v1/notifications \
  -H "Authorization: Bearer YOUR_QUOTAPULSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"构建完成","body":"任务已完成"}'
```

成功时返回 HTTP `202`。

## 浏览器 Console

浏览器页面必须运行在安全上下文中。推荐先访问一个本机页面，例如：

```bash
cd /tmp
python3 -m http.server 8765
```

然后打开 `http://localhost:8765/`，在该页面的开发者工具 Console 中执行：

```js
fetch("http://127.0.0.1:37821/v1/notifications", {
  method: "POST",
  headers: {
    Authorization: "Bearer YOUR_QUOTAPULSE_TOKEN",
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    title: "构建完成",
    body: "任务已完成"
  })
})
  .then(async response => ({
    status: response.status,
    body: await response.text()
  }))
  .then(console.log)
  .catch(console.error);
```

预期结果：

```js
{ status: 202, body: "" }
```

不要直接在 `file://` 页面或浏览器新标签页的空白 Console 中执行。它们的来源通常是 `null`，Chrome 会因为 Private Network Access 安全策略拒绝访问本机接口。

## Python

```python
import urllib.request
import json

request = urllib.request.Request(
    "http://127.0.0.1:37821/v1/notifications",
    data=json.dumps({
        "title": "备份完成",
        "body": "文件已成功备份"
    }).encode("utf-8"),
    headers={
        "Authorization": "Bearer YOUR_QUOTAPULSE_TOKEN",
        "Content-Type": "application/json"
    },
    method="POST",
)

with urllib.request.urlopen(request) as response:
    print(response.status)  # 202
```

## Node.js

```js
const response = await fetch("http://127.0.0.1:37821/v1/notifications", {
  method: "POST",
  headers: {
    Authorization: "Bearer YOUR_QUOTAPULSE_TOKEN",
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    title: "部署完成",
    body: "生产环境部署成功"
  })
});

console.log(response.status); // 202
```

## 常见返回状态

| 状态码 | 含义 | 常见原因 |
| --- | --- | --- |
| `202` | 请求已接受 | 通知请求合法 |
| `400` | 请求格式错误 | JSON 无效、字段为空或内容过长 |
| `401` | 未授权 | 令牌缺失或错误 |
| `404` | 找不到接口 | URL 不是 `/v1/notifications` |
| `405` | 方法不允许 | 使用了 `GET` 等非 `POST` 方法 |

## 排查步骤

### 浏览器报 CORS 或 Private Network Access 错误

确认当前页面地址是 `http://localhost:...` 或 `https://...`，不要使用 `file://`。同时确认 QuotaPulse 已经启动，并且使用的是包含浏览器 CORS 支持的最新版应用。

### 返回 401

从 QuotaPulse 设置中重新复制令牌，确保请求头格式完全是：

```text
Authorization: Bearer YOUR_QUOTAPULSE_TOKEN
```

### 连接失败

确认 QuotaPulse 正在运行。HTTP 服务随应用启动和退出：应用退出后，`127.0.0.1:37821` 不再监听。

### 通知没有弹出

打开 macOS 系统设置中的通知权限，确认已允许 QuotaPulse 发送通知。

## 停止本机测试网页服务器

如果按照浏览器示例启动了临时网页服务器，请回到运行命令的终端按 `Ctrl + C` 停止它。该命令只是提供 `/tmp` 目录内容，不需要删除整个 `/tmp` 目录。
