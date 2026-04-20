import AppKit
import AVFoundation
import CoreGraphics
import Foundation

setbuf(stdout, nil)

// Stability / debounce.
let neededFrames = 3
let rearmFrames = 5
let pinchNeededFrames = 2
let pinchCooldownSeconds: TimeInterval = 0.8

// After a Delete fires, suppress Enter briefly — the release of a closed pinch
// can momentarily look like an OK sign before the thumb-index gap opens up.
let enterAfterDeleteCooldown: TimeInterval = 0.4


// Squat config.
let squatWindowSeconds: TimeInterval = 2.0
let squatMinDipRatio: CGFloat = 0.30   // as fraction of torso length
let squatRiseBackRatio: CGFloat = 0.10
let squatCooldownSeconds: TimeInterval = 1.5
let squatMinFrames = 10

final class EdgeTrigger {
    private var streak = 0
    private var awayStreak = 999
    private var armed = true
    let needed: Int
    let rearm: Int
    init(needed: Int = neededFrames, rearm: Int = rearmFrames) {
        self.needed = needed
        self.rearm = rearm
    }

    func update(_ active: Bool) -> Bool {
        if active {
            awayStreak = 0
            streak += 1
            if armed && streak >= needed {
                armed = false
                return true
            }
        } else {
            streak = 0
            awayStreak += 1
            if awayStreak >= rearm {
                armed = true
            }
        }
        return false
    }
}

// MARK: - Hand mode controller

final class HandController {
    weak var overlay: Overlay?

    private let thumbsUp = EdgeTrigger()
    private let thumbsDown = EdgeTrigger()
    private let pointIndex = EdgeTrigger()
    private let pointLeft = EdgeTrigger()
    private let pointRight = EdgeTrigger()
    private let peace = EdgeTrigger()
    private let rock = EdgeTrigger()
    private let closedPinch = EdgeTrigger()

    private var pinchStreak = 0
    private var lastPinchAt: Date = .distantPast
    private var lastDeleteAt: Date = .distantPast

    func handle(_ gesture: Gesture, landmarks: HandLandmarks?) {
        overlay?.updateHand(landmarks: landmarks, status: gesture.rawValue)

        if thumbsUp.update(gesture == .thumbsUp) {
            Keyboard.tapFn()
            Feedback.play("Tink")
            overlay?.flash("Fn (dictation)")
            print("[thumbsUp] Fn tap (toggle)")
        }
        if thumbsDown.update(gesture == .thumbsDown) {
            Keyboard.tapEscape()
            Feedback.play("Funk")
            overlay?.flash("Esc")
            print("[thumbsDown] Escape")
        }
        if pointIndex.update(gesture == .pointIndex) {
            Keyboard.tapCmdA()
            Feedback.play("Morse")
            overlay?.flash("⌘A")
            print("[pointIndex] Cmd+A")
        }
        if pointLeft.update(gesture == .pointLeft) {
            Keyboard.tapLeftArrow()
            Feedback.play("Tink")
            overlay?.flash("←")
            print("[pointLeft] Left arrow")
        }
        if pointRight.update(gesture == .pointRight) {
            Keyboard.tapRightArrow()
            Feedback.play("Tink")
            overlay?.flash("→")
            print("[pointRight] Right arrow")
        }
        if peace.update(gesture == .peace) {
            Keyboard.tapCmdV()
            Feedback.play("Glass")
            overlay?.flash("⌘V")
            print("[peace] Cmd+V")
        }
        if rock.update(gesture == .rock) {
            Keyboard.tapCmdC()
            Feedback.play("Hero")
            overlay?.flash("⌘C")
            print("[rock] Cmd+C")
        }

        if gesture == .pinch {
            pinchStreak += 1
            let now = Date()
            if pinchStreak >= pinchNeededFrames,
               now.timeIntervalSince(lastPinchAt) > pinchCooldownSeconds,
               now.timeIntervalSince(lastDeleteAt) > enterAfterDeleteCooldown {
                lastPinchAt = now
                pinchStreak = 0
                Keyboard.tapReturn()
                Feedback.play("Pop")
                overlay?.flash("Enter")
                print("[pinch] Enter")
            }
        } else {
            pinchStreak = 0
        }

        if closedPinch.update(gesture == .closedPinch) {
            lastDeleteAt = Date()
            Keyboard.tapDelete()
            Feedback.play("Bottle")
            overlay?.flash("⌫")
            print("[closedPinch] Delete")
        }
    }
}

// MARK: - Body mode controller

final class BodyController {
    weak var overlay: Overlay?

    private let clap = EdgeTrigger(needed: 1, rearm: 8)
    private let crossArms = EdgeTrigger(needed: 2, rearm: 8)
    private var hipHistory: [(Date, CGFloat, CGFloat)] = []  // (time, hipY, torsoLen)
    private var lastSquatAt: Date = .distantPast
    private var frameCount = 0
    private var noBodyStreak = 0

