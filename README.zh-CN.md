# VibeMove

[English](README.md) | **简体中文**

> **你坐得太久了。我们用深蹲来解决这个问题。**

VibeMove 是一个让你**必须付出代价**才能发 prompt 的 vibe coding 助手。笔电摄像头盯着你。蹲一下，麦克风开。拍个掌，消息发出去。两臂交叉成 X，就像一个失望的教练，刚才说的话整个抹掉。

不用 Joy-Con，不用穿戴设备，不用从电影厂偷出来的动捕设备。只有 `AVCaptureSession` + Apple Vision + 一点点羞耻感。

## 核心理念

AI 负责思考。语音负责打字。**你的身体是新的鼠标。**

就这一件事。每一个 prompt 大约对应一次深蹲——怎么理解这里的"对应"，看你选哪个模式。

## 两种模式

目标一样：少敲键盘，多动身体。

| 模式 | 感觉 | 适合 |
| --- | --- | --- |
| **`body`** *（默认）* | "我要 vibe code 到出汗为止。" | 站立办公桌、走步机、厨房操作台、客厅地毯 |
| **`hand`** | "安静的手势魔法就好。" | 凌晨两点的桌前、开放式工位、隔壁房间孩子在睡觉 |

```bash
swift run VibeMove                       # body 模式（默认）
swift run VibeMove -- --mode hand        # hand 模式
```

## Hand 模式 —— 6 个手势，零键盘

跑 `VNDetectHumanHandPoseRequest`，像一个礼貌的机器人盯着你手上的 21 个关节。完全离线、本地、免费。

| 手势 | 触发 | 为什么是这个 |
| --- | --- | --- |
| 👍 **竖拇指**（点按） | **Fn** —— 听写开关 | 你现在是点赞侠了，接受它 |
| 👌 **OK 捏合** | **Enter** | 全世界通用的"发送"符号。而且手感很爽 |
| 🖐️ **张开手掌向下挥** | **Escape** | 带着气势把东西甩掉 |
| ☝️ **只伸食指** | **⌘A** —— 全选 | 一根手指，全宇宙 |
| ✌️ **Peace 手势** | **⌘V** —— 粘贴 | 对，V 就是 V |
| 🤘 **Rock 手势** | **⌘C** —— 复制 | 摇滚地复制 |

## Body 模式 —— 全身心体验

用 `VNDetectHumanBodyPoseRequest`。摄像头**至少要看到你从头到髋**。笔电平放在桌上只能拍到你的下巴——垫高、离远、接受变成居家健身博主的命运。

| 动作 | 触发 | 哲学 |
| --- | --- | --- |
| 🏋️ **深蹲**（下蹲+起身） | **Fn** —— 听写开关 | "想跟 AI 说话？先证明一下你配。" |
| 👏 **击掌**（胸前合拢） | **Enter** —— 发送 | 宇宙跟你的消息击掌 |
| ❌ **双臂胸前 X 交叉** | **Escape** —— 取消 | 裁判说不行 |

你的同事**一定会**在下次视频会议上问你在干嘛。这是个 feature，不是 bug。

## 音效设计

每次成功触发都会播放不同的 macOS 内置系统音，不用看屏幕就能听出是哪个动作刚中：

| 动作 | 音效 | 感觉像 |
| --- | --- | --- |
| Fn —— 听写 | Tink | "麦克风开了" |
| Enter —— 发送 | Pop | "飞出去了" |
| Escape —— 取消 | Funk | "撤回那个想法" |
| ⌘A | Morse | "一把抓全部" |
| ⌘V | Glass | "轻轻放下" |
| ⌘C | Hero | "拿走" |

## 安装

### 方式一 —— 下载预编译的 `.app`（推荐）

到 [Releases](https://github.com/fifteen42/vibemove/releases) 下载最新的 zip，解压后把 `VibeMove.app` 拖进 `Applications`。

> **首次启动 macOS 会骂你。** 因为构建还没签名（$99 的 Apple Developer ID *还没办*），Gatekeeper 会拒绝直接双击。绕过方式：
> - 右键点 `VibeMove.app` → **打开** → 在弹窗里确认。
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

## 权限

首次启动 macOS 会要两个权限。两个都得给，不然啥都不灵：

1. **摄像头** —— 系统会自动弹窗。
2. **辅助功能** —— 系统设置 → 隐私与安全性 → 辅助功能 → 把你用的终端 app（Terminal / iTerm2 / Ghostty / 等等）加进去。没有这个，VibeMove 看得见你但打不了字。

## 运行要求

- macOS 13+
- 任何带摄像头的 Mac（Apple Silicon 更快，Intel 也能跑）
- Swift 5.9+
- 接受自己"看起来有点傻"的能力

## 调参

如果默认阈值不适合你——太敏感、太难触发、跟你的身体比例不匹配——打开 `Sources/VibeMove/main.swift` 改顶部的常量：

| 常量 | 默认值 | 作用 |
| --- | --- | --- |
| `neededFrames` | 3 | 手势需要连续多少帧才触发 |
| `rearmFrames` | 5 | 手势离开后多少帧才能再次触发 |
| `pinchCooldownSeconds` | 0.8 | 两次 Enter 之间的最小间隔 |
| `swipeMinDropRatio` | 0.25 | 手腕下挥幅度（占画面高度百分比） |
| `squatMinDipRatio` | 0.30 | 深蹲要蹲多深（占躯干长度百分比）才算数 |
| `squatCooldownSeconds` | 1.5 | 两次深蹲之间的最小间隔 |

如果你发现自己在偷偷蹲半蹲避免触发，就把比例调低。不丢人。你的腰，你做主。

## 工作原理

- **摄像头** → `AVCaptureSession`，640×480。小分辨率，处理快，不烧 GPU。
- **识别** → Apple Vision 框架。`VNDetectHumanHandPoseRequest` 给 21 个手部关键点，`VNDetectHumanBodyPoseRequest` 给 19 个身体关键点。全在本地跑，零云调用，零模型下载。
- **分类器** → 归一化坐标上的几何判断。不训练 ML、不用标注数据、不要 20GB 权重。全是"这个点在那个点上面吗？这两段距离的比值小于多少吗？"
- **键盘模拟** → `CGEvent`。**Fn 键**特别刁钻：必须用 `.flagsChanged` 事件类型模拟（不能用 `keyDown`），否则 macOS 会以为 Fn 一直按着、开始自动给你放大屏幕。这个坑我踩过。
- **反馈** → `NSSound` 播放系统内置音效。免费、即时、不需要辅助功能权限。
- **HUD** → 屏幕右下角一个小的 `NSWindow` 浮层，实时显示骨架、当前识别到的姿态、以及每次触发动作时闪一下。让你看到 VibeMove 看到的东西。

## 愿景

长期 vibe：后键盘时代，打字已经不是瓶颈了。语音 + AI 处理文字，剩下的是**意图**——选这个、跳过那个、发送、取消、切换上下文。意图恰好是身体动作擅长的领域。一个深蹲、一次击掌、一个竖拇指，都是跟电脑说"对，就做这件事"的完美方式。

而且：你真的不应该每天被粘在椅子上十个小时。每个 prompt 一次深蹲，累积起来就多了。

## 致谢

精神层面受到 [wong2/vibe-ring](https://github.com/wong2/vibe-ring) 启发。VibeMove 走的是不同的路——没有控制器、没有外设，只有你的摄像头和你的身体。

## 许可证

MIT。随便玩、玩坏它、发 PR 过来。
