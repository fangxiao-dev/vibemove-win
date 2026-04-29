# VibeMove Windows Technology Investigation

## Role Of This Document

- Purpose: Evaluate practical technology choices for a Windows port/rebuild of VibeMove.
- Relation to `project-context.md`: This document supports the project context by comparing candidate implementation stacks and recommending a staged path.
- Scope note: This is an initial stack investigation, not a final architecture spec. It should be revised after a working recognition prototype exists.

## Selection Principles

1. Validate recognition before polishing the shell.
   The core unknown is whether Windows webcam capture plus MediaPipe landmarks can reliably reproduce the desired gestures.
2. Keep the first milestone observable.
   The prototype should expose landmarks, classified gesture, frame rate, confidence, and emitted action so threshold problems can be tuned.
3. Productize only after the input loop is proven.
   UI, installer, tray behavior, signing, and auto-update should not lead the work until the recognition path is credible.
4. Prefer native Windows affordances for the final shell.
   A Windows product should use normal Windows mechanisms for tray, hotkeys, keyboard injection, startup behavior, logging, and settings.

## Existing macOS Stack Baseline

- Language/runtime: Swift 5.9.
- Camera: `AVCaptureSession`, 640x480.
- Recognition: Apple Vision hand pose and body pose requests.
- Gesture logic: Rule-based geometry over normalized landmarks, with edge-trigger/debounce logic.
- Output: `CGEvent` keyboard events.
- UI: AppKit floating `NSWindow` skeleton HUD.
- Packaging: macOS `.app` zip built on GitHub Actions `macos-14`.

This stack is not portable to Windows because its input, output, UI, and packaging layers are Apple-platform-specific.

## Stack A: Python Prototype — **Selected for Stage 1**

- Language: Python 3.11.
- Camera: OpenCV `VideoCapture`, 640×480.
- Landmark detection: MediaPipe Tasks Vision — `HandLandmarker` and `PoseLandmarker` (Tasks API, not legacy `solutions.hands`).
- Gesture classification: Ported geometry and debounce logic from the macOS Swift implementation.
- Output: Win32 `SendInput` via `ctypes` for real keyboard events from day one, plus console/overlay debug.
- GPU: start CPU-only; try `delegate=Delegate.GPU` in `BaseOptions` after the camera loop is working — one-line change, falls back to CPU silently if unsupported.
- Packaging: none for the prototype.

## Stack B: C#/.NET Product Shell — **Selected for Stage 3**

- Language/runtime: C# on modern .NET.
- UI: WPF (transparent always-on-top HUD, settings panel, tray icon).
- System integration: P/Invoke to Win32 `SendInput`.
- Detection: connected to Python sidecar (Stack C) or rewritten natively (Stack D), decided after prototype results.

## Stack C: C# Shell + Python/MediaPipe Sidecar — **Candidate for Stage 3**

- Main app: C#/.NET WPF shell.
- Detector: Python process (script or PyInstaller bundle).
- IPC: stdin/stdout JSON Lines is the simplest starting point; named pipes or local WebSocket if latency matters.
- Trade-offs: larger install size (ships Python runtime + model assets), process lifecycle complexity.
- Choose this if prototype recognition is strong and speed to a shippable app outweighs packaging cost.

## Stack D: Native C++ Detection + C# Shell — **Deferred**

Potentially cleaner packaging than a Python sidecar, but significantly higher setup cost. Revisit only if prototype proves the feature and packaging or performance requirements justify the investment.

## Technology Notes From Current Documentation

- Google AI Edge documents MediaPipe Hand Landmarker for Python as a way to detect hand landmarks in images and provides Python example code.
- Google AI Edge documents MediaPipe Pose Landmarker for Python for body landmarks in image/video/live stream use cases. The live stream/video modes can use tracking to reduce latency.
- OpenCV provides `VideoCapture`, which is the standard first tool to validate webcam capture in a Python prototype.
- Microsoft documents WPF as a Windows desktop UI framework with a broad input/UI model and Win32 interop options.
- Microsoft documents Win32 `SendInput` as the function for synthesizing keyboard/mouse input.
- PyInstaller can bundle Python applications and dependencies, but it is platform-specific: Windows bundles need to be built on Windows.

Sources checked on 2026-04-29:

- MediaPipe Hand Landmarker for Python: https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker/python
- MediaPipe Pose Landmarker for Python: https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker/python
- OpenCV video I/O documentation: https://docs.opencv.org/
- WPF input overview: https://learn.microsoft.com/dotnet/desktop/wpf/advanced/input-overview
- WPF and Win32 interop: https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/wpf-and-win32-interoperation
- Win32 `SendInput`: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput
- PyInstaller documentation: https://pyinstaller.org/

## Recommended Staged Direction

### Stage 1: Recognition Prototype

Build a small Python prototype:

```text
OpenCV webcam -> MediaPipe landmarks -> gesture classifier -> debounce -> logged action/debug HUD
```

Initial gesture set should stay small:

- Hand: thumbs up, pinch, closed pinch, open palm or Escape gesture.
- Body: clap and cross-arms first; squat only after full-body framing is confirmed.

Do not build installer or polished UI in this stage.

### Stage 2: Windows Output Feasibility

Add Windows action output:

- `Enter`
- `Escape`
- `Backspace/Delete`
- `Ctrl+A`, `Ctrl+C`, `Ctrl+V`
- Left/right arrows
- Candidate dictation action, likely `Win+H` or a configurable hotkey

The result should make clear whether Windows input injection works reliably in the intended target apps.

### Stage 3: Product Shell Decision

Choose one of two directions:

1. C#/.NET WPF shell plus Python sidecar if speed matters and Python recognition is strong.
2. C#/.NET shell plus native detection rewrite if packaging size, reliability, and long-term maintainability matter more.

### Stage 4: Productization

Only after the previous stages:

- Tray app and background lifecycle.
- Settings UI for gestures and key bindings.
- HUD positioning/collapse persistence.
- Logs and diagnostics.
- Installer/signing/update strategy.
- Automated tests for classifier logic and process protocol.

## Current Recommendation

Python 3.11 + OpenCV + MediaPipe Tasks API for the prototype (Stage 1 and 2). C#/.NET WPF shell for productization (Stage 3), with Python sidecar as the faster bridge option versus a native detection rewrite. Sidecar architecture is not finalized until prototype packaging and reliability are tested.

## Confirmed Choices

- Target platform: Windows 11.
- The macOS Swift stack is reference material only.
- Stage 1: Python 3.11 + OpenCV + MediaPipe Tasks API (not legacy `solutions.hands`).
- Stage 3 shell: C#/.NET WPF.
- Keyboard output: Win32 `SendInput` via `ctypes`.
- Dictation action: Right Alt (`VK_RMENU = 0xA5`) for Typeless. Not `Win+H`.
- First prototype: hand gestures only. Body mode added after hand is validated.
- GPU: attempt `delegate=Delegate.GPU` after camera loop is working; start CPU-only.
- End-to-end latency target: < 150 ms (gesture hold → keyboard event).
- Gesture classifier runs inside the Python process (not raw landmark streaming to shell) for the prototype.

## Open Technical Questions

- Which IPC protocol between Python sidecar and C# shell: JSON Lines, named pipes, or local WebSocket?
- How should elevated Windows apps and protected input surfaces be handled for `SendInput`?
- What is the first distribution target: local developer run, zip, installer, or signed release?
