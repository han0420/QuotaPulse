# QuotaPulse UI 规范

这份规范适用于 `Sources/QuotaPulse/Views` 中的 SwiftUI 设置页和表单类界面。目标是让新增功能与现有额度提醒、定时提醒、通用设置保持一致。

## 页面骨架

- 设置页使用 `Form` + `.formStyle(.grouped)`。
- 顶层功能使用 `Section`，标题使用本地化 key。
- 设置页维持统一宽高：`frame(width: 620, height: 760)`，除非内容确实需要调整。
- 不在 Section 内直接堆叠裸控件；每个输入项都应有明确标签、对齐方式和状态反馈。

## 行布局

### 标签 + 单值输入

使用 `HStack(spacing: 12)`，标签占据剩余宽度，控件固定或限制最大宽度：

```swift
HStack(spacing: 12) {
    Text(title)
        .frame(maxWidth: .infinity, alignment: .leading)
    TextField("", text: $value)
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .frame(width: 72)
}
```

数值输入右对齐；单位单独作为 `Text` 放在输入框之后，不写进输入框值。

### 开关

简单开关使用 `Toggle(label, isOn:)`；需要补充说明时使用带有副标题的 `VStack` label，参考登录启动设置。不要手工把 Toggle 放到右侧再重复绘制标签。

### 多行文本

多行文本使用 `VStack(alignment: .leading, spacing: 7)`，先放标题，再放 `TextEditor`。编辑器应有最小高度、内边距和圆角描边，使其与 `.roundedBorder` 输入框属于同一视觉体系。

## 按钮与状态

- 主要保存动作使用 `.buttonStyle(.borderedProminent)`。
- 保存动作和状态反馈放在同一个 `HStack`，按钮在左、状态在右。
- 成功/失败状态使用 `Label`、SF Symbol 和本地化文案；成功使用绿色，失败使用橙色或红色。
- 删除按钮使用 destructive role，并优先使用图标 + `help`，避免长文本破坏行高。

## 文本与本地化

- 所有用户可见文本必须通过 `LanguageSettings.text` 或本地化资源提供。
- `en.lproj` 与 `zh-Hans.lproj` 必须同步新增 key。
- Label、placeholder、help、错误提示和说明文字都属于用户可见文本，不能硬编码。
- 说明文字使用 `.font(.caption).foregroundStyle(.secondary)`。

## 数据与交互

- UI 只编辑本地 `@State` / `Binding`，点击保存时再持久化；不要让文本输入的每个字符直接触发偏好、Keychain 或网络写入。
- 视图不直接调用 provider endpoint；刷新和外部 I/O 由 Store/Service 负责。
- 新设置项应有默认值、保存反馈和无效输入状态。

## 检查清单

- 是否位于正确的 `Section`？
- 标签、输入框和单位是否在同一行正确对齐？
- 是否复用了 `.roundedBorder`、`.borderedProminent` 和 caption 说明样式？
- 中英文 key 是否都已添加？
- 是否避免了输入过程中写 Keychain/网络？
- UI 修改后是否运行 `swift test`，并在可用时运行 `./script/build_and_run.sh --verify`？
