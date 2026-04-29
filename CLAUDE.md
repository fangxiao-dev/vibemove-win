# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project State

Pre-implementation. The repo currently contains only planning documents. The first deliverable is a Python prototype (`prototype/` directory, not yet created). GitHub remote: https://github.com/fangxiao-dev/vibemove-win.

## Commands

Once the Python prototype exists:

```bash
# Install dependencies (Python 3.11 recommended)
pip install -r prototype/requirements.txt

# Run prototype — hand mode
python prototype/main.py --mode hand

# Run prototype — body mode
python prototype/main.py --mode body
```

## Architecture

```
webcam frame → landmark detector → gesture classifier → EdgeTrigger (debounce) → keyboard action → HUD feedback
```

Two independent modes: `hand` (single-hand landmarks) and `body` (full-body pose). See [`docs/porting-reference.md`](docs/porting-reference.md) for the full macOS-to-Windows porting guide (landmark indices, coordinate system flip, gesture geometry, debounce constants).

### macOS Reference

`C:\Users\Xiao\Documents\Codex\2026-04-29\https-github-com-fifteen42-vibemove-macos\Sources\VibeMove\`

Port the *logic*, not the Swift APIs. The gesture classifier (`Gesture.swift`, `BodyGesture.swift`) and debounce controller (`main.swift`) are pure geometry and math — translate directly. Replace Apple platform layers with their Windows equivalents:

| macOS file | Apple API replaced | Windows file | Windows replacement |
|---|---|---|---|
| `HandDetector.swift` | AVFoundation + Vision | `prototype/hand_detector.py` | OpenCV + MediaPipe Hand Landmarker |
| `BodyDetector.swift` | AVFoundation + Vision | `prototype/body_detector.py` | OpenCV + MediaPipe Pose Landmarker |
| `Keyboard.swift` | CGEvent | `prototype/keyboard.py` | Win32 `SendInput` via `ctypes` |
| `Overlay.swift` | AppKit NSWindow | `prototype/overlay.py` | OpenCV imshow debug overlay |

### Dictation Key

**Right Alt** (`VK_RMENU = 0xA5`) replaces macOS Fn tap for Typeless dictation. macOS: `Keyboard.tapFn()` → Windows: `keyboard.tap_right_alt()`.

### Critical Coordinate System Difference

Apple Vision: origin **bottom-left**, y grows **upward**.  
MediaPipe: origin **top-left**, y grows **downward**.

The `isThumbsUp`/`isThumbsDown` y-comparisons and all body gesture height checks must be inverted. See [`docs/porting-reference.md`](docs/porting-reference.md).

## Planning Documents

- [`project-context.md`](project-context.md) — project scope, goals, open questions
- [`tech-stack-investigate.md`](tech-stack-investigate.md) — stack comparison and staged roadmap (Python prototype → C#/.NET shell)
- [`docs/porting-reference.md`](docs/porting-reference.md) — landmark indices, geometry constants, gesture-to-action mapping
- [`docs/migration-plan.md`](docs/migration-plan.md) — phased implementation plan
