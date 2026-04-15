# VibeMove

[English](README.md) | **简体中文**

> macOS 上的 vibe coding 助手。你的摄像头就是控制器——竖大拇指开始听写，捏合发送，深蹲开麦。不用外设，不用连线。

VibeMove 把**手势**和**身体动作**翻译成 macOS 快捷键。竖个大拇指开始听写，捏合一下发送消息，或者站起来做个**深蹲**开启麦克风——一边写 prompt，一边顺便锻炼。

为 vibe coding 的后键盘时代而生：当语音负责打字、AI 负责思考，**你的身体就是新的控制面板**。每一次 prompt 都是一次动作，一次对久坐的小小反击。

## 两种模式

启动时通过参数选择：

| 模式 | 氛围 | 场景 |
| --- | --- | --- |
| **`body`**（默认） | 张扬。站起来，动起来。 | 站立办公桌、厨房、客厅——远离键盘。项目的灵魂所在。 |
| **`hand`** | 低调。坐在桌前动动手。 | 写代码、写文档、编辑——贴近键盘。 |

```bash
swift run VibeMove                       # body 模式（默认）
swift run VibeMove -- --mode hand        # hand 模式
```

## Hand 模式

6 个手势 → 6 个键盘操作。基于 Apple Vision 框架（`VNDetectHumanHandPoseRequest`），**完全离线**运行。

| 手势 | 对应按键 | 说明 |
| --- | --- | --- |
| 👍 竖大拇指（点按） | **Fn**（Typeless 听写开关） | 不用一直举着——比一下开始听写，再比一下结束。匹配 Typeless 的 toggle 逻辑。 |
| 👌 拇指 + 食指捏合 | **Enter** | 发送转写后的消息。 |
| 🖐️ 张开手掌向下挥 | **Escape** | 取消 / 撤销。 |
| ☝️ 只伸食指 | **⌘A** | 全选。 |
| ✌️ Peace 手势 | **⌘V** | 粘贴（V 形对应 V 键）。 |
| 🤘 Rock 手势 | **⌘C** | 复制。 |

## Body 模式

3 个全身动作 → 3 个按键。使用 `VNDetectHumanBodyPoseRequest`。**摄像头必须至少能看到你的头部到髋部**——笔电摄像头放桌上看不到，请垫高或离远一点。

| 动作 | 对应按键 | 说明 |
| --- | --- | --- |
| 🏋️ **深蹲**（下蹲+起身） | **Fn**（Typeless 听写开关） | 在起身瞬间触发，要求髋部下降至少躯干长度的 30%。 |
| 👏 **击掌**（双手胸前合拢） | **Enter** | 发送。 |
| ❌ **双臂胸前交叉 X 形** | **Escape** | 取消。 |

Body 模式的哲学：既然要和 AI 对话，**至少要配得上这个 prompt**。

## 反馈音

每个成功触发都会播放不同的 macOS 系统音，听一下就知道是哪个动作触发了：

| 操作 | 音效 |
| --- | --- |
| Fn（听写） | Tink |
| Enter | Pop |
| Escape | Funk |
| ⌘A | Morse |
| ⌘V | Glass |
| ⌘C | Hero |

## 环境要求

- macOS 13+
- 任何 Apple Silicon 或 Intel Mac（带摄像头）
- Swift 5.9+
- 辅助功能权限（用于模拟键盘事件）
- 摄像头权限（首次运行时会弹窗请求）

## 安装

### 方式一 —— 下载预编译的 `.app`（推荐）

到 [Releases](https://github.com/fifteen42/vibemove/releases) 下载最新的 zip，解压后把 `VibeMove.app` 拖进 `Applications` 文件夹。

> **首次启动**：因为暂时还没有 $99 的 Apple Developer ID，构建是未签名的，macOS Gatekeeper 会拒绝双击打开。绕过方法：
> - 右键点 `VibeMove.app` → **打开** → 在弹窗里确认
> - 或者在终端跑：`xattr -cr /Applications/VibeMove.app`

### 方式二 —— 从源码构建

```bash
git clone https://github.com/fifteen42/vibemove.git
cd vibemove
swift build
swift run VibeMove                       # body 模式（默认）
swift run VibeMove -- --mode hand        # hand 模式
```

### 自己打包 `.app`

```bash
bash scripts/package.sh 0.1.0
# → dist/VibeMove.app
# → dist/VibeMove-0.1.0.zip
```

### 权限设置

首次运行：

1. **摄像头**：接受系统弹窗。
2. **辅助功能**：系统设置 → 隐私与安全性 → 辅助功能 → 添加你使用的终端 app（Terminal / iTerm2 / Ghostty 等）。VibeMove 需要这个权限来发送键盘事件。

## 调参

判定阈值都在 `Sources/VibeMove/main.swift` 顶部。如果手势太敏感或太难触发，可以调：

| 常量 | 默认值 | 作用 |
| --- | --- | --- |
| `neededFrames` | 3 | 手势连续多少帧才触发。 |
| `rearmFrames` | 5 | 手势离开后多少帧才能再次触发（防重复）。 |
| `pinchCooldownSeconds` | 0.8 | 两次 Enter 的最小间隔。 |
| `swipeMinDropRatio` | 0.25 | 手腕下挥幅度（画面高度的百分比）。 |
| `squatMinDipRatio` | 0.30 | 深蹲下蹲幅度（躯干长度的百分比）。 |
| `squatCooldownSeconds` | 1.5 | 两次深蹲的最小间隔。 |

## 实现原理

- **摄像头** → `AVCaptureSession`，640×480。
- **识别** → `VNDetectHumanHandPoseRequest`（21 个手部关键点）或 `VNDetectHumanBodyPoseRequest`（19 个身体关键点）。
- **分类器** → 基于归一化坐标的几何判断，没有用机器学习训练。
- **键盘** → `CGEvent`。Fn 键特殊处理：用 `.flagsChanged` 事件模拟（不能用 keyDown），否则 macOS 会以为 Fn 一直按着而触发辅助功能缩放。
- **反馈** → `NSSound` 播放 macOS 内置系统音。
- **生命周期** → detector 和 controller 保持在顶层作用域，避免 ARC 释放 AVCapture delegate。

## 致谢

精神层面受到 [wong2/vibe-ring](https://github.com/wong2/vibe-ring) 启发。VibeMove 走的是不同的路——没有控制器、没有外设，只有你的摄像头和你的身体。

## 许可证

MIT
