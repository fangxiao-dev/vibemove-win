import AppKit
import CoreGraphics
import Foundation

/// Floating HUD that draws a body skeleton + status text in a screen corner.
/// Lets the user see what the camera sees and which gesture is currently classified.
final class Overlay {
    private let window: NSWindow
    private let view: SkeletonView

    init() {
        let size = NSSize(width: 280, height: 360)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(x: screen.maxX - size.width - 24, y: screen.minY + 24)
        let frame = NSRect(origin: origin, size: size)

        window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.backgroundColor = .clear

        view = SkeletonView(frame: NSRect(origin: .zero, size: size))
        window.contentView = view

        DispatchQueue.main.async {
            self.window.orderFrontRegardless()
        }
    }

    func updateBody(landmarks: BodyLandmarks?, status: String) {
        DispatchQueue.main.async {
            self.view.bodyLandmarks = landmarks
            self.view.handLandmarks = nil
            self.view.statusText = status
            self.view.needsDisplay = true
        }
    }

    func updateHand(landmarks: HandLandmarks?, status: String) {
        DispatchQueue.main.async {
            self.view.handLandmarks = landmarks
            self.view.bodyLandmarks = nil
            self.view.statusText = status
            self.view.needsDisplay = true
        }
    }

    func flash(_ action: String) {
        DispatchQueue.main.async {
            self.view.lastAction = action
            self.view.lastActionExpiry = Date().addingTimeInterval(1.2)
            self.view.needsDisplay = true
        }
    }
}

final class SkeletonView: NSView {
    var bodyLandmarks: BodyLandmarks?
    var handLandmarks: HandLandmarks?
    var statusText: String = "—"
    var lastAction: String = ""
    var lastActionExpiry: Date = .distantPast

    override var isFlipped: Bool { false }  // keep Vision's bottom-left origin

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background: rounded translucent dark panel.
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        NSColor(white: 0, alpha: 0.72).setFill()
        bg.fill()

        let drawArea = bounds.insetBy(dx: 16, dy: 56)

        if let lm = bodyLandmarks {
            drawBodySkeleton(lm, in: drawArea, ctx: ctx)
        } else if let lm = handLandmarks {
            drawHandSkeleton(lm, in: drawArea, ctx: ctx)
        } else {
            drawNoBody(in: drawArea)
        }

        drawHeader()
        drawFooter()
    }

    // MARK: drawing helpers

    private func drawBodySkeleton(_ lm: BodyLandmarks, in area: NSRect, ctx: CGContext) {
        let segs: [(CGPoint, CGPoint)] = [
            (lm.leftShoulder, lm.rightShoulder),
            (lm.leftShoulder, lm.leftHip),
            (lm.rightShoulder, lm.rightHip),
            (lm.leftHip, lm.rightHip),
            (lm.leftShoulder, lm.leftWrist),
            (lm.rightShoulder, lm.rightWrist),
            (lm.leftHip, lm.leftKnee),
            (lm.rightHip, lm.rightKnee),
        ]
        let joints: [CGPoint] = [
            lm.nose,
            lm.leftShoulder, lm.rightShoulder,
            lm.leftHip, lm.rightHip,
            lm.leftWrist, lm.rightWrist,
            lm.leftKnee, lm.rightKnee,
        ]
        drawLines(segs, in: area, ctx: ctx, color: NSColor.systemGreen.withAlphaComponent(0.85))
        drawDots(joints, in: area, color: NSColor.systemGreen)
    }

    private func drawHandSkeleton(_ lm: HandLandmarks, in area: NSRect, ctx: CGContext) {
        let segs: [(CGPoint, CGPoint)] = [
            (lm.wrist, lm.thumbCMC), (lm.thumbCMC, lm.thumbMP), (lm.thumbMP, lm.thumbIP), (lm.thumbIP, lm.thumbTip),
            (lm.wrist, lm.indexMCP), (lm.indexMCP, lm.indexPIP), (lm.indexPIP, lm.indexDIP), (lm.indexDIP, lm.indexTip),
            (lm.wrist, lm.middleMCP), (lm.middleMCP, lm.middleTip),
            (lm.wrist, lm.ringMCP), (lm.ringMCP, lm.ringTip),
            (lm.wrist, lm.littleMCP), (lm.littleMCP, lm.littleTip),
        ]
        let joints: [CGPoint] = [
            lm.wrist,
            lm.thumbCMC, lm.thumbMP, lm.thumbIP, lm.thumbTip,
            lm.indexMCP, lm.indexPIP, lm.indexDIP, lm.indexTip,
            lm.middleMCP, lm.middleTip,
            lm.ringMCP, lm.ringTip,
            lm.littleMCP, lm.littleTip,
        ]
        drawLines(segs, in: area, ctx: ctx, color: NSColor.systemTeal.withAlphaComponent(0.85))
        drawDots(joints, in: area, color: NSColor.systemTeal)
    }

    private func drawNoBody(in area: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.5),
        ]
        let str = NSAttributedString(string: "no person in frame", attributes: attrs)
        let size = str.size()
        let pt = NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2)
        str.draw(at: pt)
    }

    private func drawLines(_ segs: [(CGPoint, CGPoint)], in area: NSRect, ctx: CGContext, color: NSColor) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(2.5)
        ctx.setLineCap(.round)
        for (a, b) in segs {
            guard isValid(a), isValid(b) else { continue }
            let pa = mapPoint(a, in: area)
            let pb = mapPoint(b, in: area)
            ctx.move(to: pa)
            ctx.addLine(to: pb)
        }
        ctx.strokePath()
    }

    private func drawDots(_ pts: [CGPoint], in area: NSRect, color: NSColor) {
        color.setFill()
        for p in pts {
            guard isValid(p) else { continue }
            let m = mapPoint(p, in: area)
            let r: CGFloat = 3.5
            let rect = NSRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private func mapPoint(_ p: CGPoint, in area: NSRect) -> NSPoint {
        // Vision normalized (0..1, bottom-left origin) → view coords inside `area`.
        // Mirror x so it feels like a mirror to the user.
        let x = area.minX + (1.0 - p.x) * area.width
        let y = area.minY + p.y * area.height
        return NSPoint(x: x, y: y)
    }

    private func isValid(_ p: CGPoint) -> Bool {
        return p.x > 0.001 || p.y > 0.001
    }

    private func drawHeader() {
        let title = "VibeMove"
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.55),
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        titleStr.draw(at: NSPoint(x: 16, y: bounds.maxY - 24))

        let statusAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let statusStr = NSAttributedString(string: statusText, attributes: statusAttrs)
        statusStr.draw(at: NSPoint(x: 16, y: bounds.maxY - 44))
    }

    private func drawFooter() {
        let now = Date()
        guard now < lastActionExpiry else { return }
        let alpha = max(0, min(1, lastActionExpiry.timeIntervalSince(now) / 1.2))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.systemYellow.withAlphaComponent(alpha),
        ]
        let str = NSAttributedString(string: "→ \(lastAction)", attributes: attrs)
        str.draw(at: NSPoint(x: 16, y: 18))
    }
}
