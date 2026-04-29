# VibeMove for Windows

**English** | [简体中文](README.zh-CN.md)

A Windows port of [VibeMove](https://github.com/fifteen42/vibemove) — turn webcam-detected hand and body gestures into keyboard actions for vibe coding workflows.

> **Status: pre-implementation.** The macOS prototype exists and is the reference. This repo is building the Windows version from scratch using Python + MediaPipe.

## What it does

Your camera becomes a controller. Raise a thumb to toggle dictation, pinch to send, clap to submit — no hardware, no wires.

Two modes:

- **`hand`** — finger gestures for subtle input
- **`body`** — squat, clap, cross arms for standing-desk use

## Gesture → Action mapping

**Hand mode**

| Gesture | Action |
| --- | --- |
| 👍 Thumbs up | Right Alt (Typeless dictation toggle) |
| 👌 Pinch (OK sign) | Enter |
| 🤏 Closed pinch | Backspace |
| ☝️ Index up | Ctrl+A |
| ☜ Index left | Left arrow |
| ☞ Index right | Right arrow |
| ✌️ Peace | Ctrl+V |
| 🤘 Rock | Ctrl+C |
| 👎 Thumbs down | Escape |

**Body mode** *(requires head-to-hip camera framing)*

| Motion | Action |
| --- | --- |
| 🏋️ Squat | Right Alt (Typeless dictation toggle) |
| 👏 Clap | Enter |
| ❌ Arms cross X | Escape |

## Stack

- Python 3.11 + OpenCV + MediaPipe (prototype)
- C#/.NET WPF shell (planned, after prototype validates recognition)
- Win32 `SendInput` for keyboard injection

See [`docs/migration-plan.md`](docs/migration-plan.md) for the implementation roadmap and [`docs/porting-reference.md`](docs/porting-reference.md) for the macOS-to-Windows porting guide.

## Original macOS version

The macOS app is at [fifteen42/vibemove](https://github.com/fifteen42/vibemove). It uses AVFoundation + Apple Vision + CGEvent and targets macOS 13+. The Windows version ports the gesture logic and replaces all Apple platform layers.

## License

MIT
