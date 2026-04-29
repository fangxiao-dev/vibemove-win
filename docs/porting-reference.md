# Porting Reference: macOS → Windows

Technical reference for translating the macOS VibeMove gesture logic to the Python/MediaPipe prototype. Read alongside the macOS source at `C:\Users\Xiao\Documents\Codex\2026-04-29\https-github-com-fifteen42-vibemove-macos\Sources\VibeMove\`.

---

## Coordinate System

| | Apple Vision (macOS) | MediaPipe (Windows) |
|---|---|---|
| Origin | Bottom-left | Top-left |
| Y direction | Grows **upward** | Grows **downward** |
| Range | [0, 1] normalized | [0, 1] normalized |
| X direction | Left to right | Left to right |

**Consequence:** Any y-comparison that means "above" or "below" must be inverted.

### Affected classifiers

| Check in `Gesture.swift` | macOS condition | Python/MediaPipe condition |
|---|---|---|
| `isThumbsUp` — thumb tip above IP | `thumbTip.y > thumbIP.y` | `thumbTip.y < thumbIP.y` |
| `isThumbsUp` — IP above MP | `thumbIP.y > thumbMP.y` | `thumbIP.y < thumbMP.y` |
| `isThumbsUp` — tip above index MCP + offset | `thumbTip.y > indexMCP.y + 0.25 * handSize` | `thumbTip.y < indexMCP.y - 0.25 * handSize` |
| `isThumbsDown` — thumb tip below IP | `thumbTip.y < thumbIP.y` | `thumbTip.y > thumbIP.y` |
| `isThumbsDown` — IP below MP | `thumbIP.y < thumbMP.y` | `thumbIP.y > thumbMP.y` |
| `isThumbsDown` — tip below index MCP + offset | `thumbTip.y < indexMCP.y - 0.25 * handSize` | `thumbTip.y > indexMCP.y + 0.25 * handSize` |
| `pointingDirection` — pointing up | `dy > 0` | `dy < 0` |

| Check in `BodyGesture.swift` | macOS condition | Python/MediaPipe condition |
|---|---|---|
| `isClap` — wrists above hips | `wrist.y > hipY` | `wrist.y < hipY` |
| `isCrossArms` — wrists between hip and shoulder | `wrist.y > hipY && wrist.y < shoulderY` | `wrist.y < hipY && wrist.y > shoulderY` |

Body squat in `main.swift` tracks `hipY` and looks for a **rise then fall** pattern. In MediaPipe, "hip moving down" = hipY increasing, so "dip" = `maxY - minY` over the time window. The math is the same (absolute displacement), only the intuition flips.

---

## MediaPipe Hand Landmark Indices

MediaPipe Hand Landmarker returns 21 points (0–20). Mapping to the `HandLandmarks` struct fields:

| Field | MediaPipe index | Joint |
|---|---|---|
| `wrist` | 0 | Wrist |
| `thumbCMC` | 1 | Thumb carpometacarpal |
| `thumbMP` | 2 | Thumb metacarpophalangeal |
| `thumbIP` | 3 | Thumb interphalangeal |
| `thumbTip` | 4 | Thumb tip |
| `indexMCP` | 5 | Index metacarpophalangeal |
| `indexPIP` | 6 | Index proximal interphalangeal |
| `indexDIP` | 7 | Index distal interphalangeal |
| `indexTip` | 8 | Index tip |
| `middleMCP` | 9 | Middle MCP |
| `middleTip` | 12 | Middle tip |
| `ringMCP` | 13 | Ring MCP |
| `ringTip` | 16 | Ring tip |
| `littleMCP` | 17 | Little MCP |
| `littleTip` | 20 | Little tip |

The macOS implementation reads only the joints listed above. The intermediate PIP/DIP joints for middle/ring/little are not used in the gesture classifier.

---

## MediaPipe Pose Landmark Indices

MediaPipe Pose Landmarker returns 33 points. Mapping to the `BodyLandmarks` struct fields:

| Field | MediaPipe index | Joint |
|---|---|---|
| `nose` | 0 | Nose |
| `leftShoulder` | 11 | Left shoulder |
| `rightShoulder` | 12 | Right shoulder |
| `leftHip` | 23 | Left hip |
| `rightHip` | 24 | Right hip |
| `leftWrist` | 15 | Left wrist |
| `rightWrist` | 16 | Right wrist |
| `leftKnee` | 25 | Left knee |
| `rightKnee` | 26 | Right knee |

Note: MediaPipe's "left/right" is from the **subject's** perspective (consistent with anatomical convention). Apple Vision also uses subject-perspective naming. No swap needed.

**Core landmarks required:** leftShoulder, rightShoulder, leftHip, rightHip must all have `visibility >= 0.3`. If any are missing, emit `None` for the frame (mirrors the `guard` in `BodyDetector.swift`). Wrists and knees fall back to `(0, 0)` if below threshold.

---

## Gesture Classifier Constants

All from `Gesture.swift` — port as-is (these are geometry ratios, coordinate-independent):

```python
HAND_SIZE_MIN = 0.05          # handSize = dist(wrist, middleMCP); reject frame if smaller
LANDMARK_CONFIDENCE_MIN = 0.3 # filter MediaPipe landmark visibility

