import CoreGraphics
import Foundation

enum Gesture: String {
    case none
    case thumbsUp
    case thumbsDown
    case pinch         // 👌 thumb+index touching, middle/ring/little extended (OK sign)
    case closedPinch   // thumb+index touching, other three curled
    case fist          // ✊ all fingers curled
    case openPalm
    case pointIndex    // ☝️ index pointing up
    case pointLeft     // ☜  index pointing left (from user's POV)
    case pointRight    // ☞  index pointing right
    case peace         // ✌️ index + middle
    case rock          // 🤘 index + little
}

enum GestureClassifier {
    static func classify(_ lm: HandLandmarks) -> Gesture {
        let handSize = dist(lm.wrist, lm.middleMCP)
        guard handSize > 0.05 else { return .none }

        // Order matters: check most specific first. pinch (OK sign) must come
        // before closedPinch — both have thumb+index touching, they differ in
        // whether middle/ring are extended or curled.
        if isThumbsUp(lm, handSize: handSize) { return .thumbsUp }
        if isThumbsDown(lm, handSize: handSize) { return .thumbsDown }
        if isPinch(lm, handSize: handSize) { return .pinch }
        if isClosedPinch(lm, handSize: handSize) { return .closedPinch }
        if isPeace(lm, handSize: handSize) { return .peace }
        if isRock(lm, handSize: handSize) { return .rock }
        // Pointing directions share the same shape (index out, others curled);
        // pick axis by the larger component of the index vector.
        if let g = pointingDirection(lm, handSize: handSize) { return g }
        if isFist(lm, handSize: handSize) { return .fist }
        if isOpenPalm(lm, handSize: handSize) { return .openPalm }
        return .none
    }

    // Helpers: is a given finger extended / curled?
    private static func extended(_ tip: CGPoint, _ mcp: CGPoint, _ wrist: CGPoint) -> Bool {
        return dist(tip, wrist) > dist(mcp, wrist) * 1.5
    }

    private static func curled(_ tip: CGPoint, _ mcp: CGPoint, _ wrist: CGPoint) -> Bool {
        return dist(tip, wrist) < dist(mcp, wrist) * 1.25
    }

    private static func isPointIndex(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // Rotation-invariant: use tip-to-MCP distance, not tip-to-wrist. The
        // wrist-based `extended()` fails for a horizontally-held index finger
        // (tip-to-wrist ≈ 1.2 × mcp-to-wrist, below its 1.5× threshold), which
        // would drop the hand into the fist classification.
        guard dist(lm.indexTip, lm.indexMCP) > handSize * 0.6 else { return false }
        guard curled(lm.middleTip, lm.middleMCP, lm.wrist) else { return false }
        guard curled(lm.ringTip, lm.ringMCP, lm.wrist) else { return false }
        guard curled(lm.littleTip, lm.littleMCP, lm.wrist) else { return false }
        return true
    }

    /// If the hand is in a "pointing" shape, returns the direction it points.
    /// Axis is decided by the larger component of `indexTip - indexMCP` after
    /// correcting for the camera's 4:3 aspect: normalized x-distances are
    /// compressed vs. y, so without this a physically horizontal finger still
    /// satisfies |dy_norm| > |dx_norm| and gets misclassified as "up".
    private static func pointingDirection(_ lm: HandLandmarks, handSize: CGFloat) -> Gesture? {
        guard isPointIndex(lm, handSize: handSize) else { return nil }
        let dx = (lm.indexTip.x - lm.indexMCP.x) * (640.0 / 480.0)
        let dy = lm.indexTip.y - lm.indexMCP.y
        if abs(dy) >= abs(dx) {
            // Pointing up (dy > 0) counts as pointIndex. Pointing down leaves
            // the gesture .none for now — we don't have an action wired to it.
            return dy > 0 ? .pointIndex : nil
        }
        // Raw camera coords are a mirror of the user: when the user points to
        // their own LEFT, the index tip sits at a larger x in the frame.
        return dx > 0 ? .pointLeft : .pointRight
    }

    private static func isPeace(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // Index + middle extended, ring + little curled.
        guard extended(lm.indexTip, lm.indexMCP, lm.wrist) else { return false }
        guard extended(lm.middleTip, lm.middleMCP, lm.wrist) else { return false }
        guard curled(lm.ringTip, lm.ringMCP, lm.wrist) else { return false }
        guard curled(lm.littleTip, lm.littleMCP, lm.wrist) else { return false }
        // Spread index and middle apart (not touching) — distinguishes from "gun" pose.
        guard dist(lm.indexTip, lm.middleTip) > handSize * 0.3 else { return false }
        return true
    }

    private static func isRock(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // Index + little extended, middle + ring curled.
        guard extended(lm.indexTip, lm.indexMCP, lm.wrist) else { return false }
        guard extended(lm.littleTip, lm.littleMCP, lm.wrist) else { return false }
        guard curled(lm.middleTip, lm.middleMCP, lm.wrist) else { return false }
        guard curled(lm.ringTip, lm.ringMCP, lm.wrist) else { return false }
        return true
    }