    func handle(_ lm: BodyLandmarks?) {
        frameCount += 1
        guard let lm = lm else {
            overlay?.updateBody(landmarks: nil, status: "no body")
            hipHistory.removeAll()
            _ = clap.update(false)
            _ = crossArms.update(false)
            noBodyStreak += 1
            if frameCount % 30 == 0 {
                print("[debug] no body in frame (\(noBodyStreak) frames)")
            }
            return
        }
        noBodyStreak = 0

        let gesture = BodyGestureClassifier.classify(lm)
        overlay?.updateBody(landmarks: lm, status: gesture.rawValue)
        if frameCount % 30 == 0 {
            let hipY = (lm.leftHip.y + lm.rightHip.y) / 2
            let shoY = (lm.leftShoulder.y + lm.rightShoulder.y) / 2
            let torso = shoY - hipY
            let maxH = hipHistory.map { $0.1 }.max() ?? 0
            let minH = hipHistory.map { $0.1 }.min() ?? 0
            let dip = maxH - minH
            let dipRatio = torso > 0 ? dip / torso : 0
            print(String(format: "[debug] body OK  hipY=%.3f torso=%.3f history=%d dip=%.3f (%.0f%% of torso) gesture=%@",
                         Double(hipY), Double(torso), hipHistory.count, Double(dip), Double(dipRatio * 100), gesture.rawValue))
        }

        if clap.update(gesture == .clap) {
            Keyboard.tapReturn()
            Feedback.play("Pop")
            overlay?.flash("Enter (clap)")
            print("[clap] Enter")
        }
        if crossArms.update(gesture == .crossArms) {
            Keyboard.tapEscape()
            Feedback.play("Funk")
            overlay?.flash("Esc (cross)")
            print("[crossArms] Escape")
        }

        detectSquat(lm)
    }

    private func detectSquat(_ lm: BodyLandmarks) {
        let hipY = (lm.leftHip.y + lm.rightHip.y) / 2
        let shoulderY = (lm.leftShoulder.y + lm.rightShoulder.y) / 2
        let torso = shoulderY - hipY
        guard torso > 0.05 else { return }
        let now = Date()
        hipHistory.append((now, hipY, torso))
        hipHistory = hipHistory.filter { now.timeIntervalSince($0.0) <= squatWindowSeconds }
        guard hipHistory.count >= squatMinFrames else { return }
        guard now.timeIntervalSince(lastSquatAt) > squatCooldownSeconds else { return }

        let maxY = hipHistory.map { $0.1 }.max() ?? 0
        let minY = hipHistory.map { $0.1 }.min() ?? 0
        let dip = maxY - minY
        guard dip > torso * squatMinDipRatio else { return }
        guard hipY > maxY - torso * squatRiseBackRatio else { return }

        lastSquatAt = now
        hipHistory.removeAll()
        Keyboard.tapFn()
        Feedback.play("Tink")
        overlay?.flash("Fn (squat)")
        print("[squat] Fn tap (toggle)")
    }
}

// MARK: - Setup

func requestCameraAccess() -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
        return true
    case .notDetermined:
        let sema = DispatchSemaphore(value: 0)
        var granted = false
        AVCaptureDevice.requestAccess(for: .video) { ok in
            granted = ok
            sema.signal()
        }
        sema.wait()
        return granted
    default:
        return false
    }
}

// Parse --mode argument.
var mode = "body"
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--mode"), i + 1 < args.count {
    mode = args[i + 1]
}
guard mode == "hand" || mode == "body" else {
    print("Unknown mode: \(mode). Use --mode hand or --mode body.")
    exit(1)
}

print("VibeMove — mode: \(mode)")
if mode == "hand" {
    print("  👍 Thumbs up                    → Fn tap (Typeless dictation)")
    print("  👎 Thumbs down                  → Escape")
    print("  👌 Thumb + index pinch          → Enter")
    print("  🤏 Closed pinch (fingers curled) → Delete / Backspace")
    print("  ☝️  Index up                    → Cmd+A (select all)")
    print("  ☜  Index pointing left           → Left arrow")
    print("  ☞  Index pointing right          → Right arrow")
    print("  ✌️  Peace sign                   → Cmd+V (paste)")
    print("  🤘 Rock sign                    → Cmd+C (copy)")
} else {
    print("  🏋️ Squat (dip and rise)         → Fn tap (Typeless dictation)")
    print("  👏 Clap (wrists meet at chest)  → Enter")
    print("  ❌ Arms cross X at chest        → Escape")
    print("  (camera must see head → hips, ideally to knees)")
}
print("  Ctrl+C to quit")
print("")

guard requestCameraAccess() else {
    print("Camera access denied. Grant it in System Settings → Privacy & Security → Camera.")
    exit(1)
}

// Keep strong references at module scope so detector + controller + delegate
// stay alive for the lifetime of NSApp.run().
var handController: HandController?
var handDetector: HandDetector?
var bodyController: BodyController?
var bodyDetector: BodyDetector?
var overlay: Overlay?

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no dock icon, no menu bar
overlay = Overlay()

if mode == "hand" {
    let c = HandController()
    c.overlay = overlay
    let d = HandDetector()
    d.onLandmarks = { lm in
        guard let lm = lm else {
            c.handle(.none, landmarks: nil)
            return
        }
        let g = GestureClassifier.classify(lm)
        c.handle(g, landmarks: lm)
    }
    do {
        try d.start()
        print("Camera started. Show your hand.")
    } catch {
        print("Failed to start camera: \(error.localizedDescription)")
        exit(1)
    }
    handController = c
    handDetector = d
} else {
    let c = BodyController()
    c.overlay = overlay
    let d = BodyDetector()
    d.onLandmarks = { lm in
        c.handle(lm)
    }
    do {
        try d.start()
        print("Camera started. Stand in frame.")
    } catch {
        print("Failed to start camera: \(error.localizedDescription)")
        exit(1)
    }
    bodyController = c
    bodyDetector = d
}

signal(SIGINT) { _ in
    print("\nBye.")
    exit(0)
}

app.run()
