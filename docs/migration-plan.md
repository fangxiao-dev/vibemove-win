# Migration Plan: macOS VibeMove → Windows Prototype

## Overview

This is a port of the recognition logic from the macOS Swift app to a Python prototype on Windows. The macOS codebase is the specification; do not port Swift/Apple APIs, only port geometry, classifier logic, and debounce behavior.

Staged approach:
1. Python prototype validates recognition and keyboard output
2. C#/.NET WPF shell is built after recognition is proven (see `tech-stack-investigate.md`)

---

## Phase 0 — Repo Bootstrap

**Goal:** Runnable Python environment, repo initialized.

- [ ] `git init`, push to https://github.com/fangxiao-dev/vibemove-win
- [ ] Create `.gitignore`: Python venv, `__pycache__`, `*.pyc`, MediaPipe model files (`*.task`)
- [ ] Create `prototype/` directory
- [ ] Create `prototype/requirements.txt`:
  ```
  opencv-python>=4.9
  mediapipe>=0.10.14
  ```
- [ ] Verify install: `python -c "import cv2, mediapipe; print('OK')"`
- [ ] Pin Python 3.11 (MediaPipe supports 3.9–3.12; 3.11 is the stable choice on Windows)

**GPU note:** MediaPipe Tasks API accepts `delegate=Delegate.GPU` in `BaseOptions`. Try it after Phase 1 — if it works with the installed wheel it costs nothing. If it doesn't, proceed CPU-only; the 5070's CPU handles 640×480 hand detection at 30+ FPS.

---

## Phase 1 — Camera + Landmark Loop

**Goal:** Webcam frames flowing through MediaPipe, landmarks visible in console.

### `prototype/hand_detector.py`

Replaces `HandDetector.swift` (AVFoundation + `VNDetectHumanHandPoseRequest`).

- Use `mediapipe.tasks.python.vision.HandLandmarker` (Tasks API, not legacy `solutions.hands`)
- Download model: `hand_landmarker.task` from MediaPipe releases
- Camera: `cv2.VideoCapture(0)`, set to 640×480
- Run in `VIDEO` mode (simpler than `LIVE_STREAM` for a prototype)
- Output: a `HandLandmarks` dataclass with the same field names as the Swift struct (see `docs/porting-reference.md` for index mapping)
- Filter landmarks with `visibility < 0.3` (mirrors the `confidence > 0.3` check in macOS)

### `prototype/body_detector.py`

Replaces `BodyDetector.swift`.

- Use `mediapipe.tasks.python.vision.PoseLandmarker`
- Download model: `pose_landmarker_lite.task` (or `_full.task`)
- Same 640×480 setup
- Output: `BodyLandmarks` dataclass with the fields used by the body gesture classifier

**Validation:** Print landmark y-coordinates for thumbs-up. Confirm they are in [0, 1] with origin top-left (larger y = lower in frame). This is inverted from macOS.

---

## Phase 2 — Gesture Classifier

**Goal:** Correct gesture names printed to console for each gesture performed.

### `prototype/gesture.py`

Ports `GestureClassifier` from `Gesture.swift`. Pure geometry — no API dependency.

**Required changes from macOS:**
- `isThumbsUp`: macOS checks `thumbTip.y > thumbIP.y` (y-up). In MediaPipe (y-down), invert to `thumbTip.y < thumbIP.y`. See `porting-reference.md` for the full set of flips.
- `pointingDirection`: keep the aspect-ratio correction `dx * (640.0 / 480.0)`. Left/right mirror logic may also need verification against the camera feed.
- All `extended()`/`curled()` distance helpers are coordinate-independent — port as-is.

Classification order matters (same as macOS): thumbsUp → thumbsDown → pinch → closedPinch → peace → rock → pointingDirection → fist → openPalm.

### `prototype/body_gesture.py`

Ports `BodyGestureClassifier` from `BodyGesture.swift`.

- `isClap`: wrist gap < 50% of shoulder width, both wrists above hip y — **invert the hip y comparison** (macOS: `wrist.y > hipY` because y-up; MediaPipe: `wrist.y < hipY` because y-down and "above" = smaller y)
- `isCrossArms`: cross-product sign check is coordinate-independent — port as-is

**Validation:** Add `--debug` flag to `main.py` that prints the gesture name every frame.

---

## Phase 3 — EdgeTrigger and Controllers

**Goal:** Gestures fire actions exactly once per deliberate hold, with correct debounce.

### `prototype/main.py` (partial)

Port `EdgeTrigger`, `HandController`, `BodyController` from `main.swift`. Pure Python, no API dependency.

