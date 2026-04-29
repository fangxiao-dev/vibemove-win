# VibeMove for Windows

[English](README.md) | **简体中文**

[VibeMove](https://github.com/fifteen42/vibemove) 的 Windows 移植版——用摄像头检测手势和肢体动作，转换为键盘操作，专为 vibe coding 工作流设计。

> **当前状态：实现前期。** macOS 原型已存在并作为参考。本仓库使用 Python + MediaPipe 从头构建 Windows 版本。

## 能做什么

摄像头变成控制器。竖拇指开听写，捏合发送，击掌提交——不需要外设，不需要连线。

两种模式：

- **`hand`** —— 手指手势，适合细微操作
- **`body`** —— 深蹲、击掌、双臂交叉，适合站立办公

## 手势映射

**Hand 模式**

| 手势 | 对应操作 |
| --- | --- |
| 👍 竖拇指 | 右 Alt（Typeless 听写开关） |
| 👌 捏合（OK 手势） | Enter |
| 🤏 握拢捏合 | Backspace |
| ☝️ 只伸食指 | Ctrl+A |
| ☜ 食指向左 | 左方向键 |
| ☞ 食指向右 | 右方向键 |
| ✌️ Peace | Ctrl+V |
| 🤘 Rock | Ctrl+C |
| 👎 倒拇指 | Escape |

**Body 模式** *（需要摄像头看到头部到髋部）*

| 动作 | 对应操作 |
| --- | --- |
| 🏋️ 深蹲 | 右 Alt（Typeless 听写开关） |
| 👏 击掌 | Enter |
| ❌ 双臂胸前 X 交叉 | Escape |

## 技术栈

- Python 3.11 + OpenCV + MediaPipe（原型阶段）
- C#/.NET WPF 外壳（计划中，原型验证识别效果后实施）
- Win32 `SendInput` 模拟键盘输入

详见 [`docs/migration-plan.md`](docs/migration-plan.md)（实现路线图）和 [`docs/porting-reference.md`](docs/porting-reference.md)（macOS 到 Windows 移植参考）。

## macOS 原版

macOS 应用在 [fifteen42/vibemove](https://github.com/fifteen42/vibemove)，使用 AVFoundation + Apple Vision + CGEvent，目标平台 macOS 13+。Windows 版移植了手势逻辑，替换了所有 Apple 平台层。

## 许可证

MIT
