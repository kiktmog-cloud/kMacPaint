import AppKit

public enum SelectionHandle {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    case body

    public static let handleSize: CGFloat = 7.0
}

public final class FloatingSelection {
    public var image: NSImage
    public var frame: CGRect
    public var activeHandle: SelectionHandle? = nil
    public var originalRect: CGRect? = nil
    public var isLifted: Bool = true

    public init(image: NSImage, origin: CGPoint = .zero, originalRect: CGRect? = nil, isLifted: Bool = true) {
        self.image = image
        self.frame = CGRect(origin: origin, size: image.size)
        self.originalRect = originalRect
        self.isLifted = isLifted
    }

    public func handleRects() -> [(SelectionHandle, CGRect)] {
        let s = SelectionHandle.handleSize
        let half = s / 2.0
        let minX = frame.minX
        let midX = frame.midX
        let maxX = frame.maxX
        let minY = frame.minY
        let midY = frame.midY
        let maxY = frame.maxY

        return [
            (.topLeft, CGRect(x: minX - half, y: minY - half, width: s, height: s)),
            (.top, CGRect(x: midX - half, y: minY - half, width: s, height: s)),
            (.topRight, CGRect(x: maxX - half, y: minY - half, width: s, height: s)),
            (.right, CGRect(x: maxX - half, y: midY - half, width: s, height: s)),
            (.bottomRight, CGRect(x: maxX - half, y: maxY - half, width: s, height: s)),
            (.bottom, CGRect(x: midX - half, y: maxY - half, width: s, height: s)),
            (.bottomLeft, CGRect(x: minX - half, y: maxY - half, width: s, height: s)),
            (.left, CGRect(x: minX - half, y: midY - half, width: s, height: s))
        ]
    }

    public func hitTest(_ point: CGPoint) -> SelectionHandle? {
        for (handle, rect) in handleRects() {
            if rect.insetBy(dx: -3, dy: -3).contains(point) {
                return handle
            }
        }
        if frame.contains(point) {
            return .body
        }
        return nil
    }

    public func draw() {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 1. Draw Image
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()
            // In AppKit flipped coordinates:
            context.translateBy(x: frame.origin.x, y: frame.origin.y + frame.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(cgImage, in: CGRect(origin: .zero, size: frame.size))
            context.restoreGState()
        }

        // 2. Draw Marching Ants / Dashed Border (Windows Paint style)
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.setLineWidth(1.0)

        // Black dash underlay
        context.setStrokeColor(NSColor.black.cgColor)
        context.stroke(frame)

        // White dash overlay with phase offset for contrast
        context.setLineDash(phase: 4, lengths: [4, 4])
        context.setStrokeColor(NSColor.white.cgColor)
        context.stroke(frame)
        context.restoreGState()

        // 3. Draw 8 Resize Handles
        for (_, rect) in handleRects() {
            context.setFillColor(NSColor.white.cgColor)
            context.fill(rect)
            context.setStrokeColor(NSColor(calibratedWhite: 0.2, alpha: 1.0).cgColor)
            context.setLineWidth(1.0)
            context.stroke(rect)
        }
    }

    public func bake(into context: CGContext) {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()
            // Note: CanvasModel context coordinate system
            context.translateBy(x: frame.origin.x, y: frame.origin.y + frame.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            context.draw(cgImage, in: CGRect(origin: .zero, size: frame.size))
            context.restoreGState()
        }
    }
}