```python
# Constants (match macOS exactly to start)
NEEDED_FRAMES = 3
REARM_FRAMES = 5
PINCH_NEEDED_FRAMES = 2
PINCH_COOLDOWN_SECONDS = 0.8
ENTER_AFTER_DELETE_COOLDOWN = 0.4

# Squat detector constants
SQUAT_WINDOW_SECONDS = 2.0
SQUAT_MIN_DIP_RATIO = 0.30   # fraction of torso length
SQUAT_RISE_BACK_RATIO = 0.10
SQUAT_COOLDOWN_SECONDS = 1.5
SQUAT_MIN_FRAMES = 10
```

Squat detection uses a rolling time-window over `(timestamp, hipY, torsoLen)` tuples — see `main.swift:detectSquat()` for the exact logic.

---

## Phase 4 — Keyboard Output

**Goal:** Real keyboard events fired on Windows for every mapped gesture.

### `prototype/keyboard.py`

Replaces `Keyboard.swift` (`CGEvent` keyboard injection).

Use `ctypes` + Win32 `SendInput` (`INPUT` struct, `KEYBDINPUT`). No third-party library needed.

**Action mapping for Windows:**

| macOS function | Windows key | VK code |
|---|---|---|
| `tapFn()` | Right Alt (Typeless dictation) | `VK_RMENU = 0xA5` |
| `tapReturn()` | Enter | `VK_RETURN = 0x0D` |
| `tapEscape()` | Escape | `VK_ESCAPE = 0x1B` |
| `tapDelete()` | Backspace | `VK_BACK = 0x08` |
| `tapLeftArrow()` | Left arrow | `VK_LEFT = 0x25` |
| `tapRightArrow()` | Right arrow | `VK_RIGHT = 0x27` |
| `tapCmdA()` | Ctrl+A | `VK_CONTROL + 0x41` |
| `tapCmdC()` | Ctrl+C | `VK_CONTROL + 0x43` |
| `tapCmdV()` | Ctrl+V | `VK_CONTROL + 0x56` |

**SendInput pattern:**
```python
import ctypes
from ctypes import wintypes

INPUT_KEYBOARD = 1
KEYEVENTF_KEYUP = 0x0002

class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wintypes.WORD), ("wScan", wintypes.WORD),
                ("dwFlags", wintypes.DWORD), ("time", wintypes.DWORD),
                ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong))]

# ... wrap in INPUT union, call ctypes.windll.user32.SendInput
```

**Smoke test:** Wire a single gesture to `tap_enter()` and confirm it fires in Notepad before wiring all gestures.

---

## Phase 5 — Debug Overlay

**Goal:** Visual feedback that the pipeline is running and gestures are classified.

### `prototype/overlay.py`

Replaces `Overlay.swift` (AppKit floating NSWindow skeleton HUD).

Use OpenCV's `imshow` — draw on the camera frame before displaying:
- Landmark skeleton lines on hands/body
- Current gesture label top-left corner
- Flash the action name for ~0.5 s after an EdgeTrigger fires (use a timestamp + string)

No always-on-top window needed at this stage. That comes with the C# shell (Stage 3 in `tech-stack-investigate.md`).

---

## Phase 6 — Integration and Tuning

**Goal:** Full working prototype, `--mode hand` and `--mode body` both functional.

Wire everything in `prototype/main.py`:
1. Parse `--mode hand|body` argument
2. Start the appropriate detector
3. Each frame: extract landmarks → classify gesture → update EdgeTrigger → fire keyboard action → update overlay
4. `Ctrl+C` exits cleanly (close `VideoCapture`, destroy OpenCV windows)

**Tuning checklist:**
- [ ] Thumbs up/down recognized correctly (y-axis flip confirmed)
- [ ] Pinch vs. closedPinch correctly disambiguated (extended vs. curled middle/ring/little)
- [ ] Pointing direction horizontal/vertical split correct (aspect-ratio correction working)
- [ ] Right Alt fires and toggles Typeless dictation in target apps
- [ ] EdgeTrigger prevents double-fires on held gestures
- [ ] `enterAfterDeleteCooldown` prevents spurious Enter after closedPinch release
- [ ] Body clap and crossArms recognized at reasonable camera distance
- [ ] Squat dip/rise cycle detected (requires full-body framing, head to hips)
- [ ] Measure end-to-end latency: gesture hold → keyboard event (target < 150 ms)

---

## After Phase 6

See `tech-stack-investigate.md` Stage 3: choose between C# + Python sidecar vs. C# + native detection rewrite based on prototype results.
