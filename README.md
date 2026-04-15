# VibeMove

**English** | [简体中文](README.zh-CN.md)

> **You're sitting too much. Let's fix that with cardio.**

VibeMove is the vibe coding companion that makes you **earn** every prompt. Your laptop camera watches you. Drop into a squat and the mic turns on. Clap and your message ships. Cross your arms like a disappointed coach and whatever you just said gets nuked.

No Joy-Con. No wristbands. No LiDAR rig smuggled out of a film studio. Just `AVCaptureSession` + Apple Vision + a little bit of shame.

## The pitch

AI does the thinking. Voice does the typing. **Your body becomes the mouse.**

That's the whole gig. Every prompt you send costs roughly one squat — metaphorically, or literally, depending on which mode you pick.

## Two modes

Same goal: fewer keystrokes, more movement.

| Mode | Vibe | Best for |
| --- | --- | --- |
| **`body`** *(default)* | "I'm vibe-coding my way to cardio." | Standing desk, walking pad, kitchen counter, living room rug. |
| **`hand`** | "Silent hand magic, please." | 2am desk session, open-plan office, kids asleep in the next room. |

```bash
swift run VibeMove                       # body mode (default)
swift run VibeMove -- --mode hand        # hand mode
```

## Hand mode — six gestures, no keyboard

Runs `VNDetectHumanHandPoseRequest` and watches your 21 hand joints like a very polite robot. All offline. All local. Free forever.

| Gesture | Fires | Why this gesture |
| --- | --- | --- |
| 👍 **Thumbs up** *(tap)* | **Fn** — dictation on/off | You're the thumbs-up guy now. Own it. |
| 👌 **OK pinch** | **Enter** | The universal "send" sign. Also: satisfying. |
| 🖐️ **Open palm, swipe down** | **Escape** | Dismiss with menace. |
| ☝️ **Index finger up** | **⌘A** — select all | One finger, entire universe. |
| ✌️ **Peace sign** | **⌘V** — paste | Yes, the V stands for V. |
| 🤘 **Rock sign** | **⌘C** — copy | Copy like you mean it. |

## Body mode — the whole-body experience

Uses `VNDetectHumanBodyPoseRequest`. Needs to see you **from head to hips** (at least). A laptop flat on a desk will only catch your chin. Prop it up. Step back. Embrace the home fitness influencer setup.

| Move | Fires | Philosophy |
| --- | --- | --- |
| 🏋️ **Squat** *(drop and rise)* | **Fn** — dictation on/off | "Wanna talk to the AI? Earn it." |
| 👏 **Clap** *(at chest level)* | **Enter** — send | The universe high-fives your message. |
| ❌ **Arms cross X** *(at chest level)* | **Escape** — cancel | Ref says no. |

Your coworkers **will** ask what you're doing on the next video call. That's a feature, not a bug.

## Sound design

Every successful trigger plays a different built-in macOS sound, so you know exactly which gesture just landed without looking at a screen:

| Action | Sound | Feels like |
| --- | --- | --- |
| Fn — dictation | Tink | "the mic is hot" |
| Enter — send | Pop | "it's gone" |
| Escape — cancel | Funk | "undo that thought" |
| ⌘A | Morse | "grabbing everything" |
| ⌘V | Glass | "dropping it in" |
| ⌘C | Hero | "yoink" |

## Install

### Option 1 — Download the prebuilt `.app` (recommended)

Grab the latest zip from [Releases](https://github.com/fifteen42/vibemove/releases), unzip it, and drag `VibeMove.app` into `Applications`.

> **First launch is where macOS yells at you.** The build is unsigned (no $99 Apple Developer ID *yet*), so Gatekeeper will refuse a plain double-click. Get around it with one of:
> - Right-click `VibeMove.app` → **Open** → confirm in the dialog.
> - Or in Terminal: `xattr -cr /Applications/VibeMove.app`

### Option 2 — Build from source

```bash
git clone https://github.com/fifteen42/vibemove.git
cd vibemove
swift build
swift run VibeMove                       # body mode (default)
swift run VibeMove -- --mode hand        # hand mode
```

### Build your own `.app`

```bash
bash scripts/package.sh 0.1.0
# → dist/VibeMove.app
# → dist/VibeMove-0.1.0.zip
```

## Permissions

On first launch macOS will ask for two things. Say yes to both or nothing works:

1. **Camera** — auto-prompted.
2. **Accessibility** — System Settings → Privacy & Security → Accessibility → add your terminal app (Terminal / iTerm2 / Ghostty / whatever). Without this, VibeMove can see you but can't type for you.

## Requirements

- macOS 13+
- Any Mac with a camera (Apple Silicon is faster, Intel works)
- Swift 5.9+
- A willingness to look slightly ridiculous

## Tuning

If the thresholds feel wrong — too sensitive, too stubborn, not calibrated to your body — open `Sources/VibeMove/main.swift` and tweak the constants near the top:

| Knob | Default | What it does |
| --- | --- | --- |
| `neededFrames` | 3 | How many stable frames a hand gesture needs before it fires. |
| `rearmFrames` | 5 | How many frames the gesture must disappear before it can fire again. |
| `pinchCooldownSeconds` | 0.8 | Minimum gap between two Enter taps. |
| `swipeMinDropRatio` | 0.25 | How far the wrist must drop (as a fraction of frame height) to count as a downward swipe. |
| `squatMinDipRatio` | 0.30 | How deep your squat must go (as a fraction of torso length) before it counts. |
| `squatCooldownSeconds` | 1.5 | Minimum gap between two squats. |

If you find yourself doing half-reps to avoid triggering, lower the ratio. No shame. Your back, your rules.

## How it actually works

- **Camera** → `AVCaptureSession` at 640×480. Small frames, fast processing, no GPU melt.
- **Recognition** → Apple Vision framework. `VNDetectHumanHandPoseRequest` gives 21 hand joints; `VNDetectHumanBodyPoseRequest` gives 19 body joints. Both run on-device, zero cloud calls, zero model downloads.
- **Classifier** → Plain geometry on normalized coordinates. No ML training, no labeled data, no 20GB weights. Just "is this point above that point, and are these two distances smaller than this ratio."
- **Keyboard injection** → `CGEvent`. The **Fn** key is the tricky one: it has to be simulated via `.flagsChanged` events (not `keyDown`), otherwise macOS thinks Fn is stuck down forever and starts zooming your screen for you. Learned this one the hard way.
- **Feedback** → `NSSound` playing built-in system sounds. Free, instant, doesn't need Accessibility permission.
- **HUD** → A small `NSWindow` overlay in the bottom-right corner showing the live skeleton, the current detected gesture, and a flash on every fired action. So you can see what VibeMove sees.

## Vibe

The long-term vibe: in the post-keyboard era, typing isn't the bottleneck. Voice + AI handles the text. What's left is **intent** — pick this, skip that, send, cancel, switch context. Intent is where the body shines. A squat, a clap, a thumbs-up — all perfectly good ways to tell a computer "yes, do the thing."

Also: you shouldn't spend ten hours a day frozen in a chair. One squat per prompt adds up.

## Credit

Inspired in spirit by [wong2/vibe-ring](https://github.com/wong2/vibe-ring). VibeMove takes a different path — no controller, no hardware, just your camera and your body.

## License

MIT. Have fun, break it, send a PR.