    private static func isClosedPinch(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // Thumb tip meets index tip (same gap threshold as OK pinch).
        let gap = dist(lm.thumbTip, lm.indexTip)
        guard gap < 0.22 * handSize else { return false }
        // Other three curled — this is what distinguishes from the OK sign.
        guard curled(lm.middleTip, lm.middleMCP, lm.wrist) else { return false }
        guard curled(lm.ringTip, lm.ringMCP, lm.wrist) else { return false }
        guard curled(lm.littleTip, lm.littleMCP, lm.wrist) else { return false }
        return true
    }

    private static func isFist(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // All four non-thumb fingers curled. We don't constrain the thumb here:
        // thumbs-up / thumbs-down already require the thumb to project clearly
        // outward, so any fist-like posture (thumb tucked or loosely on top)
        // falls through to this check cleanly.
        return curled(lm.indexTip, lm.indexMCP, lm.wrist) &&
               curled(lm.middleTip, lm.middleMCP, lm.wrist) &&
               curled(lm.ringTip, lm.ringMCP, lm.wrist) &&
               curled(lm.littleTip, lm.littleMCP, lm.wrist)
    }

    private static func isOpenPalm(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // All four non-thumb fingers clearly extended.
        let fingers: [(CGPoint, CGPoint)] = [
            (lm.indexTip, lm.indexMCP),
            (lm.middleTip, lm.middleMCP),
            (lm.ringTip, lm.ringMCP),
            (lm.littleTip, lm.littleMCP),
        ]
        for (tip, mcp) in fingers {
            let tipDist = dist(tip, lm.wrist)
            let mcpDist = dist(mcp, lm.wrist)
            if tipDist < mcpDist * 1.5 { return false }
        }
        // Thumb also spread (away from index MCP).
        if dist(lm.thumbTip, lm.indexMCP) < handSize * 0.6 { return false }
        return true
    }

    private static func isThumbsUp(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // Vision's normalized coords: origin bottom-left, y grows upward.
        // Thumb must point clearly up: tip above IP above MP above CMC.
        guard lm.thumbTip.y > lm.thumbIP.y,
              lm.thumbIP.y > lm.thumbMP.y,
              lm.thumbTip.y > lm.indexMCP.y + 0.25 * handSize
        else { return false }

        // Thumb extended: tip far from wrist relative to MP.
        let thumbExtension = dist(lm.thumbTip, lm.wrist) / max(dist(lm.thumbMP, lm.wrist), 0.001)
        guard thumbExtension > 1.25 else { return false }

        // Thumb must project clearly outward from the knuckle line — prevents
        // false-positives when the thumb merely rests on top of a closed fist.
        guard dist(lm.thumbTip, lm.indexMCP) > handSize * 0.5 else { return false }

        // Other four fingers curled: tip distance to wrist ≈ MCP distance (not extended).
        let curled: [(CGPoint, CGPoint)] = [
            (lm.indexTip, lm.indexMCP),
            (lm.middleTip, lm.middleMCP),
            (lm.ringTip, lm.ringMCP),
            (lm.littleTip, lm.littleMCP),
        ]
        for (tip, mcp) in curled {
            let tipDist = dist(tip, lm.wrist)
            let mcpDist = dist(mcp, lm.wrist)
            if tipDist > mcpDist * 1.25 { return false }
        }
        return true
    }

    private static func isThumbsDown(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // Mirror of thumbsUp: thumb points clearly down.
        // Tip below IP below MP (descending y in bottom-left-origin coords).
        guard lm.thumbTip.y < lm.thumbIP.y,
              lm.thumbIP.y < lm.thumbMP.y,
              lm.thumbTip.y < lm.indexMCP.y - 0.25 * handSize
        else { return false }

        let thumbExtension = dist(lm.thumbTip, lm.wrist) / max(dist(lm.thumbMP, lm.wrist), 0.001)
        guard thumbExtension > 1.25 else { return false }

        guard dist(lm.thumbTip, lm.indexMCP) > handSize * 0.5 else { return false }

        let curled: [(CGPoint, CGPoint)] = [
            (lm.indexTip, lm.indexMCP),
            (lm.middleTip, lm.middleMCP),
            (lm.ringTip, lm.ringMCP),
            (lm.littleTip, lm.littleMCP),
        ]
        for (tip, mcp) in curled {
            let tipDist = dist(tip, lm.wrist)
            let mcpDist = dist(mcp, lm.wrist)
            if tipDist > mcpDist * 1.25 { return false }
        }
        return true
    }

    private static func isPinch(_ lm: HandLandmarks, handSize: CGFloat) -> Bool {
        // Thumb tip touches index tip.
        let gap = dist(lm.thumbTip, lm.indexTip)
        guard gap < 0.22 * handSize else { return false }

        // Middle, ring AND little must be clearly extended (stricter than the
        // curled helper's complement). This widens the dead-zone between OK
        // sign and closedPinch so partial curls don't accidentally fire Enter.
        guard extended(lm.middleTip, lm.middleMCP, lm.wrist) else { return false }
        guard extended(lm.ringTip, lm.ringMCP, lm.wrist) else { return false }
        guard extended(lm.littleTip, lm.littleMCP, lm.wrist) else { return false }
        return true
    }

    private static func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
