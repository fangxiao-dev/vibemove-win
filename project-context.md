# VibeMove Windows Project Context

## Project Summary

- Name: VibeMove Windows
- Project type: Windows desktop gesture-control application, currently in pre-implementation context setup.
- One-sentence purpose: Build a Windows version of VibeMove that turns webcam-detected hand/body gestures into keyboard actions for vibe coding workflows.
- Primary audience: Windows users who want hands-free or body-driven control while coding, dictating, prompting, or operating an AI-assisted editor.
- Current phase: Technical feasibility and stack selection before prototype implementation.

## Background

VibeMove already exists as a macOS prototype/application. The macOS version uses the camera as a controller: Apple Vision extracts hand or body landmarks, geometry rules classify gestures, and macOS keyboard events trigger actions such as dictation, Enter, Escape, copy, paste, select all, arrow keys, and delete.

The Windows project exists because the current macOS implementation is tied to Apple-only frameworks:

- Camera capture uses `AVFoundation`.
- Hand and body pose detection use Apple `Vision`.
- Keyboard injection uses `CoreGraphics.CGEvent`.
- The floating skeleton HUD uses `AppKit` and `NSWindow`.
- The Swift package declares `platforms: [.macOS(.v13)]`.

Because of those dependencies, the Windows version should be treated as a port/rebuild of platform layers, not as a small build-flag change. The reusable part is mainly the product concept, gesture/action mapping, debounce strategy, and landmark-based geometry rules.

## Product Theme

- Domain: Camera-based human-computer interaction for coding and AI tooling.
- Product feel: Utility-first Windows tray/HUD app rather than a broad creative tool.
- Core idea: The user's body or hand becomes a low-friction input surface, reducing keyboard/mouse switching during dictation and prompt iteration.

## Key User Scenarios

1. A user raises a thumb or performs a body gesture to toggle Windows dictation or another configured speech input action.
2. A user pinches, claps, or performs another deliberate gesture to submit a prompt with Enter.
3. A user performs cancel/navigation/editing gestures such as Escape, Backspace/Delete, copy, paste, select all, or arrow movement.
4. A user opens a small always-on-top HUD to see whether the camera sees the hand/body landmarks and which gesture is currently classified.

## Goals And Scope

- Current milestone: Build a Windows feasibility prototype that validates webcam capture, landmark detection, gesture classification, latency, and keyboard event injection.
- Success condition: On a normal Windows machine with a webcam, the prototype can reliably classify a small set of gestures and emit visible/logged actions with acceptable latency.
- Minimum usable closed loop: `webcam frame -> landmark detection -> gesture classification -> debounce/edge trigger -> keyboard action or logged action -> HUD/debug feedback`.
- Required deliverables for the current foundation phase:
  - `project-context.md`
  - `tech-stack-investigate.md`
  - Open questions that future planning must close before productization.
- In scope for the first technical milestone:
  - Python/OpenCV/MediaPipe proof of concept.
  - Mapping MediaPipe landmarks to the existing gesture geometry concepts.
  - Keyboard output feasibility on Windows through Win32 `SendInput`.
  - Basic debug UI or console/HUD feedback.
- Out of scope for the first technical milestone:
  - Installer, signing, auto-update, and polished packaging.
  - Full settings UI.
  - Cloud services or account system.
  - Training a custom ML model.
  - Cross-platform abstraction beyond the Windows target.
- Constraints:
  - Must run locally and process camera frames on-device.
  - Must not depend on Apple platform APIs.
  - Should keep the first prototype small enough to quickly invalidate bad recognition assumptions.
- Non-goals:
  - Recreate the Swift/macOS codebase line-for-line.
  - Make Swift the Windows implementation language unless a later investigation proves strong value.
  - Replace landmark geometry with heavy ML before the simple approach is tested.
- Risks:
  - MediaPipe recognition quality may differ from Apple Vision.
  - Body gestures may require camera framing that is awkward on Windows laptops.
  - Python sidecar packaging can become large and operationally awkward.
  - Keyboard injection may need careful handling for elevated apps, focus, and Windows security boundaries.
  - Dictation hotkey behavior on Windows is not the same as macOS Fn dictation toggling.