# extended() threshold: tip-to-wrist > mcp-to-wrist * 1.5
EXTENDED_RATIO = 1.5

# curled() threshold: tip-to-wrist < mcp-to-wrist * 1.25
CURLED_RATIO = 1.25

# isPointIndex: tip-to-MCP > handSize * 0.6 (rotation-invariant)
POINT_INDEX_RATIO = 0.6

# pointingDirection: aspect-ratio correction for 640x480 camera
ASPECT_RATIO_CORRECTION = 640.0 / 480.0

# pinch / closedPinch: thumb-to-index gap < handSize * 0.22
PINCH_GAP_RATIO = 0.22

# peace: index-to-middle tip spread > handSize * 0.3 (prevents "gun" pose)
PEACE_SPREAD_RATIO = 0.3

# thumbsUp/thumbsDown: thumb must project from knuckle line > handSize * 0.5
THUMB_PROJECT_RATIO = 0.5

# thumbsUp/thumbsDown: thumbExtension = dist(tip, wrist) / dist(MP, wrist) > 1.25
THUMB_EXTENSION_RATIO = 1.25

# openPalm: thumb away from index MCP > handSize * 0.6
OPEN_PALM_THUMB_RATIO = 0.6
```

Body classifier constants (from `BodyGesture.swift`):

```python
SHOULDER_WIDTH_MIN = 0.05     # reject frame if shoulder width is smaller
CLAP_WRIST_GAP_RATIO = 0.5   # wrist gap < shoulder_width * 0.5
```

---

## Debounce Constants

From `main.swift` — port exactly:

```python
NEEDED_FRAMES = 3
REARM_FRAMES = 5
PINCH_NEEDED_FRAMES = 2
PINCH_COOLDOWN_SECONDS = 0.8
ENTER_AFTER_DELETE_COOLDOWN = 0.4  # suppress Enter briefly after closedPinch fires

SQUAT_WINDOW_SECONDS = 2.0
SQUAT_MIN_DIP_RATIO = 0.30
SQUAT_RISE_BACK_RATIO = 0.10
SQUAT_COOLDOWN_SECONDS = 1.5
SQUAT_MIN_FRAMES = 10
```

---

## Gesture → Action Mapping

| Mode | Gesture | macOS action | Windows action |
|---|---|---|---|
| Hand | Thumbs up | `tapFn()` (Fn key) | `tap_right_alt()` (`VK_RMENU = 0xA5`) |
| Hand | Thumbs down | `tapEscape()` | `tap_escape()` (`VK_ESCAPE = 0x1B`) |
| Hand | Pinch (OK sign) | `tapReturn()` | `tap_enter()` (`VK_RETURN = 0x0D`) |
| Hand | Closed pinch | `tapDelete()` | `tap_backspace()` (`VK_BACK = 0x08`) |
| Hand | Index up | `tapCmdA()` | `tap_ctrl_a()` |
| Hand | Index left | `tapLeftArrow()` | `tap_left()` (`VK_LEFT = 0x25`) |
| Hand | Index right | `tapRightArrow()` | `tap_right()` (`VK_RIGHT = 0x27`) |
| Hand | Peace ✌️ | `tapCmdV()` | `tap_ctrl_v()` |
| Hand | Rock 🤘 | `tapCmdC()` | `tap_ctrl_c()` |
| Body | Squat | `tapFn()` | `tap_right_alt()` |
| Body | Clap | `tapReturn()` | `tap_enter()` |
| Body | Cross arms | `tapEscape()` | `tap_escape()` |

**Right Alt / Typeless dictation:** Right Alt (`VK_RMENU`) is the trigger for Typeless on Windows. This is a single keydown+keyup event, same pattern as `tapFn()` on macOS.

---

## Classification Order (Hand)

Must match macOS — more specific checks before more general ones:

1. `isThumbsUp`
2. `isThumbsDown`
3. `isPinch` (OK sign — thumb+index gap, middle/ring/little **extended**)
4. `isClosedPinch` (thumb+index gap, middle/ring/little **curled**)
5. `isPeace`
6. `isRock`
7. `pointingDirection` (returns one of: pointIndex, pointLeft, pointRight, or None)
8. `isFist`
9. `isOpenPalm`
10. `none`

Pinch must come before closedPinch: both have thumb+index touching, they differ only in whether middle/ring/little are extended or curled.