## Repository Facts

### Current Windows Repository

- Path: `D:\CodeSpace\vibemove-win`
- GitHub: https://github.com/fangxiao-dev/vibemove-win
- State: Planning documents written; Python prototype not yet started.
- Git status: Initialized and pushed.
- Key directories: `docs/` (porting reference and migration plan); `prototype/` (not yet created).
- Main entrypoints: `prototype/main.py` (planned, not yet created).
- Test entrypoints: None yet.
- Important scripts: None yet.

### Referenced macOS Prototype

- Local reference path: `C:\Users\Xiao\Documents\Codex\2026-04-29\https-github-com-fifteen42-vibemove-macos`
- Main language: Swift 5.9.
- Target platform: macOS 13+.
- Entry point: `Sources/VibeMove/main.swift`.
- Gesture classifiers:
  - `Sources/VibeMove/Gesture.swift`
  - `Sources/VibeMove/BodyGesture.swift`
- Camera and landmark extraction:
  - `Sources/VibeMove/HandDetector.swift`
  - `Sources/VibeMove/BodyDetector.swift`
- Keyboard output:
  - `Sources/VibeMove/Keyboard.swift`
- HUD:
  - `Sources/VibeMove/Overlay.swift`
- Packaging:
  - `scripts/package.sh`
  - `.github/workflows/release.yml`, running on `macos-14`.

## Candidate Technical Direction

The recommended near-term direction is:

1. Start with a Python prototype using OpenCV for camera capture and MediaPipe for hand/body landmarks.
2. Port the existing landmark geometry and debounce logic into a small Python classifier.
3. Validate latency, CPU usage, recognition reliability, and action mapping.
4. If recognition is good, decide between:
   - rewriting the product shell in C#/.NET with a more native detection layer, or
   - keeping Python/MediaPipe as a sidecar process controlled by a C#/.NET shell.

See `tech-stack-investigate.md` for the stack comparison.

## Confirmed Facts

- The current Windows repository is empty and not yet initialized as Git.
- The reference macOS project is implemented in Swift and targets macOS only.
- The reference macOS project uses Apple frameworks that are unavailable on Windows.
- The macOS project uses rule-based geometry over normalized landmarks rather than a custom trained gesture model.
- The macOS project has two modes: hand gestures and body gestures.
- The HUD is a debugging and feedback surface, not the core recognition engine.

## Reasonable Inferences

- The highest-risk Windows work is camera capture plus landmark recognition quality, not keyboard injection.
- The existing gesture rules are worth porting as a starting point, but thresholds may need retuning because MediaPipe landmarks and Apple Vision landmarks differ.
- A Python prototype is the fastest way to test the recognition loop.
- A C#/.NET shell is a reasonable productization direction for Windows-native UI, tray integration, configuration, and keyboard output.
- A Python sidecar can accelerate productization, but it increases packaging and process-management complexity.

## Closed Questions

- **Which Windows versions are required?** Windows 11 (developer machine is Windows 11 Home). Windows 10 support is not a first-prototype requirement.
- **Which gestures are mandatory for the first prototype?** Hand gestures only. Body mode requires full-body camera framing that is harder to validate early; add it after hand mode is proven.
- **What should replace macOS Fn dictation on Windows?** Right Alt (`VK_RMENU = 0xA5`) — triggers Typeless dictation. Not `Win+H` (Windows Speech Recognition dependency, requires user setup).
- **Should the first prototype emit real keyboard events immediately?** Yes. Log actions in addition to firing them, but do not defer real output — the goal is to validate the full loop including keyboard injection.

## Open Questions

- Should the product eventually be a tray app, a normal windowed app, or a mostly invisible background utility with HUD? (Tray app is the current directional preference but not finalized.)
- Is the target distribution a personal tool, open-source release, or packaged end-user product?
- How should elevated Windows apps and protected input surfaces be handled for `SendInput`?
- What is the first distribution target: local developer run, zip, installer, or signed release?
